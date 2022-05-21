import Foundation
import FirebaseMessaging

/// Manager to combine persisting a subscription to the data store and subscribing to Firebase.
/// This is to centralize the logic in one place.
struct SubscriptionManager {
    private let tag = "Store"
    var store: Store
    
    func subscribe(baseUrl: String, topic: String) {
        Log.d(tag, "Subscribing to \(topicUrl(baseUrl: baseUrl, topic: topic))")
        Messaging.messaging().subscribe(toTopic: topic)
        let subscription = store.saveSubscription(baseUrl: baseUrl, topic: topic)
        poll(subscription)
    }
    
    func unsubscribe(_ subscription: Subscription) {
        Log.d(tag, "Unsubscribing from \(subscription.urlString())")
        DispatchQueue.main.async {
            if let topic = subscription.topic {
                Messaging.messaging().unsubscribe(fromTopic: topic)
            }
            store.delete(subscription: subscription)
        }
    }
    
    func poll(_ subscription: Subscription) {
        Log.d(tag, "Polling from \(subscription.urlString())")
        ApiService.shared.poll(subscription: subscription) { messages, error in
            guard let messages = messages else {
                Log.e(tag, "Polling failed", error)
                return
            }
            Log.d(tag, "Polling success, \(messages.count) new message(s)", messages)
            if !messages.isEmpty {
                DispatchQueue.main.async {
                    for message in messages {
                        store.save(notificationFromMessage: message, withSubscription: subscription)
                    }
                }
            }
        }
    }
}
