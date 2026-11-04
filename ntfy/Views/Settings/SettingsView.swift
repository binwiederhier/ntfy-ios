import Foundation
import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var delegate: AppDelegate
    @State private var userDialog: UserDialog?
    
    var body: some View {
        NavigationView {
            Form {
                Section(
                    header: Text("General"),
                    footer: Text("When subscribing to new topics, this server will be used as a default.")
                ) {
                    DefaultServerView()
                }
                Section(
                    header: Text("Notifications"),
                    footer: Text("Automatically download attachments up to the selected size. Attachments larger than this limit must be downloaded manually.")
                ) {
                    NotificationSoundSettingView()
                    AttachmentAutoDownloadView()
                }
                Section(
                    footer: Text("Max priority notifications break through to grab your attention, appearing on the lock screen and playing a sound even when focus mode is on or your device is muted.")
                ) {
                    CriticalAlertsSettingView()
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


// The sound preference lives in Core Data, which is shared with the notification
// service extension. Reading it through a fetch request keeps this view updated.
private struct NotificationSoundSettingView: View {
    @EnvironmentObject private var store: Store
    @FetchRequest(sortDescriptors: []) private var prefs: FetchedResults<Preference>

    private var selectedSound: String {
        guard let sound = prefs.first(where: { $0.key == Store.prefKeyNotificationSound })?.value,
              Store.notificationSounds.contains(sound) else {
            return Store.notificationSoundDefault
        }
        return sound
    }

    var body: some View {
        Picker("Notification sound", selection: Binding(
            get: { selectedSound },
            set: { store.saveNotificationSound($0) }
        )) {
            Text("System default").tag(Store.notificationSoundDefault)
            Text("Ping").tag(Store.notificationSoundPing)
            Text("Chime").tag(Store.notificationSoundChime)
        }
    }
}
