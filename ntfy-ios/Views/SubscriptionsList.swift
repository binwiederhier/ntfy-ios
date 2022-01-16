//
//  ContentView.swift
//  ntfy-ios
//
//  Created by Andrew Cope on 1/15/22.
//

import SwiftUI

struct SubscriptionsList: View {
    let subscriptions = Database.current.getSubscriptions()

    var body: some View {
        NavigationView {
            List(subscriptions) { subscription in
                NavigationLink {
                    SubscriptionDetail(subscription: subscription)
                } label: {
                    SubscriptionRow(subscription: subscription)
                }
                .navigationTitle("Subscribed topics")
            }
        }
    }
}

struct SubscriptionsList_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionsList()
    }
}
