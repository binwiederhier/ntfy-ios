//
//  UserTableView.swift
//  ntfy
//
//  Created by Alek Michelson on 4/10/26.
//

import SwiftUI

enum UserDialog: Identifiable {
    case add
    case edit(User)
    
    var id: String {
        switch self {
        case .add:
            return "add"
        case .edit(let user):
            return user.objectID.uriRepresentation().absoluteString
        }
    }
    
    var user: User? {
        switch self {
        case .add:
            return nil
        case .edit(let user):
            return user
        }
    }
}

struct UserTableView: View {
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \User.baseUrl, ascending: true)]) var users: FetchedResults<User>
    
    @Binding var dialog: UserDialog?
    
    var body: some View {
        ForEach(users) { user in
            Button(action: {
                dialog = .edit(user)
            }) {
                UserRowView(user: user)
                    .foregroundColor(.primary)
            }
        }
        Button(action: {
            dialog = .add
        }) {
            HStack {
                Image(systemName: "plus")
                Text("Add user")
            }
            .foregroundColor(.primary)
        }
    }
}
