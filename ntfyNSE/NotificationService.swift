import UserNotifications
import CoreData

/// This app extension is responsible for persisting the incoming notification to the data store (Core Data). It will eventually be the entity that
/// fetches notification content from selfhosted servers (when a "poll request" is received). This is not implemented yet.
///
/// Note that the app extension does not run as part of the main app, so log messages are not printed in the main Xcode window. To debug,
/// select Debug -> Attach to Process by PID or Name, and select the extension. Don't forget to set a breakpoint, or you're not gonna have a good time.
class NotificationService: UNNotificationServiceExtension {
    private let tag = "NotificationService"
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        Log.d(tag, "Notification received (in service)") // Logs from extensions are not printed in Xcode!

        if let bestAttemptContent = bestAttemptContent {
            let userInfo = bestAttemptContent.userInfo
            
            // Set notification title to short URL if there is no title. The title is always set
            // by the server, but it may be empty.
            if let topic = userInfo["topic"] as? String,
               let title = userInfo["title"] as? String {
                if title == "" {
                    bestAttemptContent.title = topicShortUrl(baseUrl: Config.appBaseUrl, topic: topic)
                }
            }

            // Play a sound, and group by topic
            bestAttemptContent.sound = .default
            bestAttemptContent.threadIdentifier = userInfo["topic"]  as? String ?? ""

            // Map priorities to interruption level (light up screen, ...) and relevance (order)
            let priority = userInfo["priority"] as? String ?? "3"
            switch priority {
            case "1":
                bestAttemptContent.interruptionLevel = .passive
                bestAttemptContent.relevanceScore = 0
            case "2":
                bestAttemptContent.interruptionLevel = .passive
                bestAttemptContent.relevanceScore = 0.25
            case "4":
                bestAttemptContent.interruptionLevel = .timeSensitive
                bestAttemptContent.relevanceScore = 0.75
            case "5":
                bestAttemptContent.interruptionLevel = .critical
                bestAttemptContent.relevanceScore = 1
            default:
                bestAttemptContent.interruptionLevel = .active
                bestAttemptContent.relevanceScore = 0.5
            }
            
            // Save notification to store, and display it
            Store.shared.save(notificationFromUserInfo: userInfo)
            contentHandler(bestAttemptContent)
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content,
        // otherwise the original push payload will be used.
        
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
