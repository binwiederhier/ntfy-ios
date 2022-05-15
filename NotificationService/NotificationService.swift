//
//  NotificationService.swift
//  NotificationService
//
//  A notification service extension to intercept all incoming remote notifications and
//  storing the notification data in SQLite before displaying the notification to the user
//
//  Created by Andrew Cope on 2/7/22.
//

import UserNotifications

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        print("RECEIVED NOTIFICATION")
        if let bestAttemptContent = bestAttemptContent {
            // Modify the notification content here...
            bestAttemptContent.title = "\(bestAttemptContent.title) [modified]"
            
            let userInfo = bestAttemptContent.userInfo
            print("USER INFO")
            dump(userInfo)

            if let notificationId = userInfo["id"] as? String,
               let notificationTopic = userInfo["topic"] as? String,
               let notificationTimestamp = userInfo["time"] as? String,
               let notiticationTimestampInt = Int64(notificationTimestamp),
               let notificationMessage = userInfo["message"] as? String {

                print("Attempting to create notification")
                let notificationTitle = userInfo["title"] as? String ?? ""
                let notificationPriority = Int(userInfo["priority"] as? String ?? "")
                let notificationTags = userInfo["tags"] as? String ?? ""

                let attachmentName = userInfo["attachment_name"] as? String ?? "attachment.bin"
                let attachmentType = userInfo["attachment_type"] as? String ?? ""
                let attachmentSize = Int64(userInfo["attachment_size"] as? String ?? "0") ?? 0
                let attachmentUrl = userInfo["attachment_url"] as? String ?? ""
                let attachmentExpires = Int64(userInfo["attachment_expires"] as? String ?? "0") ?? 0

                if let subscription = Database.current.getSubscription(topic: notificationTopic) {
                    var attachment: NtfyAttachment? = nil
                    if !attachmentUrl.isEmpty {
                        attachment = NtfyAttachment(
                            id: 0,
                            name: attachmentName,
                            type: attachmentType,
                            size: attachmentSize,
                            expires: attachmentExpires,
                            url: attachmentUrl,
                            contentUrl: ""
                        )
                    }

                    let ntfyNotification = NtfyNotification(
                        id: notificationId,
                        subscriptionId: subscription.id,
                        timestamp: notiticationTimestampInt,
                        title: notificationTitle,
                        message: notificationMessage,
                        priority: Int(notificationPriority ?? 3),
                        tags: notificationTags.components(separatedBy: ","),
                        attachment: attachment
                    )
                    ntfyNotification.save()
                    print("Created notification")
                }
            } else {
                print("ERROR")
            }
            
            contentHandler(bestAttemptContent)
        } else {
            print("No best content?")
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

}
