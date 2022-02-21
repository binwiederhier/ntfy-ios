//
//  AddSubscriptionView.swift
//  ntfy.sh
//
//  Created by Andrew Cope on 1/16/22.
//

import SwiftUI

struct AddSubscriptionView: View {
    @State private var topic: String = ""
    @State private var baseUrl: String = Configuration.appBaseUrl
    @State private var showLogin: Bool = false
    @State private var username: String = ""
    @State private var password: String = ""

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
                if showLogin {
                    Section(
                        header: Text("Login")
                    ) {
                        TextField("Username", text: $username)
                            .textInputAutocapitalization(.none)
                            .disableAutocorrection(true)
                        SecureField("Password", text: $password)
                    }
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
                            /*
                             Validation function:
                             1. Topic is not empty
                             2. Topic matches regex? Should match Firebase topic regex

                             Authentication function:
                             1. Get baseUrl
                             2. Get user for baseUrl
                             2. api.checkAuth(baseUrl, topic, user)
                             3. If authorized, continue to subscribe
                             4. Else if user != null, access not allowed to topic but user exists
                             5. Else (user is null), access not allowed, show login view

                             Login function:
                             1. Login user / pass view
                             2. api.checkAuth(baseUrl, topic, user -> user / pass)
                             3. If authorized, save user to database, continue to subscribe
                             4. Else access not allowed, show login view again


                             Subscribe function:
                             1. Create subscription
                             2. Add subscription to database
                             3. If baseUrl == appBaseUrl, subscribe to firebase topic
                             4. Fetch cached messages
                             5. Switch to SubscriptionDetail view
                             */
                            var user = Database.current.findUser(baseUrl: baseUrl)
                            if showLogin {
                                print("Authorization via UI forms")
                                if (user != nil) {
                                    user!.username = username
                                    user!.password = password
                                } else {
                                    user = NtfyUser(baseUrl: baseUrl, username: username, password: password)
                                }
                            }
                            ApiService.shared.checkAuth(baseUrl: baseUrl, topic: topic, user: user) { authResponse, error in
                                if let authorized = authResponse?.success {
                                    if user != nil {
                                        Database.current.addUser(user: user!)
                                    }
                                    showLogin = false
                                    let subscription = NtfySubscription(id: Int64(arc4random()), baseUrl: baseUrl, topic: topic)
                                    subscription.save()
                                    if baseUrl == Configuration.appBaseUrl {
                                        subscription.subscribe(to: topic)
                                    }
                                    ApiService.shared.poll(subscription: subscription, user: user) { (notifications, error) in
                                        if let notifications = notifications {
                                            for notification in notifications {
                                                notification.save()
                                            }
                                        }
                                    }
                                    addingSubscription = false
                                } else {
                                    print("Auth failed")
                                    showLogin = true
                                }
                            }
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
