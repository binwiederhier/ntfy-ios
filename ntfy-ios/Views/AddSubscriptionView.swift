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

    @State private var showAlert = false
    @State private var activeAlert: AddSubscriptionView.ActiveAlert = .invalidTopic
    @State private var authFailureError = ""

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
                        let sanitizedTopic = sanitizeTopic(topic: topic)
                        if isTopicValid(topic: sanitizedTopic) {
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
                            ApiService.shared.checkAuth(baseUrl: baseUrl, topic: sanitizedTopic, user: user) { authResponse, error in
                                if let authResponse = authResponse {
                                    if let success = authResponse.success, success {
                                        if user != nil {
                                            Database.current.addUser(user: user!)
                                        }
                                        let subscription = NtfySubscription(id: Int64(arc4random()), baseUrl: baseUrl, topic: sanitizedTopic)
                                        subscription.save()
                                        if baseUrl == Configuration.appBaseUrl {
                                            subscription.subscribe(to: sanitizedTopic)
                                        }
                                        subscription.fetchNewNotifications(user: user)
                                        addingSubscription = false
                                        showLogin = false
                                    } else {
                                        showLogin = true
                                        showAlert = true
                                        activeAlert = .requiresAuth
                                    }
                                } else if let error = error {
                                    showAlert = true
                                    activeAlert = .authFailure
                                    authFailureError = error.localizedDescription
                                } else {
                                    showAlert = true
                                    activeAlert = .unknownFailure
                                }
                            }
                        } else {
                            print("Invalid topic")
                            showAlert = true
                            activeAlert = .invalidTopic
                        }
                    }) {
                        Text("Subscribe")
                    }
                    .disabled(!isTopicValid(topic: sanitizeTopic(topic: topic)) && addingSubscription)
                }
            }
            .alert(isPresented: $showAlert) {
                switch activeAlert {
                case .requiresAuth:
                    return Alert(
                        title: Text("Authentication Required"),
                        message: Text("This topic is password protected. Please enter a username and password to continue."),
                        dismissButton: .default(Text("OK"))
                    )
                case .invalidTopic:
                    return Alert(
                        title: Text("Invalid Topic"),
                        message: Text("Please choose another topic name"),
                        dismissButton: .default(Text("OK"))
                    )
                case .authFailure:
                    return Alert(
                        title: Text("Authorization Failure"),
                        message: Text(authFailureError),
                        dismissButton: .default(Text("OK"))
                    )
                case .unknownFailure:
                    return Alert(
                        title: Text("Authorization Failure"),
                        message: Text("Unknown Error"),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
        }
    }

    private func sanitizeTopic(topic: String) -> String {
        return topic.trimmingCharacters(in: [" "])
    }

    private func isTopicValid(topic: String) -> Bool {
        return !topic.isEmpty && (topic.range(of: "^[-_A-Za-z0-9]{1,64}$", options: .regularExpression, range: nil, locale: nil) != nil)
    }
}

extension AddSubscriptionView {
    enum ActiveAlert {
        case requiresAuth, invalidTopic, authFailure, unknownFailure
    }
}
