//
//  ContentView.swift
//  ntfy-ios
//
//  Created by Andrew Cope on 1/15/22.
//

// https://www.hackingwithswift.com/books/ios-swiftui/how-to-combine-core-data-and-swiftui

import SwiftUI
import CoreData
import FirebaseMessaging

struct SubscriptionsList: View {
    @Environment(\.managedObjectContext) var context
    @FetchRequest(sortDescriptors: []) var subscriptions: FetchedResults<Subscription>
    
    var body: some View {
        NavigationView {
            List {
                ForEach(subscriptions) { subscription in
                    let notifications = subscription.notifications!.sortedArray(using: [NSSortDescriptor(key: "time", ascending: false)]) as [Notification]
                    ZStack {
                        NavigationLink(destination: NotificationListView(subscription: subscription, notifications: notifications)) {
                            EmptyView()
                        }
                        .opacity(0.0)
                        .buttonStyle(PlainButtonStyle())

                        SubscriptionRow(subscription: subscription)
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
