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
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu("Edit") {
                    Button("Send Test Notification") {
                        let priority = Int.random(in: 1..<6)
                        ApiService.shared.publish(
                            subscription: subscription,
                            message: "This is a test notification from the Ntfy iOS app. It has a priority of \(priority).",
                            title: "Test: You can set a title if you like",
                            priority: priority
                        ) { _,_ in
                            print("Success")
                        }
                    }
                }
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
