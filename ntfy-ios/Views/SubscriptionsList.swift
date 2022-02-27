//
//  ContentView.swift
//  ntfy-ios
//
//  Created by Andrew Cope on 1/15/22.
//

import SwiftUI

struct SubscriptionsList: View {
    @ObservedObject var subscriptions = NtfySUbscriptionList()

    @Binding var currentView: CurrentView

    var body: some View {
        NavigationView {
            List{
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
            .navigationTitle("Subscribed Topics")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        currentView = .addingSubscription
                    }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        currentView = .managingUsers
                    }) {
                        Text("Users")
                    }
                }
            }
            .overlay(Group {
                if subscriptions.subscriptions.isEmpty {
                    Text("No Topics")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            self.subscriptions.objectWillChange.send()
        }
    }
}
