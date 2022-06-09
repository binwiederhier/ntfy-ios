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
        
        // If there is one (and it's eligible), download attachment
        maybeDownloadAttachment(message, content)
        
        // Save notification to store, and display it
        guard let subscription = store?.getSubscription(baseUrl: baseUrl, topic: message.topic) else {
            Log.w(tag, "Subscription \(topicUrl(baseUrl: baseUrl, topic: message.topic)) unknown")
            contentHandler(request.content)
            return
        }
        Store.shared.save(notificationFromMessage: message, withSubscription: subscription)
        contentHandler(content)
    }
    
    private func maybeDownloadAttachment(_ message: Message, _ content: UNMutableNotificationContent) {
        // This helped a lot: https://medium.com/gits-apps-insight/processing-notification-data-using-notification-service-extension-6a2b5ea2da17
        guard var attachment = message.attachment else { return }
        do {
            // Parse URL and download
            let url = try URL(string: attachment.url).orThrow("URL \(attachment.url) is not valid")
            let data = try Data(contentsOf: url)
            let contentUrl = try DownloadManager.download(id: message.id, data: data, options: nil)

            // Once downloaded, set "contentUrl" in attachment, so we persist it later.
            attachment.contentUrl = contentUrl.absoluteString
            
            // Now try to attach it to the notification
            let notificationAttachment = try UNNotificationAttachment.init(identifier: message.id, url: contentUrl, options: nil)
            content.attachments = [notificationAttachment]
        } catch {
            Log.w(tag, "Error downloading attachment", error)
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

extension UNNotificationAttachment {
    /// Save the image to disk
    static func create(imageFileIdentifier: String, data: NSData, options: [NSObject : AnyObject]?) -> UNNotificationAttachment? {
        let fileManager = FileManager.default
        let tmpSubFolderName = ProcessInfo.processInfo.globallyUniqueString
        let tmpSubFolderURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(tmpSubFolderName, isDirectory: true)

        do {
            // https://stackoverflow.com/questions/45226847/unnotificationattachment-failing-to-attach-image#comment108519977_51081941
            try fileManager.createDirectory(at: tmpSubFolderURL!, withIntermediateDirectories: true, attributes: nil)
            let fileURL = tmpSubFolderURL?.appendingPathComponent(imageFileIdentifier + ".jpg")
            try data.write(to: fileURL!, options: [])
            let imageAttachment = try UNNotificationAttachment.init(identifier: imageFileIdentifier, url: fileURL!, options: options)
            return imageAttachment
        } catch let error {
            print("error \(error)")
        }
        return nil
    }
}
