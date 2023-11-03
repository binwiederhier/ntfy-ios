import Foundation
import CoreData
import Combine

/// Handles all persistence in the app by storing/loading subscriptions and notifications using Core Data.
/// There are sadly a lot of hacks in here, because I don't quite understand this fully.
class Store: ObservableObject {
    static let shared = Store()
    static let tag = "Store"
    static let appGroup = "group.com.tcaputi.ntfy" // Must match app group of ntfy = ntfyNSE targets
    static let modelName = "ntfy" // Must match .xdatamodeld folder
    static let prefKeyDefaultBaseUrl = "defaultBaseUrl"
    
    private let container: NSPersistentContainer
    var context: NSManagedObjectContext {
        return container.viewContext
    }
    private var cancellables: Set<AnyCancellable> = []

    init(inMemory: Bool = false) {
        let storeUrl = (inMemory) ? URL(fileURLWithPath: "/dev/null") : FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Store.appGroup)!
            .appendingPathComponent("ntfy.sqlite")
        let description = NSPersistentStoreDescription(url: storeUrl)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        // Set up container and observe changes from app extension
        container = NSPersistentContainer(name: Store.modelName)
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
              // TODO: this could probably broadcast the name of the channel
              // so that only relevant views can update.
              Log.d(Store.tag, "Remote change detected, refreshing views", value)

              DispatchQueue.main.async {
                  self.hardRefresh()
              }
          }
          .store(in: &cancellables)
    }
    
    func rollbackAndRefresh() {
        // Hack: We refresh all objects, since failing to store a notification usually means
        // that the app extension stored the notification first. This is a way to update the
        // UI properly when it is in the foreground and the app extension stores a notification.
        
        context.rollback()
        hardRefresh()
    }
    
    func hardRefresh() {
        // `refreshAllObjects` only refreshes objects from which the cache is invalid. With a staleness intervall of -1 the cache never invalidates.
        // We set the `stalenessInterval` to 0 to make sure that changes in the app extension get processed correctly.
        // From: https://www.avanderlee.com/swift/core-data-app-extension-data-sharing/
        
        context.stalenessInterval = 0
        context.refreshAllObjects()
        context.stalenessInterval = -1
    }
    
    // MARK: Subscriptions
    
    func saveSubscription(baseUrl: String, topic: String) -> Subscription {
        let subscription = Subscription(context: context)
        subscription.baseUrl = baseUrl
        subscription.topic = topic
        DispatchQueue.main.sync {
            print("----------> SAVING SUBSCRIPTION \(topic)")
            try? context.save()
        }
        return subscription
    }
    
    func getSubscription(baseUrl: String, topic: String) -> Subscription? {
        let fetchRequest = Subscription.fetchRequest()
        let baseUrlPredicate = NSPredicate(format: "baseUrl = %@", baseUrl)
        let topicPredicate = NSPredicate(format: "topic = %@", topic)
        
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [baseUrlPredicate, topicPredicate])
        
        return try? context.fetch(fetchRequest).first
    }
    
    func getSubscriptions() -> [Subscription]? {
        return try? context.fetch(Subscription.fetchRequest())
    }
    
    func delete(subscription: Subscription) {
        context.delete(subscription)
        try? context.save()
    }
    
    // MARK: Notifications
    
    func save(notificationFromMessage message: Message, withSubscription subscription: Subscription) {
        do {
            let notification = Notification(context: context)
            notification.id = message.id
            notification.time = message.time
            notification.message = message.message ?? ""
            notification.title = message.title ?? ""
            notification.priority = (message.priority != nil && message.priority != 0) ? message.priority! : 3
            notification.tags = message.tags?.joined(separator: ",") ?? ""
            notification.actions = Actions.shared.encode(message.actions)
            notification.click = message.click ?? ""
            notification.subscription = subscription
            subscription.addToNotifications(notification)
            subscription.lastNotificationId = message.id
            print("--------> STORING NOTIFICATION")
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
    
    // MARK: Users
    
    func saveUser(baseUrl: String, username: String, password: String) {
        do {
            let user = getUser(baseUrl: baseUrl) ?? User(context: context)
            user.baseUrl = baseUrl
            user.username = username
            user.password = password
            try context.save()
        } catch let error {
            Log.w(Store.tag, "Cannot store user", error)
            rollbackAndRefresh()
        }
    }
    
    func getUser(baseUrl: String) -> User? {
        let request = User.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "baseUrl = %@", baseUrl)])
        return try? context.fetch(request).first
    }
    
    func delete(user: User) {
        context.delete(user)
        try? context.save()
    }
    
    // MARK: Preferences
    
    func saveDefaultBaseUrl(baseUrl: String?) {
        do {
            let pref = getPreference(key: Store.prefKeyDefaultBaseUrl) ?? Preference(context: context)
            pref.key = Store.prefKeyDefaultBaseUrl
            pref.value = baseUrl ?? Config.appBaseUrl
            try context.save()
        } catch let error {
            Log.w(Store.tag, "Cannot store preference", error)
            rollbackAndRefresh()
        }
    }
    
    func getDefaultBaseUrl() -> String {
        let baseUrl = getPreference(key: Store.prefKeyDefaultBaseUrl)?.value
        if baseUrl == nil || baseUrl?.isEmpty == true {
            return Config.appBaseUrl
        }
        return baseUrl!
    }
    
    private func getPreference(key: String) -> Preference? {
        let request = Preference.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "key = %@", key)])
        return try? context.fetch(request).first
    }
}

extension Store {
    static let sampleMessages = [
        "stats": [
            // TODO: Message with action
            Message(id: "1", time: 1653048956, event: "message", topic: "stats", message: "In the last 24 hours, hyou had 5,000 users across 13 countries visit your website", title: "Record visitor numbers", priority: 4, tags: ["smile", "server123", "de"], actions: nil),
            Message(id: "2", time: 1653058956, event: "message", topic: "stats", message: "201 users/h\n80 IPs", title: "This is a title", priority: 1, tags: [], actions: nil),
            Message(id: "3", time: 1643058956, event: "message", topic: "stats", message: "This message does not have a title, but is instead super long. Like really really long. It can't be any longer I think. I mean, there is s 4,000 byte limit of the message, so I guess I have to make this 4,000 bytes long. Or do I? 😁 I don't know. It's quite tedious to come up with something so long, so I'll stop now. Bye!", title: nil, priority: 5, tags: ["facepalm"], actions: nil)
        ],
        "backups": [],
        "announcements": [],
        "alerts": [],
        "playground": []
    ]
    
    static var preview: Store = {
        let store = Store(inMemory: true)
        store.context.perform {
            // Subscriptions and notifications
            sampleMessages.forEach { topic, messages in
                store.makeSubscription(store.context, topic, messages)
            }
            
            // Users
            store.saveUser(baseUrl: "https://ntfy.sh", username: "testuser", password: "testuser")
            store.saveUser(baseUrl: "https://ntfy.example.com", username: "phil", password: "phil12")
        }
        return store
    }()
    
    static var previewEmpty: Store = {
        return Store(inMemory: true)
    }()
    
    @discardableResult
    func makeSubscription(_ context: NSManagedObjectContext, _ topic: String, _ messages: [Message]) -> Subscription {
        let notifications = messages.map { makeNotification(context, $0) }
        let subscription = Subscription(context: context)
        subscription.baseUrl = Config.appBaseUrl
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
        notification.priority = message.priority ?? 3
        notification.tags = message.tags?.joined(separator: ",") ?? ""
        return notification
    }
}
