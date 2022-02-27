//
//  UserManagementView.swift
//  ntfy.sh
//
//  Created by Andrew Cope on 2/27/22.
//

import Foundation
import SwiftUI

struct UserManagementView: View {

    @ObservedObject var viewModel = UserManagementViewModel()

    @Binding var currentView: CurrentView

    var body: some View {
        NavigationView {
            List {
                Section(header: Text(Configuration.appBaseUrl)) {
                    ForEach(viewModel.users) { user in
                        Text(user.username)
                            .swipeActions {
                                Button(role: .destructive) {
                                    viewModel.deleteUser(user: user)
                                } label: {
                                    Label("Delete", systemImage: "trash.circle")
                                }
                            }
                    }
                }
            }
            .listStyle(GroupedListStyle())
            .navigationTitle("Manage Users")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        currentView = .subscriptionList
                    }) {
                        Text("Topics")
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            viewModel.loadUsers()
        }
    }
}

class UserManagementViewModel: ObservableObject {
    @Published var users = [NtfyUser]()

    func loadUsers() {
        self.users = Database.current.findUsers(baseUrl: Configuration.appBaseUrl)
    }

    func deleteUser(user: NtfyUser) {
        Database.current.deleteUser(user: user)
        self.loadUsers()
    }
}
