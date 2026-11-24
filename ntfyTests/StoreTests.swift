import Testing
@testable import ntfy

/// Each test gets its own in-memory Core Data store. `Store.context` is a main-queue context,
/// so tests run on the main actor to avoid racing the store's main-thread refreshes.
@MainActor
struct StoreTests {
    let store = Store(inMemory: true)

    private func message(_ id: String, time: Int64 = 1) -> Message {
        Message(id: id, time: time, event: "message", topic: "alerts", message: "m-\(id)")
    }

    @Test func savesSubscriptionWithNormalizedBaseUrl() throws {
        _ = store.saveSubscription(baseUrl: "https://example.com/", topic: "alerts")
        let subscription = try #require(store.getSubscription(baseUrl: "https://example.com", topic: "alerts"))
        #expect(subscription.baseUrl == "https://example.com")
        #expect(store.getSubscriptions()?.count == 1)
    }

    /// Mirrors SubscriptionAddView, which saves the user and subscription from a background queue.
    @Test func savesUserAndSubscriptionFromBackgroundQueue() async throws {
        let store = self.store
        await Task.detached {
            store.saveUser(baseUrl: "https://example.com/", username: "user", password: "secret")
            _ = store.saveSubscription(baseUrl: "https://example.com/", topic: "alerts")
        }.value

        #expect(store.getUser(baseUrl: "https://example.com")?.username == "user")
        #expect(store.getSubscription(baseUrl: "https://example.com", topic: "alerts") != nil)
    }

    @Test func savingSameMessageTwiceDoesNotDuplicate() throws {
        let subscription = store.saveSubscription(baseUrl: "https://example.com", topic: "alerts")
        store.save(notificationFromMessage: message("a"), withSubscription: subscription)
        store.save(notificationsFromMessages: [message("a"), message("b")], withSubscription: subscription)

        #expect(subscription.notificationCount() == 2)
        #expect(subscription.lastNotificationId == "b")
    }

    @Test func saveByTopicRequiresExistingSubscription() {
        #expect(!store.save(notificationFromMessage: message("a"), baseUrl: "https://example.com", topic: "missing"))

        _ = store.saveSubscription(baseUrl: "https://example.com", topic: "alerts")
        #expect(store.save(notificationFromMessage: message("a"), baseUrl: "https://example.com/", topic: "alerts"))
    }

    @Test func pollRequestMatchesSelfHostedSubscriptionByHash() throws {
        _ = store.saveSubscription(baseUrl: "https://example.com", topic: "alerts")
        let hash = topicHash(baseUrl: "https://example.com", topic: "alerts")

        let match = try #require(store.findSubscriptionMatch(forPollRequestTopic: hash))
        #expect(match.baseUrl == "https://example.com")
        #expect(match.topic == "alerts")
    }

    @Test func pollRequestPrefersRequestedBaseUrl() throws {
        _ = store.saveSubscription(baseUrl: Config.appBaseUrl, topic: "alerts")
        _ = store.saveSubscription(baseUrl: "https://example.com", topic: "alerts")

        let preferred = try #require(store.findSubscriptionMatch(forPollRequestTopic: "alerts", preferredBaseUrl: "https://example.com/"))
        #expect(preferred.baseUrl == "https://example.com")

        // Without a preference, a plain topic name resolves to the default server.
        let fallback = try #require(store.findSubscriptionMatch(forPollRequestTopic: "alerts"))
        #expect(fallback.baseUrl == normalizeBaseUrl(Config.appBaseUrl))
    }

    @Test func pollRequestWithUnknownTopicHasNoMatch() {
        _ = store.saveSubscription(baseUrl: "https://example.com", topic: "alerts")
        #expect(store.findSubscriptionMatch(forPollRequestTopic: "nope") == nil)
    }

    @Test func criticalAlertsPreferenceDefaultsOffAndPersists() {
        #expect(!store.getCriticalAlertsEnabled())
        store.saveCriticalAlertsEnabled(true)
        #expect(store.getCriticalAlertsEnabled())
        store.saveCriticalAlertsEnabled(false)
        #expect(!store.getCriticalAlertsEnabled())
    }
}
