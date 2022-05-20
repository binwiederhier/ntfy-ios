// https://www.raywenderlich.com/14958063-modern-efficient-core-data
// https://www.hackingwithswift.com/books/ios-swiftui/how-to-combine-core-data-and-swiftui

import SwiftUI
import CoreData
import FirebaseMessaging
import UserNotifications

struct SubscriptionListView: View {
    let tag = "SubscriptionList"
    
    @EnvironmentObject private var store: Store
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Subscription.topic, ascending: true)]) var subscriptions: FetchedResults<Subscription>
    
    @State private var unsubscribeAlert = false
    @State private var unsubscribeSubscription: Subscription?
    
    private var subscriptionManager: SubscriptionManager {
        return SubscriptionManager(store: store)
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(subscriptions) { subscription in
                    ZStack {
                        NavigationLink(destination: NotificationListView(subscription: subscription)) {
                            EmptyView()
                        }
                        .opacity(0.0)
                        .buttonStyle(PlainButtonStyle())

                        SubscriptionRowView(subscription: subscription)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            unsubscribeAlert = true
                            unsubscribeSubscription = subscription
                            //subscriptionManager.unsubscribe(subscription)
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
                                    subscriptionManager.unsubscribe(unsubscribeSubscription!)
                                    unsubscribeAlert = false
                                    unsubscribeSubscription = nil
                                }
                            ),
                            secondaryButton: .cancel()
                        )
                    }
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("Subscribed topics")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(
                        destination: SubscriptionAddView()
                    ) {
                        Image(systemName: "plus")
                    }
                }
            }
            .overlay(Group {
                if subscriptions.isEmpty {
                    Text("No topics")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
}

struct SubscriptionRowView: View {
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

struct SubscriptionsListView_Previews: PreviewProvider {
  static var previews: some View {
    SubscriptionListView()
      .environment(\.managedObjectContext, Store.preview.context)
      .environmentObject(Store.preview)
  }
}
