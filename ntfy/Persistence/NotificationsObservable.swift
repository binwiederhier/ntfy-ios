import CoreData
import SwiftUI

class NotificationsObservable: NSObject, ObservableObject {
    private let tag = "NotificationsObservable"
    private var subscriptionID: NSManagedObjectID
    
    private lazy var fetchedResultsController: NSFetchedResultsController<Notification> = {
        let fetchRequest: NSFetchRequest<Notification> = Notification.fetchRequest()
        
        // Filter by the desired subscription
        fetchRequest.predicate = NSPredicate(format: "subscription == %@", subscriptionID)
        
        // Sort descriptors if you need them
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "time", ascending: false)] // Assuming you have a 'date' attribute on the NotificationEntity
        
        let controller = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: Store.shared.context, sectionNameKeyPath: nil, cacheName: nil)
        controller.delegate = self
        return controller
    }()
    
    @Published var notifications: [Notification] = []
    
    init(subscriptionID: NSManagedObjectID) {
        self.subscriptionID = subscriptionID
        super.init()
        
        do {
            Log.d(tag, "Fetching notifications")
            try self.fetchedResultsController.performFetch()
            self.notifications = self.fetchedResultsController.fetchedObjects ?? []
        } catch {
            Log.w(tag, "Failed to fetch notifications \(error)")
        }
    }
}

extension NotificationsObservable: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        DispatchQueue.main.async {
            self.notifications = self.fetchedResultsController.fetchedObjects ?? []
        }
    }
}
