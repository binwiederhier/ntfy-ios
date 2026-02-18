import Testing
import CoreData
@testable import ntfy

/// Top-level serialization wrapper.
///
/// Both inner suites create Store(inMemory: true), which initialises an
/// NSPersistentContainer. Concurrent initialisation of multiple containers
/// in the same process causes CoreData to emit "Failed to find a unique match
/// for NSEntityDescription" warnings that can silently break relationship
/// queries (e.g. subscription.notificationCount()). Wrapping both suites in a
/// single .serialized parent prevents them from running concurrently regardless
/// of how the test plan's parallelizationEnabled is interpreted by the runner.
@Suite(.serialized)
struct NtfyTests {

/// Tests for notification delivery fixes.
///
/// Background: when a push arrives while the app is in the foreground, iOS calls
/// userNotificationCenter(_:willPresent:). The upstream only showed a banner and
/// never saved the message to CoreData, so it never appeared in the topic list (issue #337).
///
/// These tests verify the fix and the Message parsing contract that the fix depends on.
@Suite(.serialized)
struct NotificationDeliveryTests {

    // MARK: - Message.from(userInfo:) parsing

    /// The real ntfy server sends `time` and `priority` as strings.
    /// Parsing must succeed and produce correct field values.
    @Test func messageFromUserInfoParsesStringTypes() {
        let userInfo: [AnyHashable: Any] = [
            "id": "abc123",
            "time": "1739661000",    // string — as sent by the real server
            "event": "message",
            "topic": "topic-parse-string",
            "message": "Hello from ntfy",
            "priority": "3",         // string — as sent by the real server
            "base_url": "https://ntfy.sh"
        ]
        let message = Message.from(userInfo: userInfo)
        #expect(message != nil, "Message.from should succeed when time and priority are strings")
        #expect(message?.id == "abc123")
        #expect(message?.time == 1739661000)
        #expect(message?.event == "message")
        #expect(message?.topic == "topic-parse-string")
        #expect(message?.message == "Hello from ntfy")
        #expect(message?.priority == 3)
    }

    /// If `time` arrives as a JSON integer (e.g. hand-crafted payload), parsing returns nil.
    /// This documents the required payload format: all numeric fields must be strings.
    @Test func messageFromUserInfoFailsWithIntegerTime() {
        let userInfo: [AnyHashable: Any] = [
            "id": "abc456",
            "time": 1739661000,     // integer — wrong format, parser expects String
            "event": "message",
            "topic": "topic-parse-int",
            "message": "Hello from ntfy"
        ]
        #expect(Message.from(userInfo: userInfo) == nil,
                "Message.from must return nil when time is an integer (use string instead)")
    }

    /// Missing required fields must return nil.
    @Test func messageFromUserInfoFailsOnMissingMessage() {
        let userInfo: [AnyHashable: Any] = [
            "id": "abc789",
            "time": "1739661000",
            "event": "message",
            "topic": "topic-parse-missing"
            // "message" is intentionally missing
        ]
        #expect(Message.from(userInfo: userInfo) == nil,
                "Should return nil when the message field is missing")
    }

    // MARK: - Idempotent save (polling deduplication)

    /// Contract test: saving the same message ID multiple times (e.g. NSE then background poll)
    /// must produce exactly one notification in CoreData.
    ///
    /// Implementation note: CoreData's mergeByPropertyStoreTrumpMergePolicyType also prevents
    /// DB duplicates via the uniquenessConstraint on Notification.id. The explicit idempotency
    /// check in Store.save() makes the intent clear and avoids an unnecessary insert + merge cycle.
    @Test func savingDuplicateIdIsIdempotent() {
        let store = Store(inMemory: true)
        let subscription = store.saveSubscription(baseUrl: "https://ntfy.sh", topic: "topic-idem")

        let message = Message(
            id: "idem-001",
            time: 1739661010,
            event: "message",
            topic: "topic-idem",
            message: "Only one copy should exist"
        )

        store.save(notificationFromMessage: message, withSubscription: subscription) // NSE path
        store.save(notificationFromMessage: message, withSubscription: subscription) // background poll path
        store.save(notificationFromMessage: message, withSubscription: subscription) // willPresent path

        store.context.refreshAllObjects()
        #expect(subscription.notificationCount() == 1,
                "Three saves with the same ID must produce exactly one notification")
    }

    /// Two distinct message IDs must both be saved — idempotency must not over-deduplicate.
    @Test func savingDistinctIdsPreservesBoth() {
        let store = Store(inMemory: true)
        let subscription = store.saveSubscription(baseUrl: "https://ntfy.sh", topic: "topic-distinct")

        let first = Message(id: "distinct-001", time: 1739661011, event: "message",
                            topic: "topic-distinct", message: "First")
        let second = Message(id: "distinct-002", time: 1739661012, event: "message",
                             topic: "topic-distinct", message: "Second")

        store.save(notificationFromMessage: first, withSubscription: subscription)
        store.save(notificationFromMessage: second, withSubscription: subscription)

        store.context.refreshAllObjects()
        #expect(subscription.notificationCount() == 2,
                "Two distinct message IDs must each produce a separate notification")
    }

    // MARK: - willPresent save logic

    /// Simulates willPresent receiving a foreground push for a subscribed topic.
    /// The notification must be written to CoreData so it appears in the list.
    @Test func willPresentLogicSavesNotificationForKnownSubscription() {
        let store = Store(inMemory: true)
        let subscription = store.saveSubscription(baseUrl: "https://ntfy.sh", topic: "topic-save-known")

        let userInfo: [AnyHashable: Any] = [
            "id": "save-001",
            "time": "1739661001",
            "event": "message",
            "topic": "topic-save-known",
            "message": "Fix test: notification should appear in list",
            "priority": "3",
            "base_url": "https://ntfy.sh"
        ]

        // Replicate willPresent fix logic
        if let message = Message.from(userInfo: userInfo), message.event == "message" {
            let baseUrl = userInfo["base_url"] as? String ?? Config.appBaseUrl
            if let sub = store.getSubscription(baseUrl: baseUrl, topic: message.topic) {
                store.save(notificationFromMessage: message, withSubscription: sub)
            }
        }

        store.context.refreshAllObjects()
        #expect(subscription.notificationCount() == 1,
                "Notification should be saved to CoreData by the willPresent fix")
    }

    /// willPresent receives a push for a topic that is NOT subscribed — nothing should be saved.
    @Test func willPresentLogicSkipsUnknownTopic() {
        let store = Store(inMemory: true)
        // No subscriptions

        let userInfo: [AnyHashable: Any] = [
            "id": "skip-001",
            "time": "1739661002",
            "event": "message",
            "topic": "topic-skip-unknown",
            "message": "This should not be saved",
            "base_url": "https://ntfy.sh"
        ]

        if let message = Message.from(userInfo: userInfo), message.event == "message" {
            let baseUrl = userInfo["base_url"] as? String ?? Config.appBaseUrl
            if let sub = store.getSubscription(baseUrl: baseUrl, topic: message.topic) {
                store.save(notificationFromMessage: message, withSubscription: sub)
            }
        }

        #expect(store.getSubscription(baseUrl: "https://ntfy.sh", topic: "topic-skip-unknown") == nil,
                "No subscription should exist for an unknown topic")
    }

    /// willPresent must not save keepalive or open events — only "message" events.
    @Test func willPresentLogicSkipsNonMessageEvents() {
        let store = Store(inMemory: true)
        let subscription = store.saveSubscription(baseUrl: "https://ntfy.sh", topic: "topic-keepalive")

        let userInfo: [AnyHashable: Any] = [
            "id": "keepalive-001",
            "time": "1739661003",
            "event": "keepalive",
            "topic": "topic-keepalive",
            "message": "",
            "base_url": "https://ntfy.sh"
        ]

        if let message = Message.from(userInfo: userInfo), message.event == "message" {
            let baseUrl = userInfo["base_url"] as? String ?? Config.appBaseUrl
            if let sub = store.getSubscription(baseUrl: baseUrl, topic: message.topic) {
                store.save(notificationFromMessage: message, withSubscription: sub)
            }
        }

        store.context.refreshAllObjects()
        #expect(subscription.notificationCount() == 0, "Keepalive events must not be saved")
    }

    /// If the NSE already saved the notification before willPresent runs,
    /// a second save with the same ID must not create a duplicate.
    @Test func willPresentDoesNotDuplicateExistingNotification() {
        let store = Store(inMemory: true)
        let subscription = store.saveSubscription(baseUrl: "https://ntfy.sh", topic: "topic-dedup")

        let first = Message(
            id: "dedup-001",
            time: 1739661004,
            event: "message",
            topic: "topic-dedup",
            message: "Already saved by NSE"
        )

        // First save — simulates NSE
        store.save(notificationFromMessage: first, withSubscription: subscription)

        // Second save — simulates willPresent with same ID
        let userInfo: [AnyHashable: Any] = [
            "id": "dedup-001",
            "time": "1739661004",
            "event": "message",
            "topic": "topic-dedup",
            "message": "Already saved by NSE",
            "base_url": "https://ntfy.sh"
        ]
        if let parsed = Message.from(userInfo: userInfo), parsed.event == "message" {
            let baseUrl = userInfo["base_url"] as? String ?? Config.appBaseUrl
            if let sub = store.getSubscription(baseUrl: baseUrl, topic: parsed.topic) {
                store.save(notificationFromMessage: parsed, withSubscription: sub)
            }
        }

        store.context.refreshAllObjects()
        #expect(subscription.notificationCount() == 1,
                "Saving the same notification ID twice must not create a duplicate")
    }
}

// MARK: - Firebase topic subscription

/// Tests for AppDelegate.firebaseTopics(for:) — the logic that maps subscriptions to
/// Firebase topic names. The ~poll topic must always be included; ntfy.sh subscriptions
/// use the plain topic name; self-hosted subscriptions use a SHA256 hash of the URL
/// so the server address is not leaked to Firebase (#1305).
@Suite(.serialized)
struct FirebaseTopicsTests {
    // Hardcoded to avoid depending on Config.appBaseUrl (Bundle.main.infoDictionary) in tests.
    private let ntfyBaseUrl = "https://ntfy.sh"
    private let selfHostedBaseUrl = "https://ntfy.example.com"
    private let poll = "~poll"

    private func topics(_ subscriptions: [Subscription]) -> [String] {
        firebaseTopics(subscriptions: subscriptions, appBaseUrl: ntfyBaseUrl, pollTopic: poll)
    }

    /// No subscriptions — only ~poll must be returned.
    @Test func emptySubscriptionsReturnsPollOnly() {
        #expect(topics([]) == [poll],
                "~poll must always be included even with no subscriptions")
    }

    /// ntfy.sh subscription — topic name is used directly, not hashed.
    @Test func ntfyShSubscriptionUsesPlainTopicName() {
        let store = Store(inMemory: true)
        let sub = store.saveSubscription(baseUrl: ntfyBaseUrl, topic: "alerts")
        let result = topics([sub])
        #expect(result.contains(poll))
        #expect(result.contains("alerts"),
                "ntfy.sh topics must appear as plain names in Firebase")
        #expect(result.count == 2)
    }

    /// Self-hosted subscription — topic must be hashed to avoid leaking the server URL.
    @Test func selfHostedSubscriptionUsesTopicHash() {
        let store = Store(inMemory: true)
        let sub = store.saveSubscription(baseUrl: selfHostedBaseUrl, topic: "alerts")
        let expectedHash = topicHash(baseUrl: selfHostedBaseUrl, topic: "alerts")
        let result = topics([sub])
        #expect(result.contains(poll))
        #expect(result.contains(expectedHash),
                "Self-hosted topics must use SHA256(baseUrl/topic) in Firebase")
        #expect(!result.contains("alerts"),
                "Self-hosted topic plain name must not appear in Firebase")
        #expect(result.count == 2)
    }

    /// Mixed subscriptions — both plain and hashed topics must appear alongside ~poll.
    @Test func mixedSubscriptionsProducesCorrectTopics() {
        let store = Store(inMemory: true)
        let ntfySub = store.saveSubscription(baseUrl: ntfyBaseUrl, topic: "news")
        let selfSub = store.saveSubscription(baseUrl: selfHostedBaseUrl, topic: "private")
        let expectedHash = topicHash(baseUrl: selfHostedBaseUrl, topic: "private")
        let result = topics([ntfySub, selfSub])
        #expect(result.contains(poll))
        #expect(result.contains("news"))
        #expect(result.contains(expectedHash))
        #expect(result.count == 3)
    }

    /// Two self-hosted subscriptions on different servers must produce different hashes.
    @Test func differentServersProduceDifferentHashes() {
        let store = Store(inMemory: true)
        let sub1 = store.saveSubscription(baseUrl: "https://ntfy.server1.com", topic: "topic")
        let sub2 = store.saveSubscription(baseUrl: "https://ntfy.server2.com", topic: "topic")
        let result = topics([sub1, sub2])
        let hashes = result.filter { $0 != poll }
        #expect(Set(hashes).count == 2,
                "Different self-hosted servers with the same topic must produce different hashes")
    }
}

} // NtfyTests
