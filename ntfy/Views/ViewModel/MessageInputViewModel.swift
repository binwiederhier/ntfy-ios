//
//  MessageInputViewModel.swift
//  ntfy
//
//  Created by Nguyen Loc on 11/08/2023.
//

import Foundation
import SwiftUI
extension MessageInputView {
    @MainActor
    class ViewModel: ObservableObject {
        let subscription: Subscription
        @Published var title: String = ""
        @Published var message: String = ""
        @Published var tag: String = ""
        @Published var priority: Priority = .normal
        let store: Store
        init(subscription: Subscription, store: Store) {
            self.subscription = subscription
            self.store = store
        }
        
        func send() async {
            let priority = priority.rawValue
            let tags: [String] = tag.split(separator: ",").map { item in
                "\(item)"
            }
            let user = self.store.getUser(baseUrl: self.subscription.baseUrl!)?.toBasicUser()
            ApiService.shared.publish(
                subscription: self.subscription,
                user: user,
                message: self.message,
                title: title,
                priority: priority,
                tags: tags
            )
            title = ""
            message = ""
            self.priority = Priority.normal
            tag = ""
        }
    }
}
