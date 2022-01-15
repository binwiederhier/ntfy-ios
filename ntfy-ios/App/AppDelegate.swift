//
//  AppDelegate.swift
//  ntfy.sh
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

      return true
  }
}
