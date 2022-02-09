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
                ZStack {
                    NavigationLink(
                        destination: SubscriptionDetail(subscription: subscription)
                    ) {
                        EmptyView()
                    }
                    .opacity(0.0)
                    .buttonStyle(PlainButtonStyle())

                    SubscriptionRow(subscription: subscription)
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
