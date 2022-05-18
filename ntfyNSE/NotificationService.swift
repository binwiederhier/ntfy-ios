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
    
    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        print("NotificationService didReceive")
        if let bestAttemptContent = bestAttemptContent {
            bestAttemptContent.title = "\(bestAttemptContent.title) [modified]"
            
            let userInfo = bestAttemptContent.userInfo
            Store.shared.saveNotification(fromUserInfo: userInfo)
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
