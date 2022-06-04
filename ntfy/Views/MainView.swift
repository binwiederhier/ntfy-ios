import Foundation
import SwiftUI

struct MainView: View {
    var body: some View {
        TabView {
            SubscriptionListView()
                .tabItem {
                    Image(systemName: "message.fill")
                    Text("Notifications")
                }
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
