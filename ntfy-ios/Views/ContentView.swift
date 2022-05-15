//
//  ContentView.swift
//  ntfy.sh
//
//  Created by Andrew Cope on 1/16/22.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var subscriptions: NtfySubscriptionList
    @State var currentView = CurrentView.subscriptionList
    
    var body: some View {
        switch (currentView) {
        case .addingSubscription:
            AddSubscriptionView(subscriptions: subscriptions, currentView: $currentView)
        case .subscriptionList:
            SubscriptionsList(subscriptions: subscriptions, currentView: $currentView)
        }
    }
}

enum CurrentView {
    case addingSubscription, subscriptionList
}
