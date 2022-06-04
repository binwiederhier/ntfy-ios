import Foundation
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: Store
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \User.baseUrl, ascending: true)]) var users: FetchedResults<User>
   
    var body: some View {
        NavigationView {
            Form {
                /*Section(header: Text("General")) {
                    NavigationLink(destination: UsersView()) {
                        Text("Manage users")
                    }
                }*/
                Section(
                    header: Text("Users")
                ) {
                    List {
                        ForEach(users) { user in
                            HStack {
                                Image(systemName: "person.fill")
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(user.username ?? "?")
                                        
                                    Text(user.baseUrl ?? "?")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        HStack {
                            Image(systemName: "plus")
                            Text("Add user")
                        }
                    }
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
   
    var body: some View {
        List {
            ForEach(users) { user in
                Text(user.username ?? "")
            }
        }
        .listStyle(PlainListStyle())
        .navigationTitle("Manage users")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    //self.showingAddDialog = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
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
