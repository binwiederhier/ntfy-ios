//
//  ntfyApp.swift
//  ntfy
//
//  Created by Philipp Heckel on 5/13/22.
//

import SwiftUI
import Firebase

@main
struct AppMain: App {
    let tag = "main"
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate: AppDelegate
    @StateObject private var store = Store.shared

    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, store.container.viewContext)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Use this hook instead of applicationDidBecomeActive, see https://stackoverflow.com/a/68888509/1440785
                    // That post also explains how to start SwiftUI from AppDelegate if that's ever needed.
                    
                    Log.d(tag, "App became active, refreshing objects")
                    store.context.refreshAllObjects()
                }
        }
    }
}

