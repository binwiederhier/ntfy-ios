import UserNotifications
import CoreData

/// This app extension is responsible for persisting the incoming notification to the data store (Core Data). It will eventually be the entity that
/// fetches notification content from selfhosted servers (when a "poll request" is received). This is not implemented yet.
///
/// Note that the app extension does not run as part of the main app, so log messages are not printed in the main Xcode window. To debug,
/// select Debug -> Attach to Process by PID or Name, and select the extension. Don't forget to set a breakpoint, or you're not gonna have a good time.
class NotificationService: UNNotificationServiceExtension {
    private let tag = "NotificationService"
    private let actionsCategory = "ntfyActions" // It seems ok to re-use the same category
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        Log.d(tag, "Notification received (in service)") // Logs from extensions are not printed in Xcode!

        if let bestAttemptContent = bestAttemptContent {
            let userInfo = bestAttemptContent.userInfo
            
            // Get all the things
            let event = userInfo["event"]  as? String ?? ""
            let baseUrl = userInfo["base_url"]  as? String ?? Config.appBaseUrl
            let topic = userInfo["topic"]  as? String ?? ""
            let title = userInfo["title"] as? String
            let priority = userInfo["priority"] as? String ?? "3"
            let tags = userInfo["tags"] as? String
            let actions = userInfo["actions"] as? String ?? "[]"

            // Only handle "message" events
            if event != "message" {
                contentHandler(request.content)
                return
            }
            
            // Set notification title to short URL if there is no title. The title is always set
            // by the server, but it may be empty.
            if let title = title, title == "" {
                bestAttemptContent.title = topicShortUrl(baseUrl: baseUrl, topic: topic)
            }
            
            // Emojify title or message
            let emojiTags = parseEmojiTags(tags)
            if !emojiTags.isEmpty {
                if let title = title, title != "" {
                    bestAttemptContent.title = emojiTags.joined(separator: "") + " " + bestAttemptContent.title
                } else {
                    bestAttemptContent.body = emojiTags.joined(separator: "") + " " + bestAttemptContent.body
                }
            }
            
            // Add custom actions
            //
            // We re-define the categories every time here, which is weird, but it works. When tapped, the action sets the
            // actionIdentifier in the application(didReceive) callback. This logic is handled in the AppDelegate. This approach
            // is described in a comment in https://stackoverflow.com/questions/30103867/changing-action-titles-in-interactive-notifications-at-run-time#comment122812568_30107065
            //
            // We also must set the .foreground flag, which brings the notification to the foreground and avoids an error about
            // permissions. This is described in https://stackoverflow.com/a/44580916/1440785
            if let actions = Actions.shared.parse(actions), !actions.isEmpty {
                bestAttemptContent.categoryIdentifier = actionsCategory

                let center = UNUserNotificationCenter.current()
                let notificationActions = actions.map { UNNotificationAction(identifier: $0.id, title: $0.label, options: [.foreground]) }
                let category = UNNotificationCategory(identifier: actionsCategory, actions: notificationActions, intentIdentifiers: [])
                center.setNotificationCategories([category])
            }
                        
            // Play a sound, and group by topic
            bestAttemptContent.sound = .default
            bestAttemptContent.threadIdentifier = topic

            // Map priorities to interruption level (light up screen, ...) and relevance (order)
            if #available(iOS 15.0, *) {
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
