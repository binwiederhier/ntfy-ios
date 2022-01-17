//
//  ContentView.swift
//  ntfy.sh
//
//  Created by Andrew Cope on 1/16/22.
//

import SwiftUI

struct ContentView: View {
    @State var addingSubscription = false

    var body: some View {
        return Group {
            if addingSubscription {
                AddSubscriptionView(addingSubscription: $addingSubscription)
            } else {
                SubscriptionsList(addingSubscription: $addingSubscription)
            }
        }
    }
}
