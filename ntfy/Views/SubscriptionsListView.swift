// https://www.raywenderlich.com/14958063-modern-efficient-core-data
// https://www.hackingwithswift.com/books/ios-swiftui/how-to-combine-core-data-and-swiftui

import SwiftUI
import CoreData
import FirebaseMessaging
import UserNotifications

struct SubscriptionListView: View {
    let tag = "SubscriptionList"
    
    @Environment(\.managedObjectContext) var context
    @EnvironmentObject private var store: Store
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "topic", ascending: true)]) var subscriptions: FetchedResults<Subscription>
    
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
                            unsubscribe(subscription)
                        } label: {
                            Label("Delete", systemImage: "trash.circle")
                        }
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
    
    func unsubscribe(_ subscription: Subscription) {
        DispatchQueue.main.async {
            if let topic = subscription.topic {
                Messaging.messaging().unsubscribe(fromTopic: topic)
            }
            context.delete(subscription)
            try? context.save()
        }
    }
    
}

/*
struct SubscriptionsList_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionsList(
            subscriptions: NtfySubscriptionList,
            currentView: (.subscriptionList)
        )
    }
}
*/
