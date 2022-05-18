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
    
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard let aps = userInfo["aps"] as? [String: AnyObject] else {
            completionHandler(.failed)
            return
        }
        print("didReceiveRemoteNotification")
        print(userInfo)
    }
    
    
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        print("didReceiveRemoteNotification 2")
        
        guard let aps = userInfo["aps"] as? [String: AnyObject] else {
            return
        }
        print(userInfo)
    }
    
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register: \(error)")
    }
    
    
    
    // This function is added here only for debugging purposes, and can be removed if swizzling is enabled.
    // If swizzling is disabled then this function must be implemented so that the APNs token can be paired to
    // the FCM registration token.
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("APNs token retrieved: \(deviceToken)")
        
        // With swizzling disabled you must set the APNs token here.
        Messaging.messaging().apnsToken = deviceToken
        
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("Device Token: \(token)")
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
        store.saveNotification(fromUserInfo: userInfo)
        completionHandler([[.alert, .sound]])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Log.d(tag, "Notification received via userNotificationCenter(didReceive)", userInfo)
        store.saveNotification(fromUserInfo: userInfo)
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

