import Foundation
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: Store
    
    var body: some View {
        NavigationView {
            Form {
                /*Section(header: Text("General")) {
                 NavigationLink(destination: UsersView()) {
                 Text("Manage users")
                 }
                 }*/
                Section(header: Text("Users")) {
                    UsersView()
                }
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                            .foregroundColor(.gray)
                        Spacer()
                        Text("ntfy 1.1")
                    }
                }
            }
            .navigationTitle("Settings")
            
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct UsersView: View {
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
                UserRowView(user: user)
                    .onTapGesture {
                        selectedUser = user
                        baseUrl = user.baseUrl ?? "?"
                        username = user.username ?? "?"
                        showDialog = true
                    }
            }
            HStack {
                Image(systemName: "plus")
                Text("Add user")
            }
            .onTapGesture {
                showDialog = true
            }
        }
        .sheet(isPresented: $showDialog) {
            NavigationView {
                Form {
                    Section(footer:
                                Text("You can add a user here. All topics for the given server will use this user.")
                    ) {
                        if selectedUser == nil {
                            TextField("Service URL, e.g. https://ntfy.example.com", text: $baseUrl)
                                .disableAutocapitalization()
                                .disableAutocorrection(true)
                        }
                        TextField("Username", text: $username)
                            .disableAutocapitalization()
                            .disableAutocorrection(true)
                        TextField("Password", text: $password)
                            .disableAutocapitalization()
                            .disableAutocorrection(true)
                    }
                }
                .navigationTitle(selectedUser == nil ? "Add user" : "Edit user")
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
        store.saveUser(baseUrl: baseUrl, username: username, password: password)
        resetAndHide()
    }
    
    private func cancelAction() {
        resetAndHide()
    }
    
    private func isValid() -> Bool {
        return true // FIXME: validate
    }
    
    private func resetAndHide() {
        selectedUser = nil
        baseUrl = ""
        username = ""
        password = ""
        showDialog = false
    }
}

struct UserRowView: View {
    @ObservedObject var user: User
    
    var body: some View {
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

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let store = Store.preview // Store.previewEmpty
        SettingsView()
            .environment(\.managedObjectContext, store.context)
            .environmentObject(store)
            .environmentObject(AppDelegate())
    }
}
