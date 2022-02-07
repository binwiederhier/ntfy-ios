//
//  Database.swift
//  ntfy.sh
//
//  Created by Andrew Cope on 1/15/22.
//

import Foundation
import SQLite
import StoreKit

class Database {
    // Static instance
    static let current = Database()

    // Connection
    private var db: Connection?

    // Subscriptions Table
    let subscriptions = Table("Subscription")
    let subscription_id = Expression<Int64>("id")
    let subscription_base_url = Expression<String>("baseUrl")
    let subscription_topic = Expression<String>("topic")

    // Notifications Table
    let notifications = Table("Notifications")
    let notification_id = Expression<Int64>("id")
    let notification_subscription_id = Expression<Int64>("subscriptionId")
    let notification_timestamp = Expression<Int64>("timestamp")
    let notification_title = Expression<String>("title")
    let notification_message = Expression<String>("message")

    // Initialize
    init() {
        do {
            let fileManager = FileManager.default
            if let path = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.ntfy") {
                // Connect to the database
                db = try Connection("\(path.path)/ntfy.sh.sqlite3")

                // Initialize Subscriptions table
                try db?.run(subscriptions.create(ifNotExists: true) { table in
                    table.column(subscription_id, primaryKey: .autoincrement)
                    table.column(subscription_base_url)
                    table.column(subscription_topic)
                })

                // Initialize Notifications Table
                try db?.run(notifications.create(ifNotExists: true) { table in
                    table.column(notification_id, primaryKey: .autoincrement)
                    table.column(notification_subscription_id)
                    table.column(notification_timestamp)
                    table.column(notification_title)
                    table.column(notification_message)
                })
            }
        } catch {
            print(error.localizedDescription)
        }
    }

    func getSubscriptions() -> [NtfySubscription] {
        var list = [NtfySubscription]()

        do {
            if let result = try db?.prepare(subscriptions.order(subscription_id.asc)) {
                for line in result {
                    list.append(NtfySubscription(id: try line.get(subscription_id), baseUrl: try line.get(subscription_base_url), topic: try line.get(subscription_topic)))
                }
            }
        } catch {
            print(error.localizedDescription)
        }

        return list
    }

    func getSubscription(topic: String) -> NtfySubscription? {
        print("Getting subscription")
        do {
            print("Looking for subscription for topic " + topic)
            if let subscription = try db?.pluck(subscriptions.filter(subscription_topic == topic)) {
                print("Found subscription")
                return NtfySubscription(id: try subscription.get(subscription_id), baseUrl: try subscription.get(subscription_base_url), topic: try subscription.get(subscription_topic))
            } else {
                print("Did not find subscription")
            }
        } catch {
            print(error.localizedDescription)
        }
        
        return nil
    }

    func addSubscription(subscription: NtfySubscription) -> NtfySubscription {
        do {
            let id = try db?.run(subscriptions.insert(subscription_base_url <- subscription.baseUrl, subscription_topic <- subscription.topic))

            subscription.id = id
        } catch {
            print(error.localizedDescription)
        }

        return subscription
    }

    func deleteSubscription(subscription: NtfySubscription) {
        do {
            if subscription.id == 0 {
                return
            }

            let line = subscriptions.filter(subscription_id == subscription.id)

            try db?.run(line.delete())
        } catch {
            print(error.localizedDescription)
        }
    }

    func getNotifications(subscription: NtfySubscription) -> [NtfyNotification] {
        var list = [NtfyNotification]()

        do {
            if let result = try db?.prepare(notifications.filter(notification_subscription_id == subscription.id).order(subscription_id.asc)) {
                for line in result {
                    list.append(NtfyNotification(id: try line.get(notification_id), subscriptionId: try line.get(notification_subscription_id), timestamp: try line.get(notification_timestamp), title: try line.get(notification_title), message: try line.get(notification_message)))
                }
            }
        } catch {
            print(error.localizedDescription)
        }

        return list
    }

    func addNotification(notification: NtfyNotification) -> NtfyNotification {
        do {
            let id = try db?.run(notifications.insert(notification_subscription_id <- notification.subscriptionId, notification_timestamp <- notification.timestamp, notification_title <- notification.title, notification_message <- notification.message))

            notification.id = id
        } catch {
            print(error.localizedDescription)
        }

        return notification
    }

    func deleteNotification(notification: NtfyNotification) {
        do {
            if notification.id == 0 {
                return
            }

            let line = notifications.filter(notification_id == notification.id)

            try db?.run(line.delete())
        } catch {
            print(error.localizedDescription)
        }
    }

    func deleteNotificationsForSubscription(subscription: NtfySubscription) {
        do {
            if (subscription.id == 0) {
                return
            }

            let lines = notifications.filter(notification_subscription_id == subscription.id)

            try db?.run(lines.delete())
        } catch {
            print(error.localizedDescription)
        }
    }
}
