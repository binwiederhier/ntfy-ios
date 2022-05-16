//
//  NotificationService.swift
//  ntfyNSE
//
//  Created by Philipp Heckel on 5/13/22.
//

import UserNotifications
import CoreData

// https://debashishdas3100.medium.com/save-push-notifications-to-coredata-userdefaults-ios-swift-5-ea074390b57

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
//    var store: Store?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        if let bestAttemptContent = bestAttemptContent {
            // Modify the notification content here...
            bestAttemptContent.title = "\(bestAttemptContent.title) [modified]"
            
            let userInfo = bestAttemptContent.userInfo
            dump(userInfo)
            if let notificationId = userInfo["id"] as? String,
                           let notificationTimestamp = userInfo["time"] as? String,
                           let notificationTimestampInt = Int64(notificationTimestamp),
                           let notificationMessage = userInfo["message"] as? String {
                print("notification service \(notificationId)")
/*                let notification = Notification(context: context)
                notification.id = notificationId
                notification.time = notificationTimestampInt
                notification.message = notificationMessage*/
            }
                        
            contentHandler(bestAttemptContent)
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
