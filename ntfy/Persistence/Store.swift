import Foundation
import CoreData
import Combine

class Store: ObservableObject {
    static let shared = Store()
    static let tag = "Store"
    
    private let container: NSPersistentContainer
    var context: NSManagedObjectContext {
        return container.viewContext
    }
    private var cancellables: Set<AnyCancellable> = []

    init(inMemory: Bool = false) {
        let storeUrl = (inMemory) ? URL(fileURLWithPath: "/dev/null") : FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.io.heckel.ntfy")!
            .appendingPathComponent("ntfy.sqlite")
        let description = NSPersistentStoreDescription(url: storeUrl)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        // Set up container and observe changes from app extension
        container = NSPersistentContainer(name: "ntfy") // See .xdatamodeld folder
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { description, error in
            if let error = error {
                Log.e(Store.tag, "Core Data failed to load: \(error.localizedDescription)", error)
            }
        }
        
        // Shortcut for context
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyStoreTrumpMergePolicyType) // https://stackoverflow.com/a/60362945/1440785
        context.transactionAuthor = Bundle.main.bundlePath.hasSuffix(".appex") ? "ntfy.appex" : "ntfy"
        
        // When a remote change comes in (= the app extension updated entities in Core Data),
        // we force refresh the view with horrible means. Please help me make this better!
        NotificationCenter.default
          .publisher(for: .NSPersistentStoreRemoteChange)
          .sink { value in
              Log.d(Store.tag, "Remote change detected, refreshing view", value)
              
              // Hack: This is the only way I could make the UI update the subscription list.
              // I'm pretty sure I got the @FetchRequest wrong, but I don
              _ = try? self.context.fetch(Subscription.fetchRequest())
              
              DispatchQueue.main.async {
                  self.objectWillChange.send()
                  self.container.viewContext.refreshAllObjects()
              }
          }
          .store(in: &cancellables)
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
    
    func delete(subscription: Subscription) {
        context.delete(subscription)
        try? context.save()
    }
    
    func save(notificationFromUserInfo userInfo: [AnyHashable: Any]) {
        guard let id = userInfo["id"] as? String,
              let topic = userInfo["topic"] as? String,
              let time = userInfo["time"] as? String,
              let timeInt = Int64(time),
              let message = userInfo["message"] as? String else {
            Log.d(Store.tag, "Unknown or irrelevant message", userInfo)
            return
        }
        let baseUrl = appBaseUrl // Firebase messages all come from the main ntfy server
        guard let subscription = getSubscription(baseUrl: baseUrl, topic: topic) else {
            Log.d(Store.tag, "Subscription for topic \(topic) unknown")
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
            Log.w(Store.tag, "Cannot store notification (fromUserInfo)", error)
            rollbackAndRefresh()
        }
    }
    
    func save(notificationFromMessage message: Message, withSubscription subscription: Subscription) {
        do {
            let notification = Notification(context: context)
            notification.id = message.id
            notification.time = message.time
            notification.message = message.message ?? ""
            notification.title = message.title ?? ""
            subscription.addToNotifications(notification)
            try context.save()
        } catch let error {
            Log.w(Store.tag, "Cannot store notification (fromMessage)", error)
            rollbackAndRefresh()
        }
    }
    
    func delete(notification: Notification) {
        Log.d(Store.tag, "Deleting notification \(notification.id ?? "")")
        context.delete(notification)
        try? context.save()
    }
    
    func delete(notifications: Set<Notification>) {
        Log.d(Store.tag, "Deleting \(notifications.count) notification(s)")
        do {
            notifications.forEach { notification in
                context.delete(notification)
            }
            try context.save()
        } catch let error {
            Log.w(Store.tag, "Cannot delete notification(s)", error)
            rollbackAndRefresh()
        }
    }
    
    func delete(allNotificationsFor subscription: Subscription) {
        guard let notifications = subscription.notifications else { return }
        Log.d(Store.tag, "Deleting all \(notifications.count) notification(s) for subscription \(subscription.urlString())")
        do {
            notifications.forEach { notification in
                context.delete(notification as! Notification)
            }
            try context.save()
        } catch let error {
            Log.w(Store.tag, "Cannot delete notification(s)", error)
            rollbackAndRefresh()
        }
    }
    
    func rollbackAndRefresh() {
        // Hack: We refresh all objects, since failing to store a notification usually means
        // that the app extension stored the notification first. This is a way to update the
        // UI properly when it is in the foreground and the app extension stores a notification.
        
        context.rollback()
        context.refreshAllObjects()
    }
}


extension Store {
    static let sampleData = [
        "stats": [
            Message(id: "1", time: 1653048956, message: "In the last 24 hours, hyou had 5,000 users across 13 countries visit your website", title: "Record visitor numbers"),
            Message(id: "2", time: 1653058956, message: "201 users/h\n80 IPs", title: "This is a title"),
            Message(id: "3", time: 1643058956, message: "This message does not have a title, but is instead super long. Like really really long. It can't be any longer I think. I mean, there is s 4,000 byte limit of the message, so I guess I have to make this 4,000 bytes long. Or do I? 😁 I don't know. It's quite tedious to come up with something so long, so I'll stop now. Bye!", title: nil)

        ],
        "backups": [],
        "announcements": [],
        "alerts": [],
        "plaground": []
    ]
    
    static var preview: Store = {
        let store = Store(inMemory: true)
        store.context.perform {
            sampleData.forEach { topic, messages in
                store.makeSubscription(store.context, topic, messages)
            }
        }
        return store
    }()
    
    @discardableResult
    func makeSubscription(_ context: NSManagedObjectContext, _ topic: String, _ messages: [Message]) -> Subscription {
        let notifications = messages.map { makeNotification(context, $0) }
        let subscription = Subscription(context: context)
        subscription.baseUrl = appBaseUrl
        subscription.topic = topic
        subscription.notifications = NSSet(array: notifications)
        return subscription
    }
    
    @discardableResult
    func makeNotification(_ context: NSManagedObjectContext, _ message: Message) -> Notification {
        let notification = Notification(context: context)
        notification.id = message.id
        notification.time = message.time
        notification.message = message.message
        notification.title = message.title
        return notification
    }
}
