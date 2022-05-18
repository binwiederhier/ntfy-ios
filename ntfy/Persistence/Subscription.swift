//
//  Subscription.swift
//  ntfy
//
//  Created by Philipp Heckel on 5/15/22.
//

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
        return notifications!.sortedArray(using: [NSSortDescriptor(key: "time", ascending: false)]) as! [Notification]
    }
}
