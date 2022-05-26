import UIKit
import SafariServices
import UserNotifications
import Firebase
import FirebaseCore
import CoreData

class AppDelegate: UIResponder, UIApplicationDelegate, ObservableObject {
    private let tag = "AppDelegate"
    private let pollTimerTopic = "~poll" // See ntfy server if ever changed
    
    // Implements navigation from notifications, see https://stackoverflow.com/a/70731861/1440785
    @Published var selectedBaseUrl: String? = nil

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Log.d(tag, "Launching AppDelegate")
        
        // Register app permissions for push notifications
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            guard success else {
                Log.e(self.tag, "Failed to register for local push notifications", error)
                return
            }
            Log.d(self.tag, "Successfully registered for local push notifications")
        }
        
        // Register too receive remote notifications
        application.registerForRemoteNotifications()

        // Set self as messaging delegate
        Messaging.messaging().delegate = self
        
        // Register to timerkeeper topic
        Messaging.messaging().subscribe(toTopic: pollTimerTopic)
        
        return true
    }
    
    /// Executed when a background notification arrives. This is used to trigger polling of local topics.
    /// See https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/pushing_background_updates_to_your_app
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Log.d(tag, "Background notification received", userInfo)
        
        // Exit out early if this message is not expected
        let topic = userInfo["topic"] as? String ?? ""
        if topic != pollTimerTopic {
            completionHandler(.noData)
            return
        }

        // Poll and display new messages
        let store = Store.shared
        let center = UNUserNotificationCenter.current()
        let subscriptionManager = SubscriptionManager(store: store)
        
        store.getSubscriptions()?.forEach { subscription in
            subscriptionManager.poll(subscription) { messages in
                messages.forEach { message in
                    let content = UNMutableNotificationContent()
                    content.title = message.title ?? ""
                    content.body = message.message ?? ""
                    content.sound = .default
                    
                    let request = UNNotificationRequest(identifier: message.id, content: content, trigger: nil /* now */)
                    center.add(request) { (error) in
                        if let error = error {
                            Log.e(self.tag, "Unable to create notification", error)
                        }
                    }
                }
            }
        }
        completionHandler(.newData)
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { data in String(format: "%02.2hhx", data) }.joined()
        Messaging.messaging().apnsToken = deviceToken
        Log.d(tag, "Registered for remote notifications. Passing APNs token to Firebase: \(token)")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Log.e(tag, "Failed to register for remote notifications", error)
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Executed when the app is in the foreground. Nothing has to be done here, except call the completionHandler.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        Log.d(tag, "Notification received via userNotificationCenter(willPresent)", userInfo)
        completionHandler([[.banner, .sound]])
    }
    
    /// Executed when the user clicks on the notification.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionId = response.actionIdentifier

        Log.d(tag, "Notification received via userNotificationCenter(didReceive)", userInfo)
        
        let clickUrl = URL(string: userInfo["click"] as? String ?? "")
        let topic = userInfo["topic"] as? String ?? ""
        let actions = userInfo["actions"] as? String ?? "[]"
        let action = findAction(id: actionId, actions: Actions.shared.parse(actions))

        // Show current topic
        if topic != "" {
            selectedBaseUrl = topicUrl(baseUrl: Config.appBaseUrl, topic: topic)
        }
        
        // Execute user action or click action (if any)
        if let action = action {
            handleAction(action)
        } else if let clickUrl = clickUrl {
            handleCustomClick(clickUrl)
        }
    
        completionHandler()
    }
    
    private func findAction(id: String, actions: [Action]?) -> Action? {
        guard let actions = actions else { return nil }
        return actions.first { $0.id == id }
    }
    
    private func handleAction(_ action: Action) {
        Log.d(tag, "Executing user action", action)
        switch action.action {
        case "view":
            if let url = URL(string: action.url ?? "") {
                openUrl(url)
            } else {
                Log.w(tag, "Unable to parse action URL", action)
            }
        case "http":
            Actions.shared.http(action)
        default:
            Log.w(tag, "Action \(action.action) not supported", action)
        }
    }
    
    private func handleCustomClick(_ url: URL) {
        openUrl(url)
    }
    
    private func handleDefaultClick(topic: String) {
        Log.d(tag, "Selecting topic \(topic)")
        selectedBaseUrl = topicUrl(baseUrl: Config.appBaseUrl, topic: topic)
    }
    
    private func openUrl(_ url: URL) {
        Log.d(tag, "Opening URL \(url)")
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Log.d(tag, "Firebase token received: \(String(describing: fcmToken))")
        
        // We don't actually need the FCM token, since we're just using topics.
        // We still print it so we can see if things were successful.
    }
}
