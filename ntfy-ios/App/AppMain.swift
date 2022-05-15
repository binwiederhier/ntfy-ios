//
//  ntfy_iosApp.swift
//  ntfy-ios
//
//  Created by Andrew Cope on 1/15/22.
//

import SwiftUI

@main
struct AppMain: App {
    // Set App Delegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var subscriptions = NtfySubscriptionList()
    
    var body: some Scene {
        WindowGroup {
            ContentView(subscriptions: subscriptions)
        }
    }
}
