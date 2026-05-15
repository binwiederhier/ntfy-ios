import Foundation
import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject private var store: Store
    @State private var userDialog: UserDialog?
    
    var body: some View {
        NavigationView {
            Form {
                Section(
                    header: Text("General"),
                    footer: Text("Choose the default server for new topics and how subscribed topics are sorted.")
                ) {
                    DefaultServerView()
                    Picker(
                        "Subscription sorting",
                        selection: Binding(
                            get: { store.subscriptionSortOrder },
                            set: { store.saveSubscriptionSortOrder($0) }
                        )
                    ) {
                        ForEach(SubscriptionSortOrder.allCases) { sortOrder in
                            Text(sortOrder.label).tag(sortOrder)
                        }
                    }
                }
                Section(
                    header: Text("Users"),
                    footer: Text("To access read-protected topics, you may add or edit users here. All topics for a given server will use the same user.")
                ) {
                    UserTableView(dialog: $userDialog)
                }
                Section(header: Text("About")) {
                    AboutView()
                }
            }
            .navigationTitle("Settings")
        }
        .sheet(item: $userDialog) { dialog in
            UserEditorView(
                selectedUser: dialog.user,
                onSave: { baseUrl, username, password in
                    store.saveUser(baseUrl: baseUrl, username: username, password: password)
                    userDialog = nil
                },
                onDelete: { user in
                    store.delete(user: user)
                    userDialog = nil
                },
                onCancel: {
                    userDialog = nil
                }
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}


struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let store = Store.preview // Store.previewEmpty
        SettingsView()
            .environment(\.managedObjectContext, store.context)
            .environmentObject(store)
            .environmentObject(AppDelegate())
    }
}
