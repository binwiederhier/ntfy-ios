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
            Log.w(tag, "Failed to fetch items: \(error)", error)
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
    
    var subscriptions: [Subscription] {
        fetchedResultsController.fetchedObjects ?? []
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
