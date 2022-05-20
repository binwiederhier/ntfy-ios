import UIKit
import SafariServices
import UserNotifications
import Firebase
import FirebaseCore
import CoreData

// https://stackoverflow.com/a/41783666/1440785
// https://stackoverflow.com/questions/47374903/viewing-core-data-data-from-your-app-on-a-device

class AppDelegate: UIResponder, UIApplicationDelegate {
    let tag = "AppDelegate"
    let store = Store.shared
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        Log.d(tag, "ApplicationDelegate didFinishLaunchingWithOptions.")
        
        // FirebaseApp.configure() DOES NOT WORK
        FirebaseConfiguration.shared.setLoggerLevel(.max)
        Messaging.messaging().delegate = self
        
        registerForPushNotifications()
        UNUserNotificationCenter.current().delegate = self
        
        return true
    }
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Log.d(tag, "Called didReceiveRemoteNotification (with completionHandler). This is a no-op.", userInfo)
    }
    
    
    func application(
        _ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) {
        Log.d(tag, "Called didReceiveRemoteNotification (without completionHandler). This is a no-op.", userInfo)
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Log.e(tag, "Failed to register for remote notifications", error)
    }
    
    func application(
        _ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken
            .map { data in String(format: "%02.2hhx", data) }
            .joined()
        Log.d(tag, "Registered for remote notifications. Passing APNs token to Firebase: \(token)")
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func registerForPushNotifications() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
                print("granted: \(granted)")
                guard granted else { return }
                self?.getNotificationSettings()
            }
    }
    
    func getNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("Notification settings: \(settings)")
            guard settings.authorizationStatus == .authorized else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        Log.d(tag, "Notification received via userNotificationCenter(willPresent)", userInfo)
        completionHandler([[.banner, .sound]])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Log.d(tag, "Notification received via userNotificationCenter(didReceive)", userInfo)
        completionHandler()
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        Log.d(tag, "Firebase token received: \(String(describing: fcmToken))")
        
        // FIXME: Is this necessary?
        
        let dataDict: [String: String] = ["token": fcmToken ?? ""]
        NotificationCenter.default.post(
            name: UserNotifications.Notification.Name("FCMToken"),
            object: nil,
            userInfo: dataDict
        )
    }
}

