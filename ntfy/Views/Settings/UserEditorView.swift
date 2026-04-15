//
//  UserEditorView.swift
//  ntfy
//
//  Created by Alek Michelson on 4/10/26.
//

import SwiftUI

struct UserEditorView: View {
    @EnvironmentObject private var store: Store
    
    let selectedUser: User?
    let onSave: (String, String, String) -> Void
    let onDelete: (User) -> Void
    let onCancel: () -> Void
    
    @State private var baseUrl: String
    @State private var username: String
    @State private var password: String
    
    init(
        selectedUser: User?,
        onSave: @escaping (String, String, String) -> Void,
        onDelete: @escaping (User) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.selectedUser = selectedUser
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        _baseUrl = State(initialValue: selectedUser?.baseUrl ?? "")
        _username = State(initialValue: selectedUser?.username ?? "")
        _password = State(initialValue: "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(
                    footer: isNewUser
                    ? Text("You can add a user here. All topics for the given server will use this user.")
                    : Text("Edit the username or password for \(shortUrl(url: baseUrl)) here. This user is used for all topics of this server. Leave the password blank to leave it unchanged.")
                ) {
                    if isNewUser {
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
            .navigationTitle(isNewUser ? "Add user" : "Edit user")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isNewUser {
                        Button("Cancel") {
                            onCancel()
                        }
                    } else {
                        Menu {
                            Button("Cancel") {
                                onCancel()
                            }
                            if #available(iOS 15.0, *) {
                                Button(role: .destructive) {
                                    deleteAction()
                                } label: {
                                    Text("Delete")
                                }
                            } else {
                                Button("Delete") {
                                    deleteAction()
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .padding([.leading], 40)
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
    
    private var isNewUser: Bool {
        selectedUser == nil
    }
    
    private func saveAction() {
        let finalPassword: String
        if let user = selectedUser, password.isEmpty {
            finalPassword = user.password ?? "?"
        } else {
            finalPassword = password
        }
        onSave(baseUrl, username, finalPassword)
    }
    
    private func deleteAction() {
        guard let selectedUser = selectedUser else { return }
        onDelete(selectedUser)
    }
    
    private func isValid() -> Bool {
        if isNewUser {
            if baseUrl.range(of: "^https?://.+", options: .regularExpression, range: nil, locale: nil) == nil {
                return false
            } else if username.isEmpty || password.isEmpty {
                return false
            } else if store.getUser(baseUrl: baseUrl) != nil {
                return false
            }
        } else if username.isEmpty {
            return false
        }
        return true
    }
}
