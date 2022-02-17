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
                Section(
                    header: Text("Topic Name"),
                    footer: Text("Topics may not be password protected, so choose a name that's not easy to guess. Once subscribed, you can PUT/POST notifications")
                ) {
                    TextField("Topic name, e.g. server_alerts", text: $topic)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        addingSubscription = false
                    }) {
                        Text("Cancel")
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("New Topic").font(.headline)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if !topic.isEmpty {
                            let subscription = NtfySubscription(id: 1, baseUrl: Configuration.appBaseUrl, topic: topic)
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
        }
    }
}
