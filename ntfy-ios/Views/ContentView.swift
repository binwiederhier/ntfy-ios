//
//  ContentView.swift
//  ntfy.sh
//
//  Created by Andrew Cope on 1/16/22.
//

import SwiftUI

struct ContentView: View {
    @State var addingSubscription = false
    @State var managingUsers = false
    @State var currentView = CurrentView.subscriptionList

    var body: some View {
        switch (currentView) {
        case .managingUsers:
            UserManagementView(currentView: $currentView)
        case .addingSubscription:
            AddSubscriptionView(currentView: $currentView)
        case .subscriptionList:
            SubscriptionsList(currentView: $currentView)
        }
    }
}

enum CurrentView {
    case addingSubscription, managingUsers, subscriptionList
}
