//
//  SubscriptionDetail.swift
//  ntfy.sh
//
//  Created by Andrew Cope on 1/15/22.
//

import SwiftUI

struct SubscriptionDetail: View {
    var subscription: NtfySubscription

    var body: some View {
        let notifications = Database.current.getNotifications(subscription: subscription)
        NavigationView {
            List(notifications) { notification in
                NotificationRow(notification: notification)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(subscription.displayName()).font(.headline)
            }
        }
        .overlay(Group {
            Text("No Notifications")
                .font(.headline)
                .foregroundColor(.gray)
        })
    }
}
