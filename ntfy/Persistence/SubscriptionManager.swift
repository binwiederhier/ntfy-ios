import Foundation
import FirebaseMessaging

/// Manager to combine persisting a subscription to the data store and subscribing to Firebase.
/// This is to centralize the logic in one place.
struct SubscriptionManager {
    private let tag = "SubscriptionManager"
    var store: Store
    
    func subscribe(baseUrl: String, topic: String) {
        let normalizedBaseUrl = normalizeBaseUrl(baseUrl)
        Log.d(tag, "Subscribing to \(topicUrl(baseUrl: normalizedBaseUrl, topic: topic))")
        Messaging.messaging().subscribe(toTopic: firebaseTopic(baseUrl: normalizedBaseUrl, topic: topic))
        let subscription = store.saveSubscription(baseUrl: normalizedBaseUrl, topic: topic)
        poll(subscription)
    }
    
    func unsubscribe(_ subscription: Subscription) {
        Log.d(tag, "Unsubscribing from \(subscription.urlString())")
        DispatchQueue.main.async {
            if let baseUrl = subscription.baseUrl, let topic = subscription.topic {
                Messaging.messaging().unsubscribe(fromTopic: firebaseTopic(baseUrl: baseUrl, topic: topic))
            }
            store.delete(subscription: subscription)
        }
    }
    
    func poll(_ subscription: Subscription) {
        poll(subscription) { _ in }
    }
    
    func poll(_ subscription: Subscription, completionHandler: @escaping ([Message]) -> Void) {
        // This is a bit of a hack but it prevents us from polling dead subscriptions
        if (subscription.baseUrl == nil) {
            Log.d(tag, "Attempting to poll dead subscription failed")
            completionHandler([])
            return
        }
        
        let user = store.getUser(baseUrl: subscription.baseUrl!)?.toBasicUser()
        Log.d(tag, "Polling from \(subscription.urlString()) with user \(user?.username ?? "anonymous")")
        ApiService.shared.poll(subscription: subscription, user: user) { messages, error in
            guard let messages = messages else {
                Log.e(tag, "Polling failed", error)
                completionHandler([])
                return
            }
            Log.d(tag, "Polling success, \(messages.count) new message(s)", messages)
            if !messages.isEmpty {
                for message in messages {
                    store.save(notificationFromMessage: message, withSubscription: subscription)
                }
            }
            completionHandler(messages)
        }
    }
}
