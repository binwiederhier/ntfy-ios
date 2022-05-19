import Foundation

extension Subscription {
    func urlString() -> String {
        return topicUrl(baseUrl: baseUrl!, topic: topic!)
    }
    
    func displayName() -> String {
        return topic ?? "<unknown>"
    }
    
    func notificationCount() -> Int {
        return notifications?.count ?? 0
    }
    
    func lastNotification() -> Notification? {
        return notificationsSorted().first
    }
    
    func notificationsSorted() -> [Notification] {
        if let notifications = notifications {
            return notifications.sortedArray(using: [NSSortDescriptor(key: "time", ascending: false)]) as! [Notification]
        }
        return []
    }
}
