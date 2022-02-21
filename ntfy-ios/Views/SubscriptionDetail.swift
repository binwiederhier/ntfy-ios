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
        let user = Database.current.findUser(baseUrl: subscription.baseUrl)
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
                        let possibleTags = ["warning", "skull", "success", "triangular_flag_on_post", "de", "us", "dog", "cat", "rotating_light", "bike", "backup", "rsync", "this-s-a-tag", "ios"]
                        let priority = Int.random(in: 1..<6)
                        let tags = Array(possibleTags.shuffled().prefix(Int.random(in: 0..<4)))
                        ApiService.shared.publish(
                            subscription: subscription,
                            message: "This is a test notification from the Ntfy iOS app. It has a priority of \(priority). If you send another one, it may look different.",
                            title: "Test: You can set a title if you like",
                            priority: priority,
                            tags: tags,
                            user: user
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
            ApiService.shared.poll(subscription: subscription, user: user) { (notifications, error) in
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
