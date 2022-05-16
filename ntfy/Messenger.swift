//
//  Messenger.swift
//  ntfy
//
//  Created by Philipp Heckel on 5/15/22.
//

import Foundation
import FirebaseMessaging
import CoreData

struct Messenger {
    var context: NSManagedObjectContext

    func subscribe(toTopic topic: String) {
        Messaging.messaging().subscribe(toTopic: topic)
        
        let subscription = Subscription(context: context)
        subscription.baseUrl = "https://ntfy.sh"
        subscription.topic = topic
        try? context.save()
        
    }
}
