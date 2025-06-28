//
//  Persistence.swift
//  NoteBrain
//
//  Created by Kaitlyn Concilio on 6/18/25.
//

import CoreData
import CloudKit
import os.log

struct PersistenceController {
    static let shared = PersistenceController()
    private let logger = Logger(subsystem: "kait.dev.NoteBrain", category: "Persistence")

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        let logger = Logger(subsystem: "kait.dev.NoteBrain", category: "Persistence")
        
        for _ in 0..<10 {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()
        }
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            logger.error("Preview context save failed: \(nsError.localizedDescription)")
            // Don't crash, just log the error
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "NoteBrain")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Configure the persistent store with CloudKit sync
        if let storeDescription = container.persistentStoreDescriptions.first {
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            
            // Enable CloudKit sync
            storeDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.kait.dev.NoteBrain.settings"
            )
        }
        
        // Add some debugging for the context before setting up the closure
        print("Core Data context configured: concurrencyType=\(container.viewContext.concurrencyType.rawValue)")
        
        // Capture logger before the closure to avoid capturing self
        let logger = self.logger
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                logger.error("Core Data store loading failed: \(error.localizedDescription)")
                // Don't crash, just log the error and continue
                // The app can still function with limited features
            } else {
                logger.info("Core Data store loaded successfully with CloudKit sync")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
