import Foundation

extension Subscription {
    func urlString() -> String {
        return topicUrl(baseUrl: baseUrl ?? "?", topic: topic ?? "?")
    }
    
    func displayName() -> String {
        return topicShortUrl(baseUrl: baseUrl ?? "?", topic: topic ?? "?")
    }
    
    func topicName() -> String {
        return topic ?? "?"
    }
    
    func urlHash() -> String {
        return topicHash(baseUrl: baseUrl ?? "?", topic: topic ?? "?")
    }
    
    func notificationCount() -> Int {
        return notifications?.count ?? 0
    }
    
    func lastNotification() -> Notification? {
        guard let notifications else {
            return nil
        }
        return notifications
            .sortedArray(using: [NSSortDescriptor(keyPath: \Notification.time, ascending: false)])
            .first as? Notification
    }
}

extension Subscription {
    /// Time of the newest notification in this topic, or 0 if there is none.
    func lastNotificationTime() -> Int64 {
        guard let notifications else {
            return 0
        }
        var newest: Int64 = 0
        for case let notification as Notification in notifications where notification.time > newest {
            newest = notification.time
        }
        return newest
    }
}
