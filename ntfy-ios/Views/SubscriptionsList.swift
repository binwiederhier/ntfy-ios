//
//  ContentView.swift
//  ntfy-ios
//
//  Created by Andrew Cope on 1/15/22.
//

import SwiftUI

struct SubscriptionsList: View {
    @State var subscriptions = Database.current.getSubscriptions()

    @Binding var addingSubscription: Bool

    var body: some View {
        NavigationView {
            List(subscriptions) { subscription in
                NavigationLink {
                    SubscriptionDetail(subscription: subscription)
                } label: {
                    SubscriptionRow(subscription: subscription)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        subscription.delete()
                        subscriptions = Database.current.getSubscriptions()
                    } label: {
                        Label("Delete", systemImage: "trash.circle")
                    }
                }
            }
            .navigationTitle("Subscribed topics")
            .toolbar {
                Button(action: {
                    addingSubscription = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
    }
}
