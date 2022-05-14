//
//  ntfyApp.swift
//  ntfy
//
//  Created by Philipp Heckel on 5/13/22.
//

import SwiftUI
import Firebase


@main
struct ntfyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate: AppDelegate
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

