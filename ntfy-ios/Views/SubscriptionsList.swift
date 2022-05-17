//
//  ContentView.swift
//  ntfy-ios
//
//  Created by Andrew Cope on 1/15/22.
//

import SwiftUI

struct SubscriptionsList: View {
    @ObservedObject var subscriptions: NtfySubscriptionList
    @Binding var currentView: CurrentView

    var body: some View {
        NavigationView {
            List {
                ForEach(subscriptions.subscriptions) { subscription in
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
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            subscription.delete()
                            subscriptions.subscriptions = Database.current.getSubscriptions()
                        } label: {
                            Label("Delete", systemImage: "trash.circle")
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("Topics")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        currentView = .addingSubscription
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .overlay(Group {
                if subscriptions.subscriptions.isEmpty {
                    Text("No Topics")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            subscriptions.objectWillChange.send()
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