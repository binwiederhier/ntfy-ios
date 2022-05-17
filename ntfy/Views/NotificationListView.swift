//
//  SubscriptionDetail.swift
//  ntfy.sh
//
//  Created by Andrew Cope on 1/15/22.
//

import SwiftUI

enum ActiveAlert {
    case clear, unsubscribe, selected
}

struct NotificationListView: View {
    @Environment(\.managedObjectContext) var context
    @Environment(\.presentationMode) var presentationMode

    @ObservedObject var subscription: Subscription

    @State private var editMode = EditMode.inactive
    @State private var selection = Set<Notification>()

    @State private var showAlert = false
    @State private var activeAlert: ActiveAlert = .clear

    var body: some View {
        NavigationView {
            List(selection: $selection) {
                ForEach(Array(subscription.notifications! as Set).reversed(), id: \.self) { notification in
                    NotificationRowView(notification: notification as! Notification)
                }
            }
        }
        .listStyle(PlainListStyle())
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, self.$editMode)
        .navigationBarBackButtonHidden(self.editMode == .active)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(subscription.displayName()).font(.headline)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if (self.editMode == .active) {
                    editButton
                } else {
                    Menu("Edit") {
                        editButton
                        Button("Send test notification") {
                            let possibleTags = ["warning", "skull", "success", "triangular_flag_on_post", "de", "us", "dog", "cat", "rotating_light", "bike", "backup", "rsync", "this-s-a-tag", "ios"]
                            let priority = Int.random(in: 1..<6)
                            let tags = Array(possibleTags.shuffled().prefix(Int.random(in: 0..<4)))
                            ApiService.shared.publish(
                                subscription: subscription,
                                message: "This is a test notification from the ntfy iOS app. It has a priority of \(priority). If you send another one, it may look different.",
                                title: "Test: You can set a title if you like",
                                priority: priority,
                                tags: tags
                            ) { _,_ in
                                print("Success")
                            }
                        }
                        Button("Clear all notifications") {
                            self.showAlert = true
                            self.activeAlert = .clear
                        }
                        Button("Unsubscribe") {
                            self.showAlert = true
                            self.activeAlert = .unsubscribe
                        }

                    }
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                if (self.editMode == .active) {
                    Button(action: {
                        self.showAlert = true
                        self.activeAlert = .selected
                    }) {
                        Text("Delete")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .alert(isPresented: $showAlert) {
            switch activeAlert {
            case .clear:
                return Alert(
                    title: Text("Clear notifications"),
                    message: Text("Do you really want to delete all of the notifications in this topic?"),
                    primaryButton: .destructive(
                        Text("Permanently delete"),
                        action: {
                            //Database.current.deleteNotificationsForSubscription(subscription: subscription)
                            //viewModel.notifications = Database.current.getNotifications(subscription: subscription)
                            //subscription.loadNotifications()
                        }),
                    secondaryButton: .cancel())
            case .unsubscribe:
                return Alert(
                    title: Text("Unsubscribe"),
                    message: Text("Do you really want to unsubscribe from this topic and delete all of the notifications you received?"),
                    primaryButton: .destructive(
                        Text("Unsubscribe"),
                        action: {
                            try? context.delete(subscription)
                            self.presentationMode.wrappedValue.dismiss()
                        }),
                    secondaryButton: .cancel())
            case .selected:
                return Alert(
                    title: Text("Delete"),
                    message: Text("Do you really want to delete these selected notifications?"),
                    primaryButton: .destructive(
                        Text("Delete"),
                        action: {
                            //deleteSelectedNotifications(notifications: subscription.notifications)
                            self.editMode = .inactive
                        }),
                    secondaryButton: .cancel())
            }
        }
        /*.overlay(Group {
            if subscription.notifications.isEmpty() {
                Text("No Notifications")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
        })*/
        .refreshable {
            print("Refresh")
            ApiService.shared.poll(subscription: subscription) { messages, error in
                guard let messages = messages else {
                    print(error)
                    return
                }
                print("Saving new messages to subscription \(subscription.urlString())", messages)
                DispatchQueue.main.async {
                    for message in messages {
                        do {
                            let notification = Notification(context: context)
                            notification.id = message.id
                            notification.time = message.time
                            notification.message = message.message ?? ""
                            notification.title = message.title ?? ""
                            subscription.addToNotifications(notification)
                            try context.save()
                        } catch let error {
                            print(error)
                            context.rollback()
                        }
                    }
                }
            }
        }
        .onAppear {
            print("onAppear")
            //subscription.loadNotifications()
        }
    }

    private var editButton: some View {
        if editMode == .inactive {
            return Button(action: {
                self.editMode = .active
                self.selection = Set<Notification>()
            }) {
                Text("Select Messages")
            }
        } else {
            return Button(action: {
                self.editMode = .inactive
                self.selection = Set<Notification>()
            }) {
                Text("Done")
            }
        }
    }

    private func deleteSelectedNotifications(notifications: [Notification]) {
        print("deletedSelected")
        /*
        for id in selection {
            if let index = subscription.notifications.lastIndex(where: { $0 == id }) {
                subscription.notifications.remove(at: index)
                //Database.current.deleteNotification(notification: notifications[index])
            }
        }*/
        selection = Set<Notification>()
    }
}
