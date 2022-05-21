import UIKit
import SafariServices
import UserNotifications
import Firebase
import FirebaseCore
import CoreData

class AppDelegate: UIResponder, UIApplicationDelegate {
    let tag = "AppDelegate"
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        Log.d(tag, "ApplicationDelegate didFinishLaunchingWithOptions.")
        
        Messaging.messaging().delegate = self
        
        registerForPushNotifications()
        UNUserNotificationCenter.current().delegate = self
        
        return true
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
        Log.d(tag, "Registering for local push notifications")
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { success, error in
                guard success else {
                    Log.e(self.tag, "Failed to register for local push notifications", error)
                    return
                }
                Log.d(self.tag, "Successfully registered for local push notifications")
                self.registerForRemoteNotifications()
            }
    }
    
    func registerForRemoteNotifications() {
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
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Log.d(tag, "Firebase token received: \(String(describing: fcmToken))")
        
        // We don't actually need the FCM token, since we're just using topics.
        // We still print it so we can see if things were successful.
    }
}
