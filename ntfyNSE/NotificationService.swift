import UserNotifications
import CoreData
import CryptoKit

/// This app extension is responsible for persisting the incoming notification to the data store (Core Data). It will eventually be the entity that
/// fetches notification content from selfhosted servers (when a "poll request" is received). This is not implemented yet.
///
/// Note that the app extension does not run as part of the main app, so log messages are not printed in the main Xcode window. To debug,
/// select Debug -> Attach to Process by PID or Name, and select the extension. Don't forget to set a breakpoint, or you're not gonna have a good time.
class NotificationService: UNNotificationServiceExtension {
    private let tag = "NotificationService"
    private var store: Store?
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    
    // Requests being handled by this process, see exitWhenIdle
    private static let lock = NSLock()
    private static var activeRequests = 0
    private static var exitWhenIdle = false

    override func didReceive(_ request: UNNotificationRequest, withContentHandler originalContentHandler: @escaping (UNNotificationContent) -> Void) {
        NotificationService.requestStarted()
        var finished = false
        let contentHandler: (UNNotificationContent) -> Void = { content in
            originalContentHandler(content)
            if !finished {
                finished = true
                NotificationService.requestFinished()
            }
        }
        self.store = Store.shared
        self.contentHandler = contentHandler
        self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        if let bestAttemptContent = bestAttemptContent {
            let userInfo = bestAttemptContent.userInfo
            guard let message = Message.from(userInfo: userInfo) else {
                Log.w(tag, "Message cannot be parsed from userInfo", userInfo)
                contentHandler(request.content)
                return
            }
            Log.d(
                tag,
                "\(#function) event=\(message.event), topic=\(message.topic), pollId=\(message.pollId ?? "<nil>"), baseUrl=\(userInfo["base_url"] as? String ?? "<nil>")"
            )
            switch message.event {
            case "poll_request":
                handlePollRequest(request, bestAttemptContent, message, contentHandler)
            case "message":
                let baseUrl = userInfo["base_url"]  as? String ?? Config.appBaseUrl // messages only come for the main server
                handleMessage(request, bestAttemptContent, baseUrl, message, contentHandler)
            default:
                Log.w(tag, "Irrelevant message received", message)
                contentHandler(request.content)
            }
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content,
        // otherwise the original push payload will be used.

        Log.w(tag, "\(#function): delivering best attempt content")
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
    
    private func handleMessage(_ request: UNNotificationRequest, _ content: UNMutableNotificationContent, _ baseUrl: String, _ message: Message, _ contentHandler: @escaping (UNNotificationContent) -> Void) {
        // Save notification first so attachment downloads can update persistent state.
        guard store?.save(notificationFromMessage: message, baseUrl: baseUrl, topic: message.topic) == true else {
            Log.w(tag, "Subscription \(topicUrl(baseUrl: baseUrl, topic: message.topic)) unknown")
            contentHandler(request.content)
            return
        }
        let user = store?.getBasicUser(baseUrl: baseUrl)
        content.modify(message: message, baseUrl: baseUrl)
        content.quietIfLiveActivityUpdate(message: message)
        content.attachImageIfNeeded(message: message, user: user) {
            content.applySenderIcon(message: message, baseUrl: baseUrl, user: user) { finalContent in
                LiveActivityManager.handle(messages: [message], baseUrl: baseUrl, user: user) {
                    // iOS doesn't let extensions update Live Activities, so wake the app to do it.
                    // Starting one needs the app in the foreground, so a start can't be handled this way.
                    if let command = LiveActivityCommand(message: message, baseUrl: baseUrl), command.state != .start, !LiveActivityQueue.pending().isEmpty {
                        LiveActivityWaker.scheduleWake(baseUrl: baseUrl)
                        NotificationService.exitWhenIdle = true
                    }
                    contentHandler(finalContent)
                }
            }
        }
    }
    
    private func handlePollRequest(_ request: UNNotificationRequest, _ content: UNMutableNotificationContent, _ pollRequest: Message, _ contentHandler: @escaping (UNNotificationContent) -> Void) {
        let pollId = pollRequest.pollId ?? pollRequest.id
        let preferredBaseUrl = bestAttemptContent?.userInfo["base_url"] as? String
        guard let subscription = store?.findSubscriptionMatch(
                forPollRequestTopic: pollRequest.topic,
                preferredBaseUrl: preferredBaseUrl
            )
        else {
            Log.w(tag, "Cannot find subscription for poll request topic=\(pollRequest.topic), pollId=\(pollRequest.pollId ?? "<nil>")")
            contentHandler(request.content)
            return
        }
        
        // Poll original server
        let user = store?.getBasicUser(baseUrl: subscription.baseUrl)
        // The extension only needs contentHandler to be called from the async callback
        ApiService.shared.poll(baseUrl: subscription.baseUrl, topic: subscription.topic, messageId: pollId, user: user) { message, error in
            guard let message = message else {
                Log.w(self.tag, "Error fetching poll request message topic=\(pollRequest.topic), pollId=\(pollId), subscription=\(topicUrl(baseUrl: subscription.baseUrl, topic: subscription.topic))", error)
                contentHandler(request.content)
                return
            }
            self.handleMessage(request, content, subscription.baseUrl, message, contentHandler)
        }
    }

    private static func requestStarted() {
        lock.lock()
        activeRequests += 1
        lock.unlock()
    }

    /// iOS only relaunches the app for the wake-up download if this extension is no longer running when the download
    /// finishes, otherwise it delivers the result here. iOS keeps extension processes around for reuse, so once
    /// nothing is in flight, quit. The delay gives the content handler time to hand the notification to the system.
    private static func requestFinished() {
        lock.lock()
        activeRequests -= 1
        let shouldExit = activeRequests == 0 && exitWhenIdle
        lock.unlock()
        guard shouldExit else {
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            lock.lock()
            let stillIdle = activeRequests == 0
            lock.unlock()
            if stillIdle {
                Log.d("NotificationService", "Exiting so that iOS relaunches the app for the wake-up download")
                exit(0)
            }
        }
    }
}
