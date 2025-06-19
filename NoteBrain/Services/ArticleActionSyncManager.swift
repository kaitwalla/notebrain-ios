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
            await Self.syncActions(context: context)
            // Fetch latest articles after syncing actions
            let articleService = ArticleService(context: context)
            do {
                try await articleService.fetchArticles()
                // Clean up already-applied actions
                await Self.cleanupAppliedActions(context: context)
            } catch {
                print("Failed to fetch articles after sync: \(error)")
            }
            self.isSyncing = false
        }
    }
    
    static func oneTimeSync(context: NSManagedObjectContext) async {
        await syncActions(context: context)
    }
    
    private static func fetchPendingActions(context: NSManagedObjectContext) -> [ArticleAction] {
        let fetchRequest: NSFetchRequest<ArticleAction> = ArticleAction.fetchRequest() as! NSFetchRequest<ArticleAction>
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Failed to fetch ArticleActions: \(error)")
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
            return "/api/articles/\(id)/archive"
        case "delete":
            return "/api/articles/\(id)/delete"
        case "summarize":
            return "/api/articles/\(id)/summarize"
        default:
            return nil
        }
    }
    
    private static func syncActions(context: NSManagedObjectContext) async {
        let apiService = APIService(context: context)
        let actions = fetchPendingActions(context: context)
        let reconciled = reconcileActions(actions)
        for action in reconciled {
            guard let endpoint = endpoint(for: action) else { continue }
            do {
                try await postAction(to: endpoint, apiService: apiService)
            } catch {
                print("Failed to sync action for articleId \(action.articleId): \(error)")
            }
        }
        // Clear all ArticleAction objects after sync
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = ArticleAction.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
            try context.save()
        } catch {
            print("Failed to clear ArticleAction database: \(error)")
        }
    }
    
    private static func postAction(to endpoint: String, apiService: APIService) async throws {
        guard let baseURL = apiService.baseURL,
              let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
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
            print("Failed to save ArticleAction: \(error)")
        }
        if isConnected {
            triggerSync()
        }
    }
    
    // Clean up actions that have already been applied after a refresh
    private static func cleanupAppliedActions(context: NSManagedObjectContext) async {
        let fetchRequest: NSFetchRequest<ArticleAction> = ArticleAction.fetchRequest() as! NSFetchRequest<ArticleAction>
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
            print("Failed to clean up applied actions: \(error)")
        }
    }
} 
