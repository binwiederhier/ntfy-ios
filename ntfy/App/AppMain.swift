import SwiftUI
import Firebase

// Must have before release:
// TODO: Verify whether model version needs to be specified
// TODO: Disallow adding same topic twice!!

// Nice to have
// TODO: Make notification click open detail view
// TODO: Slide up dialog for "add topic"

@main
struct AppMain: App {
    let tag = "main"
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate: AppDelegate
    @StateObject private var store = Store.shared
    
    init() {
        Log.d(tag, "Launching ntfy 🥳. Welcome!")
        Log.d(tag, "Base URL is \(Config.appBaseUrl)")
        
        // We must configure Firebase here, and not in the AppDelegate. For some reason
        // configuring it there did not work.
        FirebaseApp.configure()
        FirebaseConfiguration.shared.setLoggerLevel(.max)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, store.context)
                .environmentObject(store)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Use this hook instead of applicationDidBecomeActive, see https://stackoverflow.com/a/68888509/1440785
                    // That post also explains how to start SwiftUI from AppDelegate if that's ever needed.
                    
                    Log.d(tag, "App became active, refreshing objects")
                    store.context.refreshAllObjects()
                    store.objectWillChange.send()
                }
        }
    }
}

