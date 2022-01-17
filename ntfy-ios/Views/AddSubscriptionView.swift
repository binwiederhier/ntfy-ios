//
//  AddSubscriptionView.swift
//  ntfy.sh
//
//  Created by Andrew Cope on 1/16/22.
//

import SwiftUI

struct AddSubscriptionView: View {
    @State private var topic: String = ""

    @Binding var addingSubscription: Bool

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Topic Name")) {
                    TextField("Topic name", text: $topic)
                }
                Button(action: {
                    if !topic.isEmpty {
                        let subscription = NtfySubscription(id: 1, baseUrl: "192.168.1.135", topic: topic)
                        subscription.save()
                        subscription.subscribe(to: topic)
                        addingSubscription = false
                    }
                }) {
                    Text("Subscribe")
                }
                .disabled(topic.isEmpty)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Subscribe to topic").font(.headline)
            }
        }
    }
}
