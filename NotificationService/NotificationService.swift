//
//  NotificationService.swift
//  NotificationService
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
            print(userInfo)
            
            if //let notificationId = userInfo["id"] as? Int64,
               let notificationTopic = userInfo["topic"] as? String,
               //let notificationTimestamp = userInfo["time"] as? Int64,
               let notificationTitle = userInfo["title"] as? String,
               let notificationMessage = userInfo["message"] as? String {
              print("Attempting to create notification")
              if let subscription = Database.current.getSubscription(topic: notificationTopic) {
                let ntfyNotification = NtfyNotification(id: Int64(1), subscriptionId: subscription.id, timestamp: Int64(0), title: notificationTitle, message: notificationMessage)
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
