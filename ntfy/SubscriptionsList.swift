//
//  ContentView.swift
//  ntfy-ios
//
//  Created by Andrew Cope on 1/15/22.
//

// https://www.hackingwithswift.com/books/ios-swiftui/how-to-combine-core-data-and-swiftui

import SwiftUI

struct SubscriptionsList: View {
    @Environment(\.managedObjectContext) var context
    @FetchRequest(sortDescriptors: []) var subscriptions: FetchedResults<Subscription>
    
    var body: some View {
        VStack {
            List(subscriptions) { subscription in
                Text("\(subscription.topic ?? "")")
            }
            Button("Add") {
                let firstNames = ["Ginny", "Harry", "Hermione", "Luna", "Ron"]
                let chosenFirstName = firstNames.randomElement()!

                let subscription = Subscription(context: context)
                subscription.baseUrl = "https://ntfy.sh"
                subscription.topic = chosenFirstName
                try? context.save()
            }
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
