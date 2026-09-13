import UIKit
import SafariServices
import UserNotifications
import Firebase
import FirebaseCore
import FirebaseMessaging
import CoreData

class AppDelegate: UIResponder, UIApplicationDelegate, ObservableObject {
    private let tag = "AppDelegate"
    private let pollTopic = "~poll" // See ntfy server if ever changed
    private let firebaseTopicResubscribeInterval: TimeInterval = 24 * 60 * 60
    
    // Implements navigation from notifications, see https://stackoverflow.com/a/70731861/1440785
    @Published var selectedBaseUrl: String? = nil
    @Published private(set) var criticalAlertSetting: UNNotificationSetting = .notSupported

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Log.d(tag, "Launching AppDelegate")

        FirebaseApp.configure()
        FirebaseConfiguration.shared.setLoggerLevel(.max)

        // Register app permissions for push notifications
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        requestStandardNotificationAuthorization()
        refreshNotificationSettings()
        
        // Register too receive remote notifications
        application.registerForRemoteNotifications()
        
        // Repair lost Firebase topic subscriptions. This is a no-op until the Firebase and APNs tokens are available,
        // at which point the sync is retried when the app becomes active, or forced from didReceiveRegistrationToken.
        syncFirebaseTopics()
                
        return true
    }

    func refreshNotificationSettings(completion: (() -> Void)? = nil) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let isAuthorized = settings.criticalAlertSetting == .enabled
            DispatchQueue.main.async {
                self.criticalAlertSetting = settings.criticalAlertSetting
                Store.saveCriticalAlertsAuthorized(isAuthorized)
                completion?()
            }
        }
    }

    func requestCriticalAlertsAuthorization(completion: @escaping (Bool) -> Void) {
        if criticalAlertSetting == .enabled {
            completion(true)
            return
        }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound, .criticalAlert]) { success, error in
            if let error {
                Log.e(self.tag, "Failed to register for critical alerts", error)
            } else if success {
                Log.d(self.tag, "Successfully requested critical alerts")
            }

            self.refreshNotificationSettings {
                completion(self.criticalAlertSetting == .enabled)
            }
        }
    }

    // TODO: Needs to be tested on multiple devices/iOS versions
    func openNotificationSettings() {
        let settingsURLString: String
        #if targetEnvironment(simulator)
        settingsURLString = UIApplication.openSettingsURLString
        #else
        if #available(iOS 16.0, *) {
            settingsURLString = UIApplication.openNotificationSettingsURLString
        } else if #available(iOS 15.4, *) {
            settingsURLString = UIApplicationOpenNotificationSettingsURLString
        } else {
            settingsURLString = UIApplication.openSettingsURLString
        }
        #endif
        guard let url = URL(string: settingsURLString) else {
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    private func requestStandardNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            guard success else {
                Log.e(self.tag, "Failed to register for local push notifications", error)
                return
            }
            Log.d(self.tag, "Successfully registered for local push notifications")
        }
    }
    
    /// Subscribes to the "~poll" topic and all locally saved topics, and unsubscribes from topics that no longer have a
    /// matching subscription.
    ///
    /// iOS and Firebase can silently lose the per-topic subscription state of a device, which causes push notifications
    /// to stop working until the app is reinstalled. Since the Firebase SDK does not let us read its subscription state
    /// back, we track it ourselves and regularly repair it. See https://github.com/binwiederhier/ntfy/issues/1305
    ///
    /// - Parameter force: Re-subscribe to all topics, even if they are already tracked as subscribed. This is needed
    ///   when the Firebase token changes, because topic subscriptions are tied to the token.
    func syncFirebaseTopics(force: Bool = false) {
        // Firebase can only subscribe once an FCM token exists. The token is restored from the keychain, so this is
        // normally available right away; on a fresh install it is fetched asynchronously, and the forced sync in
        // didReceiveRegistrationToken takes over at that point.
        guard Messaging.messaging().fcmToken != nil else {
            Log.d(tag, "Firebase topic sync deferred, Firebase token not available yet")
            return
        }
        guard let subscriptions = Store.shared.getSubscriptions() else {
            Log.w(tag, "Firebase topic sync skipped, cannot read subscriptions")
            return
        }
        
        // Subscribe to ~poll to receive poll requests, plus one topic per subscription
        let desiredTopics = Set([pollTopic]).union(subscriptions.compactMap { subscription -> String? in
            guard let baseUrl = subscription.baseUrl, let topic = subscription.topic else {
                Log.w(tag, "Skipping Firebase subscription with missing baseUrl or topic")
                return nil
            }
            return firebaseTopic(baseUrl: baseUrl, topic: topic)
        })
        let trackedTopics = Store.getFirebaseTopics()
        let fullResubscribe = force || Date().timeIntervalSince(Store.getFirebaseTopicsSyncedAt()) > firebaseTopicResubscribeInterval
        let topicsToSubscribe = fullResubscribe ? desiredTopics : desiredTopics.subtracting(trackedTopics)
        let topicsToUnsubscribe = trackedTopics.subtracting(desiredTopics) // Never contains ~poll, it is always desired
        Log.d(tag, "Syncing Firebase topics, subscribing to \(topicsToSubscribe.count), unsubscribing from \(topicsToUnsubscribe.count), full=\(fullResubscribe)")
        
        // Topics are only tracked as subscribed once Firebase confirms, so failed attempts are retried on the next sync
        topicsToSubscribe.forEach { topic in
            Messaging.messaging().subscribe(toTopic: topic) { error in
                if let error {
                    Log.e(self.tag, "Firebase subscribe failed for \(topic)", error)
                } else {
                    Log.d(self.tag, "Firebase subscribe succeeded for \(topic)")
                    Store.addFirebaseTopic(topic)
                }
            }
        }
        topicsToUnsubscribe.forEach { topic in
            Messaging.messaging().unsubscribe(fromTopic: topic) { error in
                if let error {
                    Log.e(self.tag, "Firebase unsubscribe failed for \(topic)", error)
                } else {
                    Log.d(self.tag, "Firebase unsubscribe succeeded for \(topic)")
                    Store.removeFirebaseTopic(topic)
                }
            }
        }
        if fullResubscribe {
            Store.setFirebaseTopicsSyncedAt(Date())
        }
    }
    
    /// Executed when a background notification arrives on the "~poll" topic. This is used to trigger polling of local topics.
    /// See https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/pushing_background_updates_to_your_app
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Log.d(tag, "Background notification received", userInfo)
        
        // Exit out early if this message is not expected
        let topic = userInfo["topic"] as? String ?? ""
        if topic != pollTopic {
            completionHandler(.noData)
            return
        }

        // Poll and show new messages as notifications
        let store = Store.shared
        let subscriptionManager = SubscriptionManager(store: store)
        let subscriptions = store.getSubscriptions() ?? []
        guard !subscriptions.isEmpty else {
            completionHandler(.noData)
            return
        }

        let group = DispatchGroup()
        let resultQueue = DispatchQueue(label: "io.heckel.ntfy.background-poll-result")
        var didReceiveNewData = false
        subscriptions.forEach { subscription in
            group.enter()
            guard let baseUrl = subscription.baseUrl else {
                Log.w(tag, "Skipping background poll notification for subscription with missing baseUrl")
                group.leave()
                return
            }
            subscriptionManager.poll(subscription) { messages in
                if !messages.isEmpty {
                    resultQueue.sync {
                        didReceiveNewData = true
                    }
                }
                self.showNotificationsSequentially(baseUrl: baseUrl, messages: messages) {
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) {
            completionHandler(didReceiveNewData ? .newData : .noData)
        }
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { data in String(format: "%02.2hhx", data) }.joined()
        Messaging.messaging().apnsToken = deviceToken
        Log.d(tag, "Registered for remote notifications. Passing APNs token \(token.prefix(12))... to Firebase")
        
        // APNs registration completes after launch, so this is the first point where the tokens are known to be good
        syncFirebaseTopics()
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Log.e(tag, "Failed to register for remote notifications", error)
    }
    
    /// Create a local notification manually (as opposed to a remote notification being generated by Firebase). We need to make the
    /// local notification look exactly like the remote one (same userInfo), so that when we tap it, the userNotificationCenter(didReceive) function
    /// has the same information available.
    private func showNotification(_ subscription: Subscription, _ message: Message, completionHandler: (() -> Void)? = nil) {
        guard let baseUrl = subscription.baseUrl else {
            Log.w(tag, "Skipping notification for subscription with missing baseUrl")
            completionHandler?()
            return
        }
        showNotification(baseUrl: baseUrl, message, completionHandler: completionHandler)
    }

    private func showNotification(baseUrl: String, _ message: Message, completionHandler: (() -> Void)? = nil) {
        let user = Store.shared.getUser(baseUrl: baseUrl)?.toBasicUser()
        let content = UNMutableNotificationContent()
        content.modify(message: message, baseUrl: baseUrl)
        content.attachImageIfNeeded(message: message, user: user) {
            let request = UNNotificationRequest(identifier: message.id, content: content, trigger: nil /* now */)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    Log.e(self.tag, "Unable to create notification", error)
                }
                completionHandler?()
            }
        }
    }

    private func showNotificationsSequentially(baseUrl: String, messages: [Message], completionHandler: @escaping () -> Void) {
        guard let firstMessage = messages.first else {
            completionHandler()
            return
        }

        showNotification(baseUrl: baseUrl, firstMessage) {
            self.showNotificationsSequentially(
                baseUrl: baseUrl,
                messages: Array(messages.dropFirst()),
                completionHandler: completionHandler
            )
        }
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
        Log.d(tag, "Notification received via userNotificationCenter(didReceive)", userInfo)
        guard let message = Message.from(userInfo: userInfo) else {
            Log.w(tag, "Cannot convert userInfo to message", userInfo)
            completionHandler()
            return
        }
        
        let baseUrl = userInfo["base_url"] as? String ?? Config.appBaseUrl
        let action = message.actions?.first { $0.id == response.actionIdentifier }
        
        // Show current topic
        if message.topic != "" {
            selectedBaseUrl = topicUrl(baseUrl: baseUrl, topic: message.topic)
        }
        
        // Execute user action or click action (if any)
        if let action = action {
            ActionExecutor.execute(action)
        } else if let click = message.click, click != "", let url = URL(string: click) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    
        completionHandler()
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        if let fcmToken = fcmToken, !fcmToken.isEmpty {
            Log.d(tag, "Firebase token received: \(fcmToken.prefix(12))...")
        } else {
            Log.w(tag, "Firebase token missing")
        }
        
        // Topic subscriptions are tied to the Firebase token, so re-subscribe to everything when it changes
        syncFirebaseTopics(force: true)
    }
}
