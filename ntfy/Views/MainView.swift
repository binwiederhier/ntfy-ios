import Foundation
import SwiftUI

struct MainView: View {
    @StateObject private var allNotificationsModel = AllNotificationsObservable()

    private var unreadCount: Int {
        allNotificationsModel.notifications.reduce(0) { $1.isRead ? $0 : $0 + 1 }
    }

    var body: some View {
        TabView {
            SubscriptionListView()
                .tabItem {
                    Image(systemName: "message.fill")
                    Text("Notifications")
                }
                .badge(unreadCount)
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        let store = Store.preview // Store.previewEmpty
        MainView()
            .environment(\.managedObjectContext, store.context)
            .environmentObject(store)
            .environmentObject(AppDelegate())
    }
}
