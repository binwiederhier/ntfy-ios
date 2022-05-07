//
//  Subscription.swift
//  ntfy.sh
//
//  Created by Andrew Cope on 1/15/22.
//

import FirebaseMessaging
import Foundation

class NtfySubscription: ObservableObject, Identifiable {
    
    // Properties
    var id: Int64!
    var baseUrl: String
    var topic: String

    @Published var notifications = [NtfyNotification]()
    var notificationsLoaded = false

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

    func loadNotifications() {
        self.notifications = Database.current.getNotifications(subscription: self)
        self.notificationsLoaded = true
    }

    func notificationCount() -> Int {
        if (!notificationsLoaded) {
            self.loadNotifications()
        }
        return notifications.count
    }

    func lastNotification() -> NtfyNotification? {
        if (!notificationsLoaded) {
            self.loadNotifications()
        }
        return notifications.first
    }

    func fetchNewNotifications(user: NtfyUser?, completionHandler: ( ([NtfyNotification]?, Error?) -> Void)?) {
        var newNotifications = [NtfyNotification]()
        ApiService.shared.poll(subscription: self, user: user) { (notifications, error) in
            if let notifications = notifications {
                for notification in notifications {
                    if (notification.save() != nil) {
                        newNotifications.append(notification)
                    }
                }

                self.notifications = newNotifications.reversed() + self.notifications
            }

            if let completionHandler = completionHandler {
                completionHandler(newNotifications, nil)
            }
        }
    }
}

class NtfySubscriptionList: ObservableObject {
    @Published var subscriptions = [NtfySubscription]()

    init() {
        self.subscriptions = Database.current.getSubscriptions()
    }
}
