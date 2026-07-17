import SwiftUI
import UserNotifications

struct AllNotificationsView: View {
    private let tag = "AllNotificationsView"

    @EnvironmentObject private var store: Store
    @StateObject var notificationsModel = AllNotificationsObservable()

    @State private var searchText = ""
    @State private var showClearAllAlert = false

    private var filteredNotifications: [Notification] {
        guard !searchText.isEmpty else {
            return notificationsModel.notifications
        }
        return notificationsModel.notifications.filter {
            $0.formatMessage().localizedCaseInsensitiveContains(searchText) ||
            ($0.formatTitle()?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        List {
            ForEach(filteredNotifications, id: \.self) { notification in
                NotificationRowView(
                    notification: notification,
                    onCopyMessage: {},
                    subscriptionLabel: notification.subscription?.topicName()
                )
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "Search notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("All Notifications")
                    .font(.headline)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if notificationsModel.notifications.count > 0 {
                    Button("Clear all") {
                        showClearAllAlert = true
                    }
                }
            }
        }
        .overlay {
            if notificationsModel.notifications.isEmpty {
                emptyState
            }
        }
        .alert("Clear all notifications", isPresented: $showClearAllAlert) {
            Button("Permanently delete", role: .destructive) {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                store.deleteAllNotifications()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Do you really want to delete all of the notifications across every topic?")
        }
        .onAppear {
            cancelAllDeliveredNotifications()
        }
        .refreshable {
            pollAllSubscriptions()
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if #available(iOS 17.0, *) {
            ContentUnavailableView(
                "No notifications yet",
                systemImage: "bell.slash",
                description: Text("Notifications from all of your subscribed topics will show up here.")
            )
        } else {
            VStack {
                Text("You haven't received any notifications yet.")
                    .font(.title2)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(40)
        }
    }

    private func cancelAllDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    private func pollAllSubscriptions() {
        let subscriptionManager = SubscriptionManager(store: store)
        store.getSubscriptions()?.forEach { subscription in
            subscriptionManager.poll(subscription)
        }
    }
}

struct AllNotificationsView_Previews: PreviewProvider {
    static var previews: some View {
        let store = Store.preview
        NavigationStack {
            AllNotificationsView()
        }
        .environment(\.managedObjectContext, store.context)
        .environmentObject(store)
    }
}
