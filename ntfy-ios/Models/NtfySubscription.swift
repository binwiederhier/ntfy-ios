//
//  Subscription.swift
//  ntfy.sh
//
//  Created by Andrew Cope on 1/15/22.
//

import FirebaseMessaging
import Foundation

class NtfySubscription: Identifiable {
    
    // Properties
    var id: Int64!
    var baseUrl: String
    var topic: String

    init(id: Int64, baseUrl: String, topic: String) {
        // Initialize values
        self.id = id
        self.baseUrl = baseUrl
        self.topic = topic
    }

    func displayName() -> String {
        return self.baseUrl + "/" + self.topic
    }

    func save() -> NtfySubscription {
        Database.current.addSubscription(subscription: self)
    }

    func subscribe(to topic: String) {
        Messaging.messaging().subscribe(toTopic: topic)
    }

    func delete() {
        Database.current.deleteSubscription(subscription: self)
        self.unsubscribe(from: self.topic)
    }

    func unsubscribe(from topic: String) {
        Messaging.messaging().unsubscribe(fromTopic: topic)
    }
}
