import Foundation
import FirebaseMessaging

/// Manager to combine persisting a subscription to the data store and subscribing to Firebase.
/// This is to centralize the logic in one place.
struct SubscriptionManager {
    private let tag = "Store"
    var store: Store
    
    func subscribe(baseUrl: String, topic: String) {
        Log.d(tag, "Subscribing to \(topicUrl(baseUrl: baseUrl, topic: topic))")
        if baseUrl == Config.appBaseUrl {
            Messaging.messaging().subscribe(toTopic: topic)
        } else {
            Messaging.messaging().subscribe(toTopic: topicHash(baseUrl: baseUrl, topic: topic))
        }
        let subscription = store.saveSubscription(baseUrl: baseUrl, topic: topic)
        poll(subscription)
    }
    
    func unsubscribe(_ subscription: Subscription) {
        Log.d(tag, "Unsubscribing from \(subscription.urlString())")
        DispatchQueue.main.async {
            if let baseUrl = subscription.baseUrl, let topic = subscription.topic {
                if baseUrl == Config.appBaseUrl {
                    Messaging.messaging().unsubscribe(fromTopic: topic)
                } else {
                    Messaging.messaging().unsubscribe(fromTopic: topicHash(baseUrl: baseUrl, topic: topic))
                }
            }
            store.delete(subscription: subscription)
        }
    }
    
    func poll(_ subscription: Subscription) {
        poll(subscription) { _ in }
    }
    
    func backgroundPoll(_ subscription: Subscription, completionHandler: @escaping ([Message]) -> Void) {
        let user = store.getUser(baseUrl: subscription.baseUrl!)?.toBasicUser()
        Log.d(tag, "Polling from \(subscription.urlString()) with user \(user?.username ?? "anonymous")")
        let backgroundConfig = URLSessionConfiguration.background(withIdentifier: "com.example.myapp.background")
        let backgroundSession = URLSession(configuration: backgroundConfig, delegate: nil, delegateQueue: nil)
        
        ApiService(session: backgroundSession).poll(subscription: subscription, user: user) { messages, error in
            guard let messages = messages else {
                Log.e(tag, "Polling failed", error)
                completionHandler([])
                return
            }
            Log.d(tag, "Polling success, \(messages.count) new message(s)", messages)
            if !messages.isEmpty {
                DispatchQueue.main.sync {
                    for message in messages {
                        store.save(notificationFromMessage: message, withSubscription: subscription)
                    }
                }
            }
            completionHandler(messages)
        }
    }
    
    func poll(_ subscription: Subscription, completionHandler: @escaping ([Message]) -> Void) {
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
                DispatchQueue.main.sync {
                    for message in messages {
                        store.save(notificationFromMessage: message, withSubscription: subscription)
                    }
                }
            }
            completionHandler(messages)
        }
    }
}
