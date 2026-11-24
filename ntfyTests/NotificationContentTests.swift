import Testing
import UserNotifications
@testable import ntfy

/// `modify(message:baseUrl:)` reads the critical alert flags from `Store.shared` and the shared
/// app group defaults, so these tests mutate global state. They are serialized and restore it,
/// and run on the main actor because `Store.shared.context` is a main-queue context.
@MainActor
@Suite(.serialized)
struct NotificationContentTests {
    private func content(priority: Int16?, title: String? = "Title", tags: [String]? = nil) -> UNMutableNotificationContent {
        let message = Message(id: "id1", time: 1, event: "message", topic: "alerts",
                              message: "Body", title: title, priority: priority, tags: tags)
        let content = UNMutableNotificationContent()
        content.modify(message: message, baseUrl: "https://ntfy.sh")
        return content
    }

    private func withCriticalAlerts(enabled: Bool, authorized: Bool, _ body: () -> Void) {
        let previousEnabled = Store.shared.getCriticalAlertsEnabled()
        let previousAuthorized = Store.getCriticalAlertsAuthorized()
        defer {
            Store.shared.saveCriticalAlertsEnabled(previousEnabled)
            Store.saveCriticalAlertsAuthorized(previousAuthorized)
        }
        Store.shared.saveCriticalAlertsEnabled(enabled)
        Store.saveCriticalAlertsAuthorized(authorized)
        body()
    }

    @Test(arguments: [
        (Int16(1), UNNotificationInterruptionLevel.passive),
        (2, .passive),
        (3, .active),
        (4, .timeSensitive)
    ])
    func priorityMapsToInterruptionLevel(priority: Int16, expected: UNNotificationInterruptionLevel) {
        #expect(content(priority: priority).interruptionLevel == expected)
    }

    @Test func missingPriorityIsActive() {
        #expect(content(priority: nil).interruptionLevel == .active)
    }

    @Test(arguments: [(true, true), (true, false), (false, true), (false, false)])
    func priorityFiveIsCriticalOnlyWhenEnabledAndAuthorized(enabled: Bool, authorized: Bool) {
        withCriticalAlerts(enabled: enabled, authorized: authorized) {
            let level = content(priority: 5).interruptionLevel
            #expect(level == (enabled && authorized ? .critical : .timeSensitive))
        }
    }

    @Test func missingTitleFallsBackToShortTopicUrl() {
        #expect(content(priority: 3, title: "").title == "ntfy.sh/alerts")
    }

    @Test func emojiTagsArePrependedToTitle() {
        #expect(content(priority: 3, tags: ["tada"]).title == "🎉 Title")
    }

    @Test func userInfoCarriesBaseUrlForTapHandling() {
        let userInfo = content(priority: 3).userInfo
        #expect(userInfo["base_url"] as? String == "https://ntfy.sh")
        #expect(Message.from(userInfo: userInfo)?.id == "id1")
    }
}
