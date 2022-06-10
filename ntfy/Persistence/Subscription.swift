import Foundation



// 2022-06-10 07:53:45.246000-0400 ntfyApp [WARNING ⚠️] Attachment: Error loading image attachment from   /private/var/mobile/Containers/Shared/AppGroup/C133CAD1-A47F-4A3B-9874-8065E6D0E11C/7GJ8WIZazmTZ.jpg, URL: file:///private/var/mobile/Containers/Shared/AppGroup/C133CAD1-A47F-4A3B-9874-8065E6D0E11C/7GJ8WIZazmTZ.jpg
// 2022-06-10 07:54:06.839000-0400 ntfyApp [DEBUG] Attachment: Successfulluy loaded image attachment from /private/var/mobile/Containers/Shared/AppGroup/C133CAD1-A47F-4A3B-9874-8065E6D0E11C/Library/Caches/attachments/3nivZKSMMu7d.jpg, URL: file:///private/var/mobile/Containers/Shared/AppGroup/C133CAD1-A47F-4A3B-9874-8065E6D0E11C/Library/Caches/attachments/3nivZKSMMu7d.jpg

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
        return notificationsSorted().first
    }
    
    func notificationsSorted() -> [Notification] {
        if let notifications = notifications {
            return notifications.sortedArray(using: [NSSortDescriptor(keyPath: \Notification.time, ascending: false)]) as! [Notification]
        }
        return []
    }
}
