import SwiftUI
import Firebase

// TODO: Verify whether model version needs to be specified
// TODO: Disallow adding same topic twice!!
// TODO: Errors are not shown to the user, but instead just logged

@main
struct AppMain: App {
    private let tag = "main"
    
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
                .environmentObject(store)
                .environmentObject(delegate)
                .environment(\.managedObjectContext, store.context)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Use this hook instead of applicationDidBecomeActive, see https://stackoverflow.com/a/68888509/1440785
                    // That post also explains how to start SwiftUI from AppDelegate if that's ever needed.
                    
                    Log.d(tag, "App became active, refreshing objects")
                    store.hardRefresh()
                }
        }
    }
}

