//
//  Subscription.swift
//  ntfy.sh
//
//  Created by Andrew Cope on 1/15/22.
//

import FirebaseMessaging
import Foundation

class NtfySubscription: Identifiable {
    
    // Properties
    var id: Int64!
    var baseUrl: String
    var topic: String

    init(id: Int64, baseUrl: String, topic: String) {
        // Initialize values
        self.id = id
        self.baseUrl = baseUrl
        self.topic = topic
    }

    func urlString() -> String {
        return self.baseUrl + "/" + self.topic
    }

    func displayName() -> String {
        let url = URL(string: urlString())
        return url!.host! + url!.path
    }

    func save() -> NtfySubscription {
        Database.current.addSubscription(subscription: self)
    }

    func subscribe(to topic: String) {
        Messaging.messaging().subscribe(toTopic: topic)
    }

    func delete() {
        Database.current.deleteSubscription(subscription: self)
        self.unsubscribe(from: self.topic)
    }

    func unsubscribe(from topic: String) {
        Messaging.messaging().unsubscribe(fromTopic: topic)
    }

    func notificationCount() -> Int {
        Database.current.getNotificationCount(subscription: self)
    }

    func lastNotification() -> NtfyNotification? {
        Database.current.getNotifications(subscription: self, limit: 1).first
    }

    func fetchNewNotifications(user: NtfyUser?) -> [NtfyNotification] {
        var newNotifications = [NtfyNotification]()
        ApiService.shared.poll(subscription: self, user: user) { (notifications, error) in
            if let notifications = notifications {
                for notification in notifications {
                    notification.save()
                    newNotifications.append(notification)
                }
            }
        }
        return newNotifications
    }
}
