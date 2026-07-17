import CoreData
import SwiftUI

class AllNotificationsObservable: NSObject, ObservableObject {
    private let tag = "AllNotificationsObservable"

    private lazy var fetchedResultsController: NSFetchedResultsController<Notification> = {
        let fetchRequest: NSFetchRequest<Notification> = Notification.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "time", ascending: false)]

        let controller = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: Store.shared.context, sectionNameKeyPath: nil, cacheName: nil)
        controller.delegate = self
        return controller
    }()

    @Published var notifications: [Notification] = []

    override init() {
        super.init()

        do {
            Log.d(tag, "Fetching all notifications")
            try self.fetchedResultsController.performFetch()
            self.notifications = self.fetchedResultsController.fetchedObjects ?? []
        } catch {
            Log.w(tag, "Failed to fetch all notifications \(error)")
        }
    }
}

extension AllNotificationsObservable: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        let fetched = self.fetchedResultsController.fetchedObjects ?? []
        let unread = fetched.filter { !$0.isRead }.count
        Log.d(tag, "Content changed, count=\(fetched.count), unread=\(unread)")
        DispatchQueue.main.async {
            withAnimation {
                self.notifications = fetched
            }
        }
    }
}
