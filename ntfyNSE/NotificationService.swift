import UserNotifications
import CoreData
import CryptoKit

/// This app extension is responsible for persisting the incoming notification to the data store (Core Data). It will eventually be the entity that
/// fetches notification content from selfhosted servers (when a "poll request" is received). This is not implemented yet.
///
/// Note that the app extension does not run as part of the main app, so log messages are not printed in the main Xcode window. To debug,
/// select Debug -> Attach to Process by PID or Name, and select the extension. Don't forget to set a breakpoint, or you're not gonna have a good time.
class NotificationService: UNNotificationServiceExtension {
    private let tag = "NotificationService"
    private var store: Store?
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.store = Store.shared
        self.contentHandler = contentHandler
        self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        Log.d(tag, "Notification received (in service)") // Logs from extensions are not printed in Xcode!

        if let bestAttemptContent = bestAttemptContent {
            let userInfo = bestAttemptContent.userInfo
            guard let message = Message.from(userInfo: userInfo) else {
                Log.w(tag, "Message cannot be parsed from userInfo", userInfo)
                contentHandler(request.content)
                return
            }
            switch message.event {
            case "poll_request":
                handlePollRequest(request, bestAttemptContent, message, contentHandler)
            case "message":
                let baseUrl = userInfo["base_url"]  as? String ?? Config.appBaseUrl // messages only come for the main server
                handleMessage(request, bestAttemptContent, baseUrl, message, contentHandler)
            default:
                Log.w(tag, "Irrelevant message received", message)
                contentHandler(request.content)
            }
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
    
    private func handleMessage(_ request: UNNotificationRequest, _ content: UNMutableNotificationContent, _ baseUrl: String, _ message: Message, _ contentHandler: @escaping (UNNotificationContent) -> Void) {
        // Modify notification based on message
        content.modify(message: message, baseUrl: baseUrl)
        
        // Save notification to store, and display it
        guard let subscription = store?.getSubscription(baseUrl: baseUrl, topic: message.topic) else {
            Log.w(tag, "Subscription \(topicUrl(baseUrl: baseUrl, topic: message.topic)) unknown")
            contentHandler(request.content)
            return
        }
        Store.shared.save(notificationFromMessage: message, withSubscription: subscription)
        let user = store?.getUser(baseUrl: baseUrl)?.toBasicUser()
        content.attachImageIfNeeded(message: message, user: user) {
            contentHandler(content)
        }
    }
    
    private func handlePollRequest(_ request: UNNotificationRequest, _ content: UNMutableNotificationContent, _ pollRequest: Message, _ contentHandler: @escaping (UNNotificationContent) -> Void) {
        let subscription = store?.getSubscriptions()?.first { subscription in
            // Poll requests usually target the hashed topic URL, but tolerate raw topic payloads too
            subscription.urlHash() == pollRequest.topic || subscription.topic == pollRequest.topic
        }
        let baseUrl = subscription?.baseUrl
        let pollId = pollRequest.pollId ?? pollRequest.id
        guard
            let subscription = subscription,
            let baseUrl = baseUrl
        else {
            Log.w(tag, "Cannot find subscription for poll request topic=\(pollRequest.topic), pollId=\(pollRequest.pollId ?? "<nil>")")
            contentHandler(request.content)
            return
        }
        
        // Poll original server
        let user = store?.getUser(baseUrl: baseUrl)?.toBasicUser()
        // The extension only needs contentHandler to be called from the async callback
        ApiService.shared.poll(subscription: subscription, messageId: pollId, user: user) { message, error in
            guard let message = message else {
                Log.w(self.tag, "Error fetching poll request message topic=\(pollRequest.topic), pollId=\(pollId), subscription=\(subscription.urlString())", error)
                contentHandler(request.content)
                return
            }
            self.handleMessage(request, content, baseUrl, message, contentHandler)
        }
    }
}
