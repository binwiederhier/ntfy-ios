import CoreData
import SwiftUI

class SubscriptionsObservable: NSObject, ObservableObject {
    
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
            try controller.performFetch()
        } catch {
            print("Failed to fetch items: \(error)")
        }
        
        return controller
    }()
    
    private lazy var notificationsFetchedResultsController: NSFetchedResultsController<Notification> = {
        let fetchRequest: NSFetchRequest<Notification> = Notification.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
        
        let controller = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: Store.shared.context, sectionNameKeyPath: nil, cacheName: nil)
        controller.delegate = self
        
        do {
            try controller.performFetch()
        } catch {
            print("Failed to fetch notifications: \(error)")
        }
        
        return controller
    }()
    
    var subscriptions: [Subscription] {
        fetchedResultsController.fetchedObjects ?? []
    }
}

extension SubscriptionsObservable: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
}
