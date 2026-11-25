import CoreData
import Foundation
import Testing
@testable import ntfy

/// Existing users have stores written with older model versions. If one fails to load, Store only logs it and the
/// app runs with no data, so every shipped version must migrate to the current one.
struct ModelMigrationTests {
    /// Loaded once and stripped of its subclasses before any store uses it: a second model claiming Subscription etc.
    /// would confuse Store's entity lookups. The current version is always Store.model, never a second load.
    private static let firstVersion: NSManagedObjectModel? = {
        guard let url = Bundle(for: Store.self).url(forResource: Store.modelName, withExtension: "momd")?
            .appendingPathComponent("Model.mom"),
              let model = NSManagedObjectModel(contentsOf: url) else {
            return nil
        }
        for entity in model.entities {
            entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        }
        return model
    }()

    private func openStore(at url: URL, model: NSManagedObjectModel) throws -> NSPersistentContainer {
        let container = NSPersistentContainer(name: Store.modelName, managedObjectModel: model)
        container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: url)]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError {
            throw loadError
        }
        return container
    }

    @Test func firstVersionHasNoDisplayName() throws {
        let first = try #require(Self.firstVersion)
        #expect(first.entitiesByName["Subscription"]?.attributesByName["customDisplayName"] == nil)
    }

    @Test func currentVersionHasDisplayName() {
        #expect(Store.model.entitiesByName["Subscription"]?.attributesByName["customDisplayName"] != nil)
    }

    /// Runs the same inferred (lightweight) migration the app relies on, with the source model passed in explicitly.
    /// Automatic migration would load Model.mom from the bundle, briefly confusing entity lookups in parallel tests.
    @Test func storeFromFirstVersionMigratesToCurrent() throws {
        let first = try #require(Self.firstVersion)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let oldUrl = directory.appendingPathComponent("old.sqlite")
        let migratedUrl = directory.appendingPathComponent("migrated.sqlite")

        let old = try openStore(at: oldUrl, model: first)
        let subscription = NSEntityDescription.insertNewObject(forEntityName: "Subscription", into: old.viewContext)
        subscription.setValue("https://ntfy.sh", forKey: "baseUrl")
        subscription.setValue("garage", forKey: "topic")
        try old.viewContext.save()
        for store in old.persistentStoreCoordinator.persistentStores {
            try old.persistentStoreCoordinator.remove(store)
        }

        let mapping = try NSMappingModel.inferredMappingModel(forSourceModel: first, destinationModel: Store.model)
        try NSMigrationManager(sourceModel: first, destinationModel: Store.model).migrateStore(
            from: oldUrl, sourceType: NSSQLiteStoreType, options: nil, with: mapping,
            toDestinationURL: migratedUrl, destinationType: NSSQLiteStoreType, destinationOptions: nil
        )

        let migrated = try openStore(at: migratedUrl, model: Store.model)
        let rows = try migrated.viewContext.fetch(NSFetchRequest<NSManagedObject>(entityName: "Subscription"))
        #expect(rows.count == 1)
        #expect(rows.first?.value(forKey: "topic") as? String == "garage")
        #expect(rows.first?.value(forKey: "customDisplayName") == nil)
    }
}
