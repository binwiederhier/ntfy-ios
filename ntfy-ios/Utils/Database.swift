//
//  Database.swift
//  ntfy.sh
//
//  A SQLite database wrapper to handle insertion, searching,
//  and deletion of notifications and subscrptions
//
//  Created by Andrew Cope on 1/15/22.
//

import Foundation
import SQLite
import StoreKit
import SQLite3

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
    let notification_id = Expression<String>("id")
    let notification_subscription_id = Expression<Int64>("subscriptionId")
    let notification_timestamp = Expression<Int64>("timestamp")
    let notification_title = Expression<String>("title")
    let notification_message = Expression<String>("message")
    let notification_priority = Expression<Int>("priority")
    let notification_tags = Expression<String>("tags")
    let notification_attachment_id = Expression<Int64>("attachmentId")

    // Attachments Table
    let attachments = Table("Attachments")
    var attachment_id = Expression<Int64>("id")
    let attachment_name = Expression<String>("name")
    let attachment_type = Expression<String>("type")
    let attachment_size = Expression<Int64>("size")
    let attachment_expires = Expression<Int64>("expires")
    let attachment_url = Expression<String>("url")
    let attachment_content_url = Expression<String>("contentUrl")

    // Users Table
    let users = Table("Users")
    let user_base_url = Expression<String>("baseUrl")
    let user_username = Expression<String>("username")
    let user_password = Expression<String>("password")

    // Initialize
    init() {
        do {
            let fileManager = FileManager.default
            // Get the App Group path, which is accessed by both the app and the notification service extension
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
                    table.column(notification_id)
                    table.column(notification_subscription_id)
                    table.column(notification_timestamp)
                    table.column(notification_title)
                    table.column(notification_message)
                    table.column(notification_priority)
                    table.column(notification_tags)
                    table.column(notification_attachment_id)
                })

                // Initialize Attachments Table
                try db?.run(attachments.create(ifNotExists: true) { table in
                    table.column(attachment_id, primaryKey: .autoincrement)
                    table.column(attachment_name)
                    table.column(attachment_type)
                    table.column(attachment_size)
                    table.column(attachment_expires)
                    table.column(attachment_url)
                    table.column(attachment_content_url)
                })

                // Initialize Users Table
                try db?.run(users.create(ifNotExists: true) { table in
                    table.column(user_base_url)
                    table.column(user_username)
                    table.column(user_password)
                    table.primaryKey(user_base_url)
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

    func getNotificationCount(subscription: NtfySubscription) -> Int {
        do {
            if let count = try db?.scalar(notifications.filter(notification_subscription_id == subscription.id).count) {
                return count
            }
        } catch {
            print(error.localizedDescription)
        }

        return 0
    }

    func getNotifications(subscription: NtfySubscription, limit: Int = 0) -> [NtfyNotification] {
        var list = [NtfyNotification]()

        do {
            var query = notifications.filter(notification_subscription_id == subscription.id).order(notification_timestamp.desc)
            if limit > 0 {
                query = query.limit(limit)
            }
            if let result = try db?.prepare(query) {
                for line in result {
                    var attachment: NtfyAttachment? = nil
                    let attachmentId = try line.get(notification_attachment_id)
                    if attachmentId != 0 {
                        if let attachmentResult = try db?.pluck(attachments.filter(attachment_id == attachmentId)) {
                            attachment = NtfyAttachment(
                                id: try attachmentResult.get(attachment_id),
                                name: try attachmentResult.get(attachment_name),
                                type: try attachmentResult.get(attachment_type),
                                size: try attachmentResult.get(attachment_size),
                                expires: try attachmentResult.get(attachment_expires),
                                url: try attachmentResult.get(attachment_url),
                                contentUrl: try attachmentResult.get(attachment_content_url)
                            )
                        }
                    }
                    list.append(
                        NtfyNotification(
                            id: try line.get(notification_id),
                            subscriptionId: try line.get(notification_subscription_id),
                            timestamp: try line.get(notification_timestamp),
                            title: try line.get(notification_title),
                            message: try line.get(notification_message),
                            priority: try line.get(notification_priority),
                            tags: try line.get(notification_tags).components(separatedBy: ","),
                            attachment: attachment
                        )
                    )
                }
            }
        } catch {
            print(error.localizedDescription)
        }

        return list
    }

    func addNotification(notification: NtfyNotification) -> NtfyNotification {
        do {
            var attachmentId: Int64 = 0
            if notification.attachment != nil {
                attachmentId = addAttachment(attachment: notification.attachment!) ?? 0
            }
            try db?.run(notifications.insert(
                notification_id <- notification.id,
                notification_subscription_id <- notification.subscriptionId,
                notification_timestamp <- notification.timestamp,
                notification_title <- notification.title,
                notification_message <- notification.message,
                notification_priority <- notification.priority,
                notification_tags <- notification.tags.joined(separator: ","),
                notification_attachment_id <- attachmentId
            ))
        } catch let Result.error(message, code, _) where code == SQLITE_CONSTRAINT {
            // Likely means that the notification already exists
            print("Constraint failed: \(message)")
        } catch let Result.error(message, code, _) {
            print(message)
            print(code)
        } catch let error {
            print(error.localizedDescription)
        }

        return notification
    }

    func deleteNotification(notification: NtfyNotification) {
        do {
            if notification.id.isEmpty {
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

    func addAttachment(attachment: NtfyAttachment) -> Int64? {
        do {
            return try db?.run(attachments.insert(
                attachment_name <- attachment.name,
                attachment_type <- attachment.type,
                attachment_size <- attachment.size,
                attachment_expires <- attachment.expires,
                attachment_url <- attachment.url,
                attachment_content_url <- attachment.contentUrl
            ))
        } catch {
            print("Error saving attachment: \(error)")
            return nil
        }
    }

    func updateAttachment(attachment: NtfyAttachment) {
        do {
            let dbAttachment = attachments.filter(attachment_id == attachment.id)
            try db?.run(dbAttachment.update(
                attachment_content_url <- attachment.contentUrl
            ))
        } catch {
            print("Error updating attachment: \(error)")
        }
    }

    func addUser(user: NtfyUser) {
        do {
            try db?.run(users.insert(
                user_base_url <- user.baseUrl,
                user_username <- user.username,
                user_password <- user.password
            ))
        } catch {
            print(error)
        }
    }

    func findUser(baseUrl: String) -> NtfyUser? {
        do {
            if let result = try db?.pluck(users.filter(user_base_url == baseUrl)) {
                return NtfyUser(
                    baseUrl: try result.get(user_base_url),
                    username: try result.get(user_username),
                    password: try result.get(user_password)
                )
            }
        } catch {
            print(error)
        }
        return nil
    }
}
