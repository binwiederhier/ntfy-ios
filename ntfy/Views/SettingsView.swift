import Foundation
import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject private var store: Store
    
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
                    header: Text("Users"),
                    footer: Text("To access read-protected topics, you may add or edit users here. All topics for a given server will use the same user.")
                ) {
                    UserTableView()
                }
                Section(header: Text("About")) {
                    AboutView()
                }
            }
            .navigationTitle("Settings")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}


struct DefaultServerView: View {
    @EnvironmentObject private var store: Store
    @FetchRequest(sortDescriptors: []) var prefs: FetchedResults<Preference>
    @State private var showDialog = false
    @State private var newDefaultBaseUrl: String = "x"
    
    private var defaultBaseUrl: String {
        prefs
            .filter { $0.key == Store.prefKeyDefaultBaseUrl }
            .first?
            .value ?? Config.appBaseUrl
    }
    
    var body: some View {
        Button(action: {
            if defaultBaseUrl == Config.appBaseUrl {
                newDefaultBaseUrl = ""
            } else {
                newDefaultBaseUrl = defaultBaseUrl
            }
            showDialog = true
        }) {
            HStack {
                let _ = newDefaultBaseUrl
                Text("Default server")
                    .foregroundColor(.primary)
                Spacer()
                Text(shortUrl(url: defaultBaseUrl))
                    .foregroundColor(.gray)
            }
            .contentShape(Rectangle())
        }
        .sheet(isPresented: $showDialog) {
            NavigationView {
                Form {
                    Section(
                        footer: Text("When subscribing to new topics, this server will be used as a default. Note that if you pick your own ntfy server, you must configure upstream-base-url to receive instant push notifications.")
                    ) {
                        HStack {
                            TextField(Config.appBaseUrl, text: $newDefaultBaseUrl)
                                .disableAutocapitalization()
                                .disableAutocorrection(true)
                            if !newDefaultBaseUrl.isEmpty {
                                Button {
                                    newDefaultBaseUrl = ""
                                } label: {
                                    Image(systemName: "clear.fill")
                                }
                            }
                        }
                        
                    }
                }
                .navigationTitle("Default server")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: cancelAction) {
                            Text("Cancel")
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: saveAction) {
                            Text("Save")
                        }
                        .disabled(!isValid())
                    }
                }
            }
        }
    }
    
    private func saveAction() {
        if newDefaultBaseUrl == "" {
            store.saveDefaultBaseUrl(baseUrl: nil)
        } else {
            store.saveDefaultBaseUrl(baseUrl: newDefaultBaseUrl)
        }
        resetAndHide()
    }
    
    private func cancelAction() {
        resetAndHide()
    }
    
    private func isValid() -> Bool {
        if !newDefaultBaseUrl.isEmpty && newDefaultBaseUrl.range(of: "^https?://.+", options: .regularExpression, range: nil, locale: nil) == nil {
            return false
        }
        return true
    }
    
    private func resetAndHide() {
        showDialog = false
    }
}

struct UserTableView: View {
    @EnvironmentObject private var store: Store
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \User.baseUrl, ascending: true)]) var users: FetchedResults<User>
    
    @State private var selectedUser: User?
    @State private var showDialog = false
    
    @State private var baseUrl: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    
    var body: some View {
        let _ = selectedUser?.username // Workaround for FB7823148, see https://developer.apple.com/forums/thread/652080
        List {
            ForEach(users) { user in
                Button(action: {
                    selectedUser = user
                    baseUrl = user.baseUrl ?? "?"
                    username = user.username ?? "?"
                    showDialog = true
                }) {
                    UserRowView(user: user)
                        .foregroundColor(.primary)
                }
            }
            Button(action: {
                showDialog = true
            }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add user")
                }
                .foregroundColor(.primary)
            }
            .padding(.all, 4)
        }
        .sheet(isPresented: $showDialog) {
            NavigationView {
                Form {
                    Section(
                        footer: (selectedUser == nil)
                        ? Text("You can add a user here. All topics for the given server will use this user.")
                        : Text("Edit the username or password for \(shortUrl(url: baseUrl)) here. This user is used for all topics of this server. Leave the password blank to leave it unchanged.")
                    ) {
                        if selectedUser == nil {
                            TextField("Service URL, e.g. https://ntfy.home.io", text: $baseUrl)
                                .disableAutocapitalization()
                                .disableAutocorrection(true)
                        }
                        TextField("Username", text: $username)
                            .disableAutocapitalization()
                            .disableAutocorrection(true)
                        SecureField("Password", text: $password)
                    }
                }
                .navigationTitle(selectedUser == nil ? "Add user" : "Edit user")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        // Sigh, for iOS 14 we need to add a "Delete" menu item, because it doesn't support
                        // swipe actions. Quite annoying.
                        
                        if #available(iOS 15.0, *) {
                            Button(action: cancelAction) {
                                Text("Cancel")
                            }
                        } else {
                            if selectedUser == nil {
                                Button("Cancel") {
                                    cancelAction()
                                }
                            } else {
                                Menu {
                                    Button("Cancel") {
                                        cancelAction()
                                    }
                                    Button("Delete") {
                                        deleteAction()
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .padding([.leading], 40)
                                }
                            }
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: saveAction) {
                            Text("Save")
                        }
                        .disabled(!isValid())
                    }
                }
            }
        }
    }
    
    private func saveAction() {
        var password = password
        if let user = selectedUser, password == "" {
            password = user.password ?? "?" // If password is blank, leave unchanged
        }
        store.saveUser(baseUrl: baseUrl, username: username, password: password)
        resetAndHide()
    }
    
    private func cancelAction() {
        resetAndHide()
    }
    
    private func deleteAction() {
        store.delete(user: selectedUser!)
        resetAndHide()
    }
    
    private func isValid() -> Bool {
        if selectedUser == nil { // New user
            if baseUrl.range(of: "^https?://.+", options: .regularExpression, range: nil, locale: nil) == nil {
                return false
            } else if username.isEmpty || password.isEmpty {
                return false
            } else if store.getUser(baseUrl: baseUrl) != nil {
                return false
            }
        } else { // Existing user
            if username.isEmpty {
                return false
            }
        }
        return true
    }
    
    private func resetAndHide() {
        showDialog = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // Hide first and then reset, otherwise we'll see the text fields change
            selectedUser = nil
            baseUrl = ""
            username = ""
            password = ""
        }
    }
}

struct UserRowView: View {
    @EnvironmentObject private var store: Store
    @ObservedObject var user: User
    
    var body: some View {
        if #available(iOS 15.0, *) {
            userRow
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        store.delete(user: user)
                    } label: {
                        Label("Delete", systemImage: "trash.circle")
                    }
                }
        } else {
            userRow
        }
    }
    
    private var userRow: some View {
        HStack {
            Image(systemName: "person.fill")
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(user.username ?? "?")
                    Text(user.baseUrl ?? "?")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
            Image(systemName: "chevron.forward")
                .font(.system(size: 12.0))
                .foregroundColor(.gray)
        }
        .padding(.all, 4)
    }
}

struct AboutView: View {
    var body: some View {
        Group {
            Button(action: {
                open(url: "https://ntfy.sh/docs")
            }) {
                HStack {
                    Text("Read the docs")
                    Spacer()
                    Text("ntfy.sh/docs")
                        .foregroundColor(.gray)
                    Image(systemName: "link")
                }
            }
            Button(action: {
                open(url: "https://github.com/binwiederhier/ntfy/issues")
            }) {
                HStack {
                    Text("Report a bug")
                    Spacer()
                    Text("github.com")
                        .foregroundColor(.gray)
                    Image(systemName: "link")
                }
            }
            Button(action: {
                open(url: "itms-apps://itunes.apple.com/app/id1625396347")
            }) {
                HStack {
                    Text("Rate the app")
                    Spacer()
                    Text("App Store")
                        .foregroundColor(.gray)
                    Image(systemName: "star.fill")
                }
            }
            HStack {
                Text("Version")
                Spacer()
                Text("ntfy \(Config.version) (\(Config.build))")
                    .foregroundColor(.gray)
            }
        }
        .foregroundColor(.primary)
    }
    
    private func open(url: String) {
        guard let url = URL(string: url) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
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
