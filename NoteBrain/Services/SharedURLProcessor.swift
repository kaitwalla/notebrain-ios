import Foundation
import CoreData
import os.log

class SharedURLProcessor: ObservableObject {
    static let shared = SharedURLProcessor()
    
    private let logger = Logger(subsystem: "kait.dev.NoteBrain", category: "SharedURLProcessor")
    private let sharedDefaults = UserDefaults(suiteName: "group.kait.dev.NoteBrain.shareextension")
    
    @Published var isProcessing = false
    @Published var lastProcessedCount = 0
    
    private init() {}
    
    func checkForSharedURLs() {
        guard let pendingURLs = sharedDefaults?.array(forKey: "PendingURLs") as? [String],
              !pendingURLs.isEmpty else {
            return
        }
        
        logger.info("Found \(pendingURLs.count) pending URLs to process")
        isProcessing = true
        let context = PersistenceController.shared.container.viewContext
        for url in pendingURLs {
            // Create a new ArticleAction with type 'add' and store the URL in a custom field if possible
            let action = ArticleAction(context: context)
            action.articleId = 0 // Use 0 or -1 as a placeholder since we don't have an Article yet
            action.actionType = "add"
            action.timestamp = Date()
            action.url = url // Set the new url field
            // Store the URL in a custom field if available, or use a convention (e.g., set 'summary' or 'excerpt' to the URL)
            // If ArticleAction has no such field, consider using userInfo or another mechanism
            // For now, let's use 'summary' if it exists
            if action.responds(to: Selector(("setSummary:"))) {
                action.setValue(url, forKey: "summary")
            }
        }
        do {
            try context.save()
        } catch {
            logger.error("Failed to save add actions for shared URLs: \(error.localizedDescription)")
        }
        ArticleActionSyncManager.shared.triggerSync()
        sharedDefaults?.removeObject(forKey: "PendingURLs")
        sharedDefaults?.synchronize()
        lastProcessedCount = pendingURLs.count
        isProcessing = false
    }
    
    // Remove processURLs and processURLsDirectly methods, as they create 'Processing...' items
} 