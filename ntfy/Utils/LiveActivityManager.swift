import Foundation
import UserNotifications
#if canImport(ActivityKit)
import ActivityKit
#endif

/// A Live Activity command parsed from an ntfy message. Messages drive a Live Activity through tags:
///
///   activity=<id>              required, identifies the activity within the topic
///   state=start|update|end     optional, defaults to update (which starts the activity if it does not exist yet)
///   progress=<0-100>           optional, shows a progress bar
///
/// The message title becomes the activity title, the message body the status text, and the icon (X-Icon) its icon.
/// Example: curl -H "Tags: activity=build-42,progress=40" -H "Title: Build #42" -d "Compiling" https://ntfy.example.com/ci
struct LiveActivityCommand: Codable {
    enum State: String, Codable {
        case start, update, end
    }

    var topic: String
    var activityId: String
    var state: State
    var title: String
    var status: String
    var progress: Double?
    var iconUrl: String?
    var iconFile: String?
    var time: Int64

    var key: String {
        "\(topic)/\(activityId)"
    }

    init?(message: Message, baseUrl: String) {
        var activityId: String?
        var state = State.update
        var progress: Double?
        for tag in message.tags ?? [] {
            let parts = tag.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2, !parts[1].isEmpty else {
                continue
            }
            switch parts[0].lowercased() {
            case "activity":
                activityId = parts[1]
            case "state":
                state = State(rawValue: parts[1].lowercased()) ?? .update
            case "progress":
                progress = Double(parts[1].replacingOccurrences(of: "%", with: "")).map { min(100, max(0, $0)) }
            default:
                break
            }
        }
        guard let activityId else {
            return nil
        }
        let title = message.title ?? ""
        let icon = message.icon?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.topic = message.topic
        self.activityId = activityId
        self.state = state
        self.title = title.isEmpty ? topicShortUrl(baseUrl: baseUrl, topic: message.topic) : title
        self.status = message.message ?? ""
        self.progress = progress
        self.iconUrl = icon.isEmpty ? TopicIconStore.iconUrl(baseUrl: baseUrl, topic: message.topic) : icon
        self.time = message.time
    }
}

/// Starts, updates and ends Live Activities locally with ActivityKit. There are no ActivityKit push tokens,
/// because only the holder of ntfy's APNs key could use them.
///
/// iOS only allows starting an activity while the app is in the foreground. Updating and ending work from the
/// background, but the app only runs in the background when iOS wakes it. Commands are therefore stored in a
/// queue in the app group, applied right away where possible (notification service extension, app), and retried
/// whenever the app becomes active, a notification is shown in the foreground, or the "~poll" background push wakes the app.
enum LiveActivityManager {
    private static let tag = "LiveActivityManager"
    private static let maxCommandAge: TimeInterval = 12 * 60 * 60 // Activities cannot live longer than 8h (+4h on the lock screen)

    /// Queues the commands contained in the messages (if any) and tries to apply all queued commands.
    static func handle(messages: [Message], baseUrl: String, user: BasicUser?, completionHandler: @escaping () -> Void) {
        let commands = messages.compactMap { LiveActivityCommand(message: $0, baseUrl: baseUrl) }
        guard !commands.isEmpty else {
            completionHandler()
            return
        }
        let group = DispatchGroup()
        for var command in commands {
            Log.d(tag, "Received Live Activity command \(command.state.rawValue) for \(command.key)")
            group.enter()
            guard let iconUrl = command.iconUrl else {
                LiveActivityQueue.enqueue(command)
                group.leave()
                continue
            }
            IconCache.load(iconUrl: iconUrl, baseUrl: baseUrl, user: user) { fileUrl in
                command.iconFile = fileUrl?.lastPathComponent
                LiveActivityQueue.enqueue(command)
                group.leave()
            }
        }
        group.notify(queue: .main) {
            processPending(completionHandler: completionHandler)
        }
    }

    /// Applies queued commands. Commands that cannot be applied yet (e.g. starting an activity
    /// while the app is in the background) stay in the queue.
    static func processPending(completionHandler: (() -> Void)? = nil) {
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            Task {
                await PendingProcessor.shared.run()
                completionHandler?()
            }
            return
        }
        #endif
        completionHandler?()
    }

    #if canImport(ActivityKit)
    /// Serializes queue processing, so that two callers cannot start the same activity twice.
    @available(iOS 16.2, *)
    private actor PendingProcessor {
        static let shared = PendingProcessor()
        private var isRunning = false
        private var runAgain = false

        func run() async {
            if isRunning {
                runAgain = true
                return
            }
            isRunning = true
            repeat {
                runAgain = false
                for command in LiveActivityQueue.pending() {
                    if Date().timeIntervalSince1970 - TimeInterval(command.time) > maxCommandAge {
                        LiveActivityQueue.remove(command)
                    } else if await apply(command) {
                        LiveActivityQueue.remove(command)
                    }
                }
            } while runAgain
            isRunning = false
        }
    }

    @available(iOS 16.2, *)
    fileprivate static func apply(_ command: LiveActivityCommand) async -> Bool {
        let updatedAt = Date(timeIntervalSince1970: TimeInterval(command.time))
        let state = NtfyActivityAttributes.ContentState(
            title: command.title,
            status: command.status,
            progress: command.progress,
            iconFile: command.iconFile,
            ended: command.state == .end,
            updatedAt: updatedAt
        )
        // Updates don't have to repeat the icon
        func content(keepingIconOf activity: Activity<NtfyActivityAttributes>?) -> ActivityContent<NtfyActivityAttributes.ContentState> {
            var state = state
            state.iconFile = state.iconFile ?? activity?.content.state.iconFile
            return ActivityContent(state: state, staleDate: nil)
        }
        let activities = Activity<NtfyActivityAttributes>.activities.filter { $0.attributes.key == command.key }
        let running = activities.filter { $0.activityState == .active || $0.activityState == .stale }

        // Activities belong to the bundle that started them, so the extension never sees the app's activities
        // and can't start one either. Leave everything to the app, which the extension wakes (LiveActivityWaker).
        if running.isEmpty && Bundle.main.bundlePath.hasSuffix(".appex") {
            Log.d(tag, "Leaving \(command.key) to the app")
            return false
        }
        if command.state == .end {
            for activity in running {
                await activity.end(content(keepingIconOf: activity), dismissalPolicy: .default)
            }
            Log.d(tag, "Ended \(running.count) Live Activity(ies) for \(command.key)")
            return true
        }
        if let activity = running.first {
            if activity.content.state.updatedAt > updatedAt {
                return true // An older message arrived late, ignore it
            }
            await activity.update(content(keepingIconOf: activity))
            Log.d(tag, "Updated Live Activity for \(command.key)")
            return true
        }
        do {
            let attributes = NtfyActivityAttributes(key: command.key, topic: command.topic)
            _ = try Activity.request(attributes: attributes, content: content(keepingIconOf: nil), pushType: nil)
            Log.d(tag, "Started Live Activity for \(command.key)")
            return true
        } catch {
            // Expected when not in the foreground, or when the user disabled Live Activities
            Log.d(tag, "Cannot start Live Activity for \(command.key) yet", error)
            return false
        }
    }
    #endif
}

extension UNMutableNotificationContent {
    /// Activity updates are mostly noise as regular notifications (iOS does not let us drop them without
    /// the filtering entitlement), so deliver them quietly. Starts stay as they are: tapping one opens the app,
    /// which is where iOS allows starting the activity.
    func quietIfLiveActivityUpdate(message: Message) {
        guard let command = LiveActivityCommand(message: message, baseUrl: ""), command.state != .start else {
            return
        }
        interruptionLevel = .passive
        sound = nil
    }
}

/// Latest command per activity, stored in the app group so the notification service extension and the app share it.
enum LiveActivityQueue {
    private static let defaults = UserDefaults(suiteName: Store.appGroup)
    private static let defaultsKey = "liveActivityPending"

    static func pending() -> [LiveActivityCommand] {
        load().values.sorted { $0.time < $1.time }
    }

    static func enqueue(_ command: LiveActivityCommand) {
        var commands = load()
        if let existing = commands[command.key], existing.time > command.time {
            return
        }
        commands[command.key] = command
        save(commands)
    }

    static func remove(_ command: LiveActivityCommand) {
        var commands = load()
        if let existing = commands[command.key], existing.time <= command.time {
            commands.removeValue(forKey: command.key)
            save(commands)
        }
    }

    private static func load() -> [String: LiveActivityCommand] {
        guard let data = defaults?.data(forKey: defaultsKey) else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: LiveActivityCommand].self, from: data)) ?? [:]
    }

    private static func save(_ commands: [String: LiveActivityCommand]) {
        defaults?.set(try? JSONEncoder().encode(commands), forKey: defaultsKey)
    }
}
