import SwiftUI
import UniformTypeIdentifiers

enum ActiveAlert {
    case clear, unsubscribe, selected
}

struct NotificationListView: View {
    private let tag = "NotificationListView"
    
    @EnvironmentObject private var delegate: AppDelegate
    @EnvironmentObject private var store: Store
    
    @ObservedObject var subscription: Subscription
    @ObservedObject var notificationsModel: NotificationsObservable
    
    @State private var editMode = EditMode.inactive
    @State private var selection = Set<Notification>()
    
    @State private var showAlert = false
    @State private var activeAlert: ActiveAlert = .clear
    
    private var subscriptionManager: SubscriptionManager {
        return SubscriptionManager(store: store)
    }
    
    init(subscription: Subscription) {
        self.subscription = subscription
        self.notificationsModel = NotificationsObservable(subscriptionID: subscription.objectID)
    }

    var body: some View {
        if #available(iOS 15.0, *) {
            notificationList
                .refreshable {
                    subscriptionManager.poll(subscription)
                }
        } else {
            notificationList
        }
    }
    
    private var notificationList: some View {
        List(selection: $selection) {
            ForEach(notificationsModel.notifications, id: \.self) { notification in
                NotificationRowView(notification: notification)
            }
        }
        .listStyle(PlainListStyle())
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, self.$editMode)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if (self.editMode != .active) {
                    Button(action: {
                        // iOS bug (?): We create a custom back button, because the original back button doesn't reset
                        // selectedBaseUrl early enough and the row stays highlighted for a long time,
                        // which is weird and feels wrong. This avoids that behavior.
                        
                        self.delegate.selectedBaseUrl = nil
                    }){
                        Image(systemName: "chevron.left")
                    }
                    .padding([.top, .bottom, .trailing], 40)
                }
            }
            ToolbarItem(placement: .principal) {
                Text(subscription.topicName())
                    .font(.headline)
                    .lineLimit(1)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if (self.editMode == .active) {
                    editButton
                } else {
                    Menu {
                        if #unavailable(iOS 15.0) {
                            Button("Refresh") {
                                subscriptionManager.poll(subscription)
                            }
                        }
                        if notificationsModel.notifications.count > 0 {
                            editButton
                        }
                        Button("Send test notification") {
                            self.sendTestNotification()
                        }
                        if notificationsModel.notifications.count > 0 {
                            Button("Clear all notifications") {
                                self.showAlert = true
                                self.activeAlert = .clear
                            }
                        }
                        Button("Unsubscribe") {
                            self.showAlert = true
                            self.activeAlert = .unsubscribe
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .padding([.leading], 40)
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
                        action: deleteAll
                    ),
                    secondaryButton: .cancel())
            case .unsubscribe:
                return Alert(
                    title: Text("Unsubscribe"),
                    message: Text("Do you really want to unsubscribe from this topic and delete all of the notifications you received?"),
                    primaryButton: .destructive(
                        Text("Unsubscribe"),
                        action: unsubscribe
                    ),
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
        .overlay(Group {
            if notificationsModel.notifications.count == 0 {
                VStack {
                    Text("You haven't received any notifications for this topic yet.")
                        .font(.title2)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.bottom)
                    
                    if #available(iOS 15.0, *) {
                        Text("To send notifications to this topic, simply PUT or POST to the topic URL.\n\nExample:\n`$ curl -d \"Hi\" \(shortUrl(url: subscription.urlString()))`\n\nDetailed instructions are available on [ntfy.sh](https://ntfy.sh) and [in the docs](https://ntfy.sh/docs).")
                            .foregroundColor(.gray)
                    } else {
                        Text("To send notifications to this topic, simply PUT or POST to the topic URL.\n\nExample:\n`$ curl -d \"Hi\" \(shortUrl(url: subscription.urlString()))`\n\nDetailed instructions are available on https://ntfy.sh and https://ntfy.sh/docs.")
                            .foregroundColor(.gray)
                    }
                }
                .padding(40)
            }
        })
        .onAppear {
            cancelSubscriptionNotifications()
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
    
    private func sendTestNotification() {
        let possibleTags: Array<String> = ["warning", "skull", "success", "triangular_flag_on_post", "de", "us", "dog", "cat", "rotating_light", "bike", "backup", "rsync", "this-s-a-tag", "ios"]
        let priority = Int.random(in: 1..<6)
        let tags = Array(possibleTags.shuffled().prefix(Int.random(in: 0..<4)))
        DispatchQueue.global(qos: .background).async {
            let user = store.getUser(baseUrl: subscription.baseUrl!)?.toBasicUser()
            ApiService.shared.publish(
                subscription: subscription,
                user: user,
                message: "This is a test notification from the ntfy iOS app. It has a priority of \(priority). If you send another one, it may look different.",
                title: "Test: You can set a title if you like",
                priority: priority,
                tags: tags
            )
        }
    }
    
    private func unsubscribe() {
        DispatchQueue.global(qos: .background).async {
            subscriptionManager.unsubscribe(subscription)
        }
        delegate.selectedBaseUrl = nil
    }
    
    private func deleteAll() {
        DispatchQueue.global(qos: .background).async {
            store.delete(allNotificationsFor: subscription)
        }
    }
    
    private func deleteSelected() {
        DispatchQueue.global(qos: .background).async {
            store.delete(notifications: selection)
            selection = Set<Notification>()
        }
        editMode = .inactive
    }
    
    private func cancelSubscriptionNotifications() {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.getDeliveredNotifications { notifications in
            let ids = notifications
                .filter { notification in
                    let userInfo = notification.request.content.userInfo
                    if let baseUrl = userInfo["base_url"] as? String, let topic = userInfo["topic"] as? String {
                        return baseUrl == subscription.baseUrl && topic == subscription.topic
                    }
                    return false
                }
                .map { notification in
                    notification.request.identifier
                }
            if !ids.isEmpty {
                Log.d(tag, "Cancelling \(ids.count) notification(s) from notification center")
                notificationCenter.removeDeliveredNotifications(withIdentifiers: ids)
            }
        }
    }
}

struct NotificationRowView: View {
    @EnvironmentObject private var store: Store
    @ObservedObject var notification: Notification
    
    var body: some View {
        if #available(iOS 15.0, *) {
            notificationRow
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        store.delete(notification: notification)
                    } label: {
                        Label("Delete", systemImage: "trash.circle")
                    }
                }
        } else {
            notificationRow
        }
    }
    
    private var notificationRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 2) {
                Text(notification.shortDateTime())
                    .font(.subheadline)
                    .foregroundColor(.gray)
                if [1,2,4,5].contains(notification.priority) {
                    Image("priority-\(notification.priority)")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                }
            }
            .padding([.bottom], 2)
            if let title = notification.formatTitle(), title != "" {
                Text(title)
                    .font(.headline)
                    .bold()
                    .padding([.bottom], 2)
            }
            Text(notification.formatMessage())
                .font(.body)
            if !notification.nonEmojiTags().isEmpty {
                Text("Tags: " + notification.nonEmojiTags().joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding([.top], 2)
            }
            if !notification.actionsList().isEmpty {
                HStack {
                    ForEach(notification.actionsList()) { action in
                        if #available(iOS 15, *) {
                            Button(action.label) {
                                ActionExecutor.execute(action)
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button(action: {
                                ActionExecutor.execute(action)
                            }) {
                                Text(action.label)
                                    .padding(EdgeInsets(top: 10.0, leading: 10.0, bottom: 10.0, trailing: 10.0))
                                    .foregroundColor(.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                            }
                            .background(Color.accentColor)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding([.top], 5)
            }
        }
        .padding(.all, 4)
        .onTapGesture {
            // TODO: This gives no feedback to the user, and it only works if the text is tapped
            UIPasteboard.general.setValue(notification.formatMessage(), forPasteboardType: UTType.plainText.identifier)
        }
    }
}

struct NotificationListView_Previews: PreviewProvider {
    static var previews: some View {
        let store = Store.preview
        Group {
            let subscriptionWithNotifications = store.makeSubscription(store.context, "stats", Store.sampleMessages["stats"]!)
            let subscriptionWithoutNotifications = store.makeSubscription(store.context, "announcements", Store.sampleMessages["announcements"]!)
            NotificationListView(subscription: subscriptionWithNotifications)
                .environment(\.managedObjectContext, store.context)
                .environmentObject(store)
            NotificationListView(subscription: subscriptionWithoutNotifications)
                .environment(\.managedObjectContext, store.context)
                .environmentObject(store)
        }
    }
}

