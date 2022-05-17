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
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate: AppDelegate
    @StateObject private var store = Store()

    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, store.container.viewContext)
        }
    }
}

