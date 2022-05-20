import Foundation
import FirebaseMessaging

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
            store.deleteSubscription(subscription: subscription)
        }
    }
}
