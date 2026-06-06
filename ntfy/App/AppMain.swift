import SwiftUI
import Firebase

// TODO: Errors are not shown to the user, but instead just logged

@main
struct AppMain: App {
    private let tag = "AppMain"
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate: AppDelegate
    @StateObject private var store = Store.shared

    init() {
        Log.d(tag, "Launching ntfy 🥳. Welcome!")
        Log.d(tag, "Base URL is \(Config.appBaseUrl), user agent is \(ApiService.userAgent)")
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
                .onOpenURL { url in
                    handleNtfyURL(url)
                }
        }
    }

    /// Handle incoming ntfy:// deep link URLs.
    ///
    /// If the topic is already subscribed, navigates directly to it.
    /// Otherwise, subscribes first and then navigates to the new subscription.
    private func handleNtfyURL(_ url: URL) {
        Log.d(tag, "Received deep link URL: \(url.absoluteString)")

        guard let deepLink = NtfyDeepLink.from(url: url) else {
            Log.w(tag, "Ignoring malformed ntfy:// URL: \(url.absoluteString)")
            return
        }

        Log.d(tag, "Parsed deep link: baseUrl=\(deepLink.baseUrl), topic=\(deepLink.topic), display=\(deepLink.displayName ?? "nil")")

        let subscriptionManager = SubscriptionManager(store: store)

        // Subscribe if not already subscribed
        if store.getSubscription(baseUrl: deepLink.baseUrl, topic: deepLink.topic) == nil {
            Log.d(tag, "Topic not yet subscribed, subscribing to \(deepLink.baseUrl)/\(deepLink.topic)")
            DispatchQueue.global(qos: .background).async {
                subscriptionManager.subscribe(baseUrl: deepLink.baseUrl, topic: deepLink.topic)
                DispatchQueue.main.async {
                    delegate.selectedBaseUrl = topicUrl(baseUrl: deepLink.baseUrl, topic: deepLink.topic)
                }
            }
        } else {
            Log.d(tag, "Already subscribed to \(deepLink.baseUrl)/\(deepLink.topic), navigating")
            delegate.selectedBaseUrl = topicUrl(baseUrl: deepLink.baseUrl, topic: deepLink.topic)
        }
    }
}

