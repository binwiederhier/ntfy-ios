import SwiftUI
import CoreData
import FirebaseMessaging
import UserNotifications

enum NotificationsRoute: Hashable {
    case all
    case topic(Subscription)
}

struct SubscriptionListView: View {
    let tag = "SubscriptionList"

    @EnvironmentObject private var store: Store
    @EnvironmentObject private var delegate: AppDelegate
    @StateObject var subscriptionsModel = SubscriptionsObservable()
    @StateObject var allNotificationsModel = AllNotificationsObservable()
    @State private var showingAddDialog = false
    @State private var path: [NotificationsRoute] = []

    private var subscriptionManager: SubscriptionManager {
        return SubscriptionManager(store: store)
    }

    var body: some View {
        NavigationStack(path: $path) {
            subscriptionList
                .navigationDestination(for: NotificationsRoute.self) { route in
                    switch route {
                    case .all:
                        AllNotificationsView()
                    case .topic(let subscription):
                        NotificationListView(subscription: subscription)
                    }
                }
        }
        .onChange(of: delegate.selectedBaseUrl) { newValue in
            guard
                let newValue,
                let subscription = subscriptionsModel.subscriptions.first(where: { $0.urlString() == newValue })
            else {
                return
            }
            path = [.topic(subscription)]
        }
    }

    private var subscriptionList: some View {
        List {
            if !subscriptionsModel.subscriptions.isEmpty {
                NavigationLink(value: NotificationsRoute.all) {
                    AllNotificationsRowView(
                        notificationsModel: allNotificationsModel,
                        topicCount: subscriptionsModel.subscriptions.count
                    )
                }
            }
            ForEach(subscriptionsModel.subscriptions) { subscription in
                SubscriptionItemNavView(subscription: subscription)
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            pollSubscriptions()
        }
        .navigationTitle("Subscribed topics")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    self.showingAddDialog = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .overlay {
            if subscriptionsModel.subscriptions.isEmpty {
                emptyState
            }
        }
        .sheet(isPresented: $showingAddDialog) {
            SubscriptionAddView(isShowing: $showingAddDialog)
        }
        .onAppear {
            // Ensures subscription count stays up to date, so a pull to refresh isn't required
            pollSubscriptions()
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if #available(iOS 17.0, *) {
            ContentUnavailableView {
                Label("No subscriptions yet", systemImage: "tray")
            } description: {
                Text("Tap + to subscribe to a topic. You'll get notified whenever a message is sent to it via PUT or POST.\n\nDetailed instructions are available on [ntfy.sh](https://ntfy.sh) and [in the docs](https://ntfy.sh/docs).")
            }
        } else {
            VStack {
                Text("It looks like you don't have any subscriptions yet")
                    .font(.title2)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.bottom)

                Text("Click the + to create or subscribe to a topic. Afterwards, you receive notifications on your device when sending messages via PUT or POST.\n\nDetailed instructions are available on [ntfy.sh](https://ntfy.sh) and [in the docs](https://ntfy.sh/docs).")
                    .foregroundColor(.gray)
            }
            .padding(40)
        }
    }

    private func pollSubscriptions() {
        subscriptionsModel.subscriptions.forEach { subscription in
            subscriptionManager.poll(subscription)
        }
    }
}

struct SubscriptionItemNavView: View {
    @EnvironmentObject private var store: Store
    @ObservedObject var subscription: Subscription
    @State private var unsubscribeAlert = false

    private var subscriptionManager: SubscriptionManager {
        return SubscriptionManager(store: store)
    }

    var body: some View {
        NavigationLink(value: NotificationsRoute.topic(subscription)) {
            SubscriptionItemRowView(subscription: subscription)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                self.unsubscribeAlert = true
            } label: {
                Label("Delete", systemImage: "trash.circle")
            }
        }
        .alert(isPresented: $unsubscribeAlert) {
            Alert(
                title: Text("Unsubscribe"),
                message: Text("Do you really want to unsubscribe from this topic and delete all of the notifications you received?"),
                primaryButton: .destructive(
                    Text("Unsubscribe"),
                    action: {
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        self.subscriptionManager.unsubscribe(subscription)
                        self.unsubscribeAlert = false
                    }
                ),
                secondaryButton: .cancel()
            )
        }
    }
}

struct SubscriptionItemRowView: View {
    @ObservedObject var subscription: Subscription
    @StateObject private var notificationsModel: NotificationsObservable
    @State private var showIconEditor = false

    init(subscription: Subscription) {
        self.subscription = subscription
        _notificationsModel = StateObject(wrappedValue: NotificationsObservable(subscriptionID: subscription.objectID))
    }

    private var isDefaultServer: Bool {
        guard let baseUrl = subscription.baseUrl else { return true }
        return normalizeBaseUrl(baseUrl) == normalizeBaseUrl(Config.appBaseUrl)
    }

    // notificationsModel.notifications is already sorted by time descending
    private var unreadCount: Int {
        notificationsModel.notifications.reduce(0) { $1.isRead ? $0 : $0 + 1 }
    }

    var body: some View {
        let totalNotificationCount = notificationsModel.notifications.count
        HStack(spacing: 12) {
            Button {
                showIconEditor = true
            } label: {
                TopicAvatarView(name: subscription.topicName(), emoji: subscription.icon)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(subscription.topicName())
                            .font(.headline)
                            .lineLimit(1)
                        if !isDefaultServer, let baseUrl = subscription.baseUrl {
                            Text(shortUrl(url: baseUrl))
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Text(notificationsModel.notifications.first?.shortDateTime() ?? "")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                HStack {
                    Text("\(totalNotificationCount) notification\(totalNotificationCount != 1 ? "s" : "")")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    if unreadCount > 0 {
                        Spacer()
                        UnreadDotView()
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showIconEditor) {
            TopicIconEditorView(subscription: subscription)
        }
    }
}

struct AllNotificationsRowView: View {
    @ObservedObject var notificationsModel: AllNotificationsObservable
    let topicCount: Int

    private var unreadCount: Int {
        notificationsModel.notifications.reduce(0) { $1.isRead ? $0 : $0 + 1 }
    }

    var body: some View {
        let notifications = notificationsModel.notifications
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 40, height: 40)
                Image(systemName: "tray.full.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 16))
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("All Notifications")
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    // notifications is already sorted by time descending
                    Text(notifications.first?.shortDateTime() ?? "")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                HStack {
                    Text("\(notifications.count) notification\(notifications.count != 1 ? "s" : "") across \(topicCount) topic\(topicCount != 1 ? "s" : "")")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    if unreadCount > 0 {
                        Spacer()
                        UnreadDotView()
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct TopicAvatarView: View {
    let name: String
    var emoji: String? = nil

    private var initial: String {
        String(name.first ?? "?").uppercased()
    }

    private var color: Color {
        let hash = abs(name.hashValue)
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.55, brightness: 0.85)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 40, height: 40)
            if let emoji, !emoji.isEmpty {
                Text(emoji)
                    .font(.system(size: 20))
            } else {
                Text(initial)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }
}

struct UnreadDotView: View {
    var body: some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: 8, height: 8)
    }
}

struct SubscriptionListView_Previews: PreviewProvider {
    static var previews: some View {
        let store = Store.preview // Store.previewEmpty
        SubscriptionListView()
            .environment(\.managedObjectContext, store.context)
            .environmentObject(store)
            .environmentObject(AppDelegate())
    }
}
