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
    @StateObject private var dataController = DataController()

    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, dataController.container.viewContext)
        }
    }
}

