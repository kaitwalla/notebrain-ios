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
        processURLs(pendingURLs)
    }
    
    private func processURLs(_ urls: [String]) {
        guard !urls.isEmpty else { return }
        
        isProcessing = true
        
        Task {
            let context = PersistenceController.shared.container.viewContext
            var processedCount = 0
            var failedCount = 0
            
            for urlString in urls {
                logger.info("Processing URL: \(urlString)")
                
                // Add the URL to the action queue by creating a temporary article
                await context.perform {
                    let article = Article(context: context)
                    article.url = urlString
                    article.title = "Processing..."
                    article.content = ""
                    article.status = "inbox"
                    article.starred = false
                    article.createdAt = Date()
                    article.updatedAt = Date()
                    
                    // Generate a temporary ID (will be replaced when synced)
                    article.id = Int64(Date().timeIntervalSince1970 * 1000)
                    
                    try? context.save()
                    
                    // Add to action queue for sync
                    ArticleActionSyncManager.shared.addAction(articleId: article.id, actionType: "add")
                }
                
                processedCount += 1
                logger.info("Successfully queued URL: \(urlString)")
            }
            
            // Clear the processed URLs from shared UserDefaults
            sharedDefaults?.removeObject(forKey: "PendingURLs")
            sharedDefaults?.synchronize()
            
            // Capture final values before entering MainActor
            let finalProcessedCount = processedCount
            let finalFailedCount = failedCount
            
            await MainActor.run {
                self.isProcessing = false
                self.lastProcessedCount = finalProcessedCount
                
                if finalFailedCount > 0 {
                    self.logger.warning("Failed to process \(finalFailedCount) URLs")
                }
                
                self.logger.info("Completed processing \(finalProcessedCount) URLs")
            }
        }
    }
    
    func processURLsDirectly(_ urls: [String]) async {
        guard !urls.isEmpty else { return }
        
        await MainActor.run {
            isProcessing = true
        }
        
        let context = PersistenceController.shared.container.viewContext
        var processedCount = 0
        let failedCount = 0 // Changed to let since it's never mutated
        
        for urlString in urls {
            logger.info("Processing URL directly: \(urlString)")
            
            // Create a temporary article and add to action queue
            await context.perform {
                let article = Article(context: context)
                article.url = urlString
                article.title = "Processing..."
                article.content = ""
                article.status = "inbox"
                article.starred = false
                article.createdAt = Date()
                article.updatedAt = Date()
                
                // Generate a temporary ID (will be replaced when synced)
                article.id = Int64(Date().timeIntervalSince1970 * 1000)
                
                try? context.save()
                
                // Add to action queue for sync
                ArticleActionSyncManager.shared.addAction(articleId: article.id, actionType: "add")
            }
            
            processedCount += 1
            logger.info("Successfully queued URL: \(urlString)")
        }
        
        // Capture final values before entering MainActor
        let finalProcessedCount = processedCount
        let finalFailedCount = failedCount
        
        await MainActor.run {
            isProcessing = false
            lastProcessedCount = finalProcessedCount
            
            if finalFailedCount > 0 {
                logger.warning("Failed to process \(finalFailedCount) URLs")
            }
            
            logger.info("Completed processing \(finalProcessedCount) URLs")
        }
    }
} 