import Foundation
import SwiftUI

struct MainView: View {
    @EnvironmentObject private var delegate: AppDelegate

    var body: some View {
        TabView(selection: $delegate.selectedTab) {
            SubscriptionListView()
                .tabItem {
                    Image(systemName: "message.fill")
                    Text("Notifications")
                }
                .tag(0)
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .tag(1)
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
