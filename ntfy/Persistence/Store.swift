//
//  DataController.swift
//  ntfy
//
//  Created by Philipp Heckel on 5/14/22.
//

import Foundation
import CoreData

class Store: ObservableObject {
    static let shared = Store()
    
    let tag = "Store"
    let container: NSPersistentContainer
    var context: NSManagedObjectContext
    
    init() {
        let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.io.heckel.ntfy")!
        let storeUrl =  directory.appendingPathComponent("ntfy.sqlite")
        let description =  NSPersistentStoreDescription(url: storeUrl)
        
        container = NSPersistentContainer(name: "Model")
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        context = container.viewContext
    }
    
    func saveSubscription(baseUrl: String, topic: String) {
        let subscription = Subscription(context: context)
        subscription.baseUrl = appBaseUrl
        subscription.topic = topic
        try? context.save()
    }
    
    func getSubscription(baseUrl: String, topic: String) -> Subscription? {
        let fetchRequest = Subscription.fetchRequest()
        let baseUrlPredicate = NSPredicate(format: "baseUrl = %@", baseUrl)
        let topicPredicate = NSPredicate(format: "topic = %@", topic)
        
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [baseUrlPredicate, topicPredicate])
        
        return try? context.fetch(fetchRequest).first
    }
    
    func saveNotification(fromUserInfo userInfo: [AnyHashable: Any]) {
        guard let id = userInfo["id"] as? String,
              let topic = userInfo["topic"] as? String, // FIXME: Notification should also contain baseUrl
              let time = userInfo["time"] as? String,
              let timeInt = Int64(time),
              let message = userInfo["message"] as? String else {
            print("Unknown or irrelevant message", userInfo)
            return
        }
        guard let subscription = getSubscription(baseUrl: appBaseUrl, topic: topic) else {
            print("Subscription for topic \(topic) unknown")
            return
        }
        
        do {
            let notification = Notification(context: context)
            notification.id = id
            notification.time = timeInt
            notification.message = message
            notification.title = userInfo["title"] as? String ?? ""
            subscription.addToNotifications(notification)
            try context.save()
        } catch let error {
            Log.w(tag, "Cannot store notification", error)
            context.rollback()
        }
    }
    
    func saveNotification(fromMessage message: Message, subscription: Subscription) {
        do {
            let notification = Notification(context: context)
            notification.id = message.id
            notification.time = message.time
            notification.message = message.message ?? ""
            notification.title = message.title ?? ""
            subscription.addToNotifications(notification)
            try context.save()
        } catch let error {
            print(error)
            context.rollback()
        }
    }
}
