//
//  AppDelegate.swift
//  ntfy.sh
//
//  AppDelegate focuses on setting up Firebase and push notification handlers
//
//  Created by Andrew Cope on 1/15/22.
//

import UIKit
import Firebase
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions
        launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Gonfiure / setup Firebase
        FirebaseApp.configure()
        FirebaseConfiguration.shared.setLoggerLevel(.max)

        // Register app permissions for push notifications
        UNUserNotificationCenter.current().delegate = self
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions) { _, _ in }
        application.registerForRemoteNotifications()

        // Set self as messaging delegate
        Messaging.messaging().delegate = self

        return true
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    // Handler for when user receives notification while app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
        @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // TODO: Should this be handled differently than the below handler?
        completionHandler([[.banner, .sound]])
    }

    // Handler for when user taps a notification / or performs any long-press actions
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // TODO: Open app to subscription view
        completionHandler()
    }

    // Mapping APNs token to the FCM registration token
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Debug error
        print("Failed to register for notifications: \(error.localizedDescription)")
    }
}

// Notify whenever FCM token is updated
extension AppDelegate: MessagingDelegate {
    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        let tokenDict = ["token": fcmToken ?? ""]
        NotificationCenter.default.post(
            name: Notification.Name("FCMToken"),
            object: nil,
            userInfo: tokenDict)
    }
}
