import Foundation
import CoreData
import Network

class ArticleActionSyncManager {
    static let shared = ArticleActionSyncManager()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ArticleActionSyncMonitor")
    private var isConnected: Bool = false
    private var isSyncing: Bool = false
    private var context: NSManagedObjectContext {
        PersistenceController.shared.container.viewContext
    }
    private let apiService = APIService(context: PersistenceController.shared.container.viewContext)
    private var syncTimer: Timer?
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let wasConnected = self?.isConnected ?? false
            self?.isConnected = path.status == .satisfied
            if self?.isConnected == true && wasConnected == false {
                self?.triggerSync()
            }
        }
        monitor.start(queue: queue)
        // Start periodic sync timer (every 2 minutes)
        syncTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            guard let self = self, self.isConnected else { return }
            self.triggerSync()
        }
    }
    
    deinit {
        syncTimer?.invalidate()
    }
    
    func triggerSync() {
        guard !isSyncing else { return }
        isSyncing = true
        Task {
            // Check what types of actions we have before syncing
            let actions = Self.fetchPendingActions(context: context)
            let hasNonSummarizeActions = actions.contains { $0.actionType != "summarize" }
            
            await Self.syncActions(context: context)
            
            // Only fetch articles if there were actions that might have changed article state
            // For summarize actions, we'll let the polling mechanism handle updates
            if hasNonSummarizeActions {
                let articleService = ArticleService(context: context)
                do {
                    try await articleService.fetchArticles()
                } catch {
                    // Handle error silently
                }
            }
            // Clean up already-applied actions
            await Self.cleanupAppliedActions(context: context)
            self.isSyncing = false
        }
    }
    
    static func oneTimeSync(context: NSManagedObjectContext) async {
        await syncActions(context: context)
    }
    
    private static func fetchPendingActions(context: NSManagedObjectContext) -> [ArticleAction] {
        let fetchRequest: NSFetchRequest<ArticleAction> = ArticleAction.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        do {
            return try context.fetch(fetchRequest)
        } catch {
            return []
        }
    }
    
    private static func reconcileActions(_ actions: [ArticleAction]) -> [ArticleAction] {
        var latestActionByArticle: [Int64: ArticleAction] = [:]
        for action in actions {
            latestActionByArticle[action.articleId] = action
        }
        return Array(latestActionByArticle.values)
    }
    
    private static func endpoint(for action: ArticleAction) -> String? {
        let id = action.articleId
        switch action.actionType {
        case "star":
            return "/api/articles/\(id)/star"
        case "unstar":
            return "/api/articles/\(id)/unstar"
        case "archive":
            return "/api/articles/\(id)/read"
        case "delete":
            return "/api/articles/\(id)"
        case "summarize":
            return "/api/articles/\(id)/summarize"
        default:
            return nil
        }
    }
    
    private static func httpMethod(for action: ArticleAction) -> String {
        switch action.actionType {
        case "delete":
            return "DELETE"
        default:
            return "POST"
        }
    }
    
    private static func syncActions(context: NSManagedObjectContext) async {
        let apiService = APIService(context: context)
        let actions = fetchPendingActions(context: context)
        let reconciled = reconcileActions(actions)
        for action in reconciled {
            guard let endpoint = endpoint(for: action) else { continue }
            do {
                try await postAction(to: endpoint, action: action, apiService: apiService)
            } catch {
                // Handle error silently
            }
        }
        // Clear all ArticleAction objects after sync
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = ArticleAction.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
            try context.save()
        } catch {
            // Handle error silently
        }
    }
    
    private static func postAction(to endpoint: String, action: ArticleAction, apiService: APIService) async throws {
        guard let baseURL = apiService.baseURL,
              let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod(for: action)
        
        if let token = apiService.apiToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
    
    // Add a new action and trigger sync if connected
    func addAction(articleId: Int64, actionType: String) {
        let action = ArticleAction(context: context)
        action.articleId = articleId
        action.actionType = actionType
        action.timestamp = Date()
        do {
            try context.save()
        } catch {
            // Handle error silently
        }
        // Only trigger sync if device is connected
        if isConnected {
            triggerSync()
        } else {
            triggerSync()
        }
    }
    
    // Clean up actions that have already been applied after a refresh
    private static func cleanupAppliedActions(context: NSManagedObjectContext) async {
        let fetchRequest: NSFetchRequest<ArticleAction> = ArticleAction.fetchRequest()
        do {
            let actions = try context.fetch(fetchRequest)
            for action in actions {
                let articleFetch: NSFetchRequest<Article> = Article.fetchRequest()
                articleFetch.predicate = NSPredicate(format: "id == %lld", action.articleId)
                articleFetch.fetchLimit = 1
                let article = try context.fetch(articleFetch).first
                switch action.actionType {
                case "summarize":
                    if let article = article, let summary = article.summary, !summary.isEmpty {
                        context.delete(action)
                    }
                case "archive", "delete":
                    if article == nil {
                        context.delete(action)
                    }
                case "star":
                    if let article = article, article.starred == true {
                        context.delete(action)
                    }
                case "unstar":
                    if let article = article, article.starred == false {
                        context.delete(action)
                    }
                default:
                    break
                }
            }
            try context.save()
        } catch {
            // Handle error silently
        }
    }
} 
