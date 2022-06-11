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
        guard let subscription = self.store?.getSubscription(baseUrl: baseUrl, topic: message.topic) else {
            Log.w(self.tag, "Subscription \(topicUrl(baseUrl: baseUrl, topic: message.topic)) unknown")
            contentHandler(request.content)
            return
        }
        
        // Modify notification based on message
        content.modify(message: message, baseUrl: baseUrl)
      
        // If there is one (and it's eligible), download attachment
        maybeDownloadAttachment(message, content) { contentUrl in
            var message = message
            if message.attachment != nil {
                message.attachment!.contentUrl = contentUrl
            }
            Store.shared.saveNotification(fromMessage: message, withSubscription: subscription)
            contentHandler(content)
        }
    }
    
    // This helped a lot: https://medium.com/gits-apps-insight/processing-notification-data-using-notification-service-extension-6a2b5ea2da17
    private func maybeDownloadAttachment(_ message: Message, _ content: UNMutableNotificationContent, completionHandler: @escaping (String?) -> Void) {
        guard let attachment = message.attachment, !timeExpired(attachment.expires) else {
            completionHandler(nil)
            return
        }
        AttachmentManager.download(url: attachment.url, id: message.id, withMaxLength: 300000) { contentUrl, error in
            if let contentUrl = contentUrl {
                do {
                    // Create temp file copy of the file (for the iOS notification). Turns out that iOS deletes
                    // the notification attachment file after it has been displayed. This took me days to figure out!
                    let fileManager = FileManager.default
                    let tempFileUrl = fileManager.temporaryDirectory
                        .appendingPathComponent(NSUUID().uuidString)
                        .appendingPathExtension(contentUrl.pathExtension)
                    try fileManager.copyItem(at: contentUrl, to: tempFileUrl)
                    
                    // Attach it to the notification
                    let notificationAttachment = try UNNotificationAttachment.init(identifier: message.id, url: tempFileUrl, options: nil)
                    content.attachments = [notificationAttachment]
                } catch {
                    Log.w(self.tag, "Error attaching image to notification", error)
                }
            }
            // Return file path as "contentUrl" in attachment (regardless of whether we displayed it, or not)
            completionHandler(contentUrl?.path) // May be nil!
        }
    }
    
    private func handlePollRequest(_ request: UNNotificationRequest, _ content: UNMutableNotificationContent, _ pollRequest: Message, _ contentHandler: @escaping (UNNotificationContent) -> Void) {
        let subscription = store?.getSubscriptions()?.first { $0.urlHash() == pollRequest.topic }
        let baseUrl = subscription?.baseUrl
        guard
            let subscription = subscription,
            let pollId = pollRequest.pollId,
            let baseUrl = baseUrl
        else {
            Log.w(tag, "Cannot find subscription", pollRequest)
            contentHandler(request.content)
            return
        }
        
        // Poll original server
        let user = store?.getUser(baseUrl: baseUrl)?.toBasicUser()
        let semaphore = DispatchSemaphore(value: 0)
        ApiService.shared.poll(subscription: subscription, messageId: pollId, user: user) { message, error in
            guard let message = message else {
                Log.w(self.tag, "Error fetching message", error)
                contentHandler(request.content)
                return
            }
            // FIXME: Check that notification is not already there (in DB and via notification center!)
            self.handleMessage(request, content, baseUrl, message, contentHandler)
            semaphore.signal()
        }
        
        // Note: If notifications only show up as "New message", it may be because the "return" statement
        // happens before the contentHandler() is called. We add this semaphore here to synchronize the threads.
        // I don't know if this is necessary, but it feels like the right thing to do.
        
        _ = semaphore.wait(timeout: DispatchTime.now() + 25) // 30 seconds is the max for the entire extension
    }
}
