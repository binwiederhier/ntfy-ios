import SwiftUI
import CoreData
import FirebaseMessaging
import UserNotifications

enum SubscriptionSortOrder: String, CaseIterable, Identifiable {
    case recent
    case name

    var id: String { rawValue }

    var label: String {
        switch self {
        case .recent: return "Recent activity"
        case .name: return "Name"
        }
    }

    var systemImage: String {
        switch self {
        case .recent: return "clock"
        case .name: return "textformat"
        }
    }
}

struct SubscriptionListView: View {
    let tag = "SubscriptionList"
    
    @EnvironmentObject private var store: Store
    @ObservedObject var subscriptionsModel = SubscriptionsObservable()
    @AppStorage("subscriptionSortOrder") private var sortOrder: SubscriptionSortOrder = .recent
    @State private var showingAddDialog = false
    
    private var subscriptionManager: SubscriptionManager {
        return SubscriptionManager(store: store)
    }
    
    var body: some View {
        NavigationView {
            if #available(iOS 15.0, *) {
                subscriptionList
                    .refreshable {
                        pollSubscriptions()
                    }
            } else {
                subscriptionList
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                pollSubscriptions()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                    }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private var subscriptionList: some View {
        List {
            ForEach(sortedSubscriptions) { subscription in
                SubscriptionItemNavView(subscription: subscription)
            }
        }
        .listStyle(PlainListStyle())
        .navigationTitle("Subscribed topics")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Menu {
                    Picker("Sort by", selection: $sortOrder) {
                        ForEach(SubscriptionSortOrder.allCases) { order in
                            Label(order.label, systemImage: order.systemImage)
                                .tag(order)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                Button {
                    self.showingAddDialog = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .overlay(Group {
            if subscriptionsModel.subscriptions.isEmpty {
                VStack {
                    Text("It looks like you don't have any subscriptions yet")
                        .font(.title2)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.bottom)

                    if #available(iOS 15.0, *) {
                        Text("Click the + to create or subscribe to a topic. Afterwards, you receive notifications on your device when sending messages via PUT or POST.\n\nDetailed instructions are available on [ntfy.sh](https://ntfy.sh) and [in the docs](https://ntfy.sh/docs).")
                            .foregroundColor(.gray)
                    } else {
                        Text("Click the + to create or subscribe to a topic. Afterwards, you receive notifications on your device when sending messages via PUT or POST.\n\nDetailed instructions are available on https://ntfy.sh and https://ntfy.sh/docs")
                            .foregroundColor(.gray)
                    }
                }
                .padding(40)
            }
        })
        .sheet(isPresented: $showingAddDialog) {
            SubscriptionAddView(isShowing: $showingAddDialog)
        }
        .onAppear {
            // Ensures subscription count stays up to date, so a pull to refresh isn't required
            pollSubscriptions()
        }
    }

    private var sortedSubscriptions: [Subscription] {
        let subscriptions = subscriptionsModel.subscriptions
        let byName: (Subscription, Subscription) -> Bool = {
            $0.displayName().localizedStandardCompare($1.displayName()) == .orderedAscending
        }
        switch sortOrder {
        case .name:
            return subscriptions.sorted(by: byName)
        case .recent:
            let lastTimes = Dictionary(uniqueKeysWithValues: subscriptions.map { ($0.objectID, $0.lastNotificationTime()) })
            return subscriptions.sorted { a, b in
                let timeA = lastTimes[a.objectID] ?? 0
                let timeB = lastTimes[b.objectID] ?? 0
                return timeA != timeB ? timeA > timeB : byName(a, b)
            }
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
    @EnvironmentObject private var delegate: AppDelegate
    @ObservedObject var subscription: Subscription
    @State private var unsubscribeAlert = false
    
    private var subscriptionManager: SubscriptionManager {
        return SubscriptionManager(store: store)
    }
    
    var body: some View {
        if #available(iOS 15.0, *) {
            subscriptionRow
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        self.unsubscribeAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash.circle")
                    }
                }
        } else {
            subscriptionRow
        }
    }
    
    private var subscriptionRow: some View {
        ZStack {
            NavigationLink(
                destination: NotificationListView(subscription: subscription),
                tag: subscription.urlString(),
                selection: $delegate.selectedBaseUrl
            ) {
                EmptyView()
            }
            .opacity(0.0)
            .buttonStyle(PlainButtonStyle())
            
            SubscriptionItemRowView(subscription: subscription)
        }
        .alert(isPresented: $unsubscribeAlert) {
            Alert(
                title: Text("Unsubscribe"),
                message: Text("Do you really want to unsubscribe from this topic and delete all of the notifications you received?"),
                primaryButton: .destructive(
                    Text("Unsubscribe"),
                    action: {
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
    
    var body: some View {
        let totalNotificationCount = subscription.notificationCount()
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(subscription.displayName())
                    .font(.headline)
                    .bold()
                    .lineLimit(1)
                Spacer()
                Text(subscription.lastNotification()?.shortDateTime() ?? "")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 12.0))
                    .foregroundColor(.gray)
            }
            Spacer()
            Text("\(totalNotificationCount) notification\(totalNotificationCount != 1 ? "s" : "")")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.all, 4)
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
