import Foundation
import UIKit

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

    func iconImage() -> UIImage? {
        guard let iconPath = iconPath, !iconPath.isEmpty else {
            return nil
        }
        return UIImage(contentsOfFile: iconPath)
    }
}
