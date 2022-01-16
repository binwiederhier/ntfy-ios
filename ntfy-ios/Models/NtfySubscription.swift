//
//  Subscription.swift
//  ntfy.sh
//
//  Created by Andrew Cope on 1/15/22.
//

import Foundation

class NtfySubscription {
    
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
}
