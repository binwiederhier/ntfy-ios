import Foundation
import FirebaseMessaging

/// Manager to combine persisting a subscription to the data store and subscribing to Firebase.
/// This is to centralize the logic in one place.
struct SubscriptionManager {
    private let tag = "Store"
    var store: Store
    
    func subscribe(baseUrl: String, topic: String) {
        Log.d(tag, "Subscribing to \(topicUrl(baseUrl: appBaseUrl, topic: topic))")
        Messaging.messaging().subscribe(toTopic: topic)
        store.saveSubscription(baseUrl: baseUrl, topic: topic)
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
}
