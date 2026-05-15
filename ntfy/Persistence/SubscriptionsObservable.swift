import CoreData
import SwiftUI

class SubscriptionsObservable: NSObject, ObservableObject {
    private let tag = "SubscriptionsObservable"
    
    override init() {
        super.init()
        
        // This will force the initialization of notificationsFetchedResultsController
        _ = self.notificationsFetchedResultsController
    }
    
    private lazy var fetchedResultsController: NSFetchedResultsController<Subscription> = {
        let fetchRequest: NSFetchRequest<Subscription> = Subscription.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "topic", ascending: true)]
        
        let controller = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: Store.shared.context, sectionNameKeyPath: nil, cacheName: nil)
        controller.delegate = self
        
        do {
            Log.d(tag, "Fetching subscriptions")
            try controller.performFetch()
        } catch {
            Log.w(tag, "Failed to fetch subscriptions: \(error)", error)
        }
        
        return controller
    }()
    
    private lazy var notificationsFetchedResultsController: NSFetchedResultsController<Notification> = {
        let fetchRequest: NSFetchRequest<Notification> = Notification.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
        
        let controller = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: Store.shared.context, sectionNameKeyPath: nil, cacheName: nil)
        controller.delegate = self
        
        do {
            Log.d(tag, "Fetching notifications")
            try controller.performFetch()
        } catch {
            Log.w(tag, "Failed to fetch notifications: \(error)", error)
        }
        
        return controller
    }()
    
    func subscriptions(sortOrder: SubscriptionSortOrder) -> [Subscription] {
        let subscriptions = fetchedResultsController.fetchedObjects ?? []
        switch sortOrder {
        case .alphabetical:
            return subscriptions
        case .recentActivity:
            return subscriptions.sorted { first, second in
                if first.lastNotificationTime != second.lastNotificationTime {
                    return first.lastNotificationTime > second.lastNotificationTime
                }
                return alphabeticallyPrecedes(first, second)
            }
        }
    }

    private func alphabeticallyPrecedes(_ first: Subscription, _ second: Subscription) -> Bool {
        let firstTopic = first.topic ?? ""
        let secondTopic = second.topic ?? ""
        let topicComparison = firstTopic.localizedCaseInsensitiveCompare(secondTopic)
        if topicComparison != .orderedSame {
            return topicComparison == .orderedAscending
        }

        let firstBaseUrl = first.baseUrl ?? ""
        let secondBaseUrl = second.baseUrl ?? ""
        return firstBaseUrl.localizedCaseInsensitiveCompare(secondBaseUrl) == .orderedAscending
    }
}

extension SubscriptionsObservable: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        Log.d(tag, "Fetching notifications")
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
}
