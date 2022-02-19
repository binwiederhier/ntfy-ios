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
        .listStyle(PlainListStyle())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(subscription.displayName()).font(.headline)
            }
        }
        .overlay(Group {
            if notifications.isEmpty {
                Text("No Notifications")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
        })
        .refreshable {
            ApiService.shared.poll(subscription: subscription) { (notifications, error) in
                if let notifications = notifications {
                    for notification in notifications {
                        notification.save()
                    }
                }
            }
            // TODO: Refresh view with updated notifications list
        }
    }
}
