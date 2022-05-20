import SwiftUI

enum ActiveAlert {
    case clear, unsubscribe, selected
}

struct NotificationListView: View {
    private let tag = "NotificationListView"
    
    @Environment(\.managedObjectContext) var context
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var store: Store
    
    @ObservedObject var subscription: Subscription
    
    @State private var editMode = EditMode.inactive
    @State private var selection = Set<Notification>()
    
    @State private var showAlert = false
    @State private var activeAlert: ActiveAlert = .clear
    
    private var subscriptionManager: SubscriptionManager {
        return SubscriptionManager(store: store)
    }
    
    var body: some View {
        List(selection: $selection) {
            ForEach(subscription.notificationsSorted(), id: \.self) { notification in
                NotificationRowView(notification: notification)
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
                    Menu {
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
                    } label: {
                        Image(systemName: "ellipsis.circle")
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
                            subscriptionManager.unsubscribe(subscription)
                            self.presentationMode.wrappedValue.dismiss()
                        }),
                    secondaryButton: .cancel())
            case .selected:
                return Alert(
                    title: Text("Delete"),
                    message: Text("Do you really want to delete these selected notifications?"),
                    primaryButton: .destructive(
                        Text("Delete"),
                        action: deleteSelected
                    ),
                    secondaryButton: .cancel())
            }
        }
        /*.overlay(Group {
         if subscription.notifications.isEmpty() {
         Text("No notifications")
         .font(.headline)
         .foregroundColor(.gray)
         }
         })*/
        .refreshable {
            poll()
        }
    }
    
    private var editButton: some View {
        if editMode == .inactive {
            return Button(action: {
                self.editMode = .active
                self.selection = Set<Notification>()
            }) {
                Text("Select messages")
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
    
    private func deleteSelected() {
        store.delete(notifications: selection)
        selection = Set<Notification>()
        editMode = .inactive
    }
    
    private func poll() {
        ApiService.shared.poll(subscription: subscription) { messages, error in
            guard let messages = messages else {
                Log.e(tag, "Polling failed", error)
                return
            }
            Log.d(tag, "Polling success, \(messages.count) new message(s)", messages)
            if !messages.isEmpty {
                DispatchQueue.main.async {
                    for message in messages {
                        store.saveNotification(fromMessage: message, subscription: subscription)
                    }
                }
            }
        }
    }
}
