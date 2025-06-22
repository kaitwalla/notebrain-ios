//
//  ContentView.swift
//  NoteBrain
//
//  Created by Kaitlyn Concilio on 6/18/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var webViewSettings: WebViewSettings
    @EnvironmentObject var configViewModel: InstallationConfigViewModel
    
    // Fetch inbox articles
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Article.createdAt, ascending: false)],
        predicate: NSPredicate(format: "status == %@", "inbox"),
        animation: .default)
    private var inboxArticles: FetchedResults<Article>
    
    // Add a computed property that depends on refreshTrigger to force refresh
    private var refreshedInboxArticles: FetchedResults<Article> {
        _ = refreshTrigger // This forces the view to refresh when refreshTrigger changes
        _ = forceRefresh // This forces the view to refresh when forceRefresh changes
        return inboxArticles
    }
    
    @State private var selectedTab = 0 // 0: Inbox, 1: Archived
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showClearAlert = false
    @State private var showPendingActionsAlert = false
    @State private var pendingActionsCount = 0
    @State private var pendingClearAndRedownload = false
    @State private var summarizePollingTask: Task<Void, Never>? = nil
    @State private var archivedArticles: [Article] = []
    @State private var archivedPage = 1
    @State private var archivedTotalPages = 1
    @State private var isLoadingArchived = false
    @State private var refreshTrigger = UUID() // Add this to force refresh
    @State private var forceRefresh = false // Additional refresh trigger
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    Picker("Tab", selection: $selectedTab) {
                        Text("Inbox").tag(0)
                        Text("Archived").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding([.top, .horizontal])
                    
                    Group {
                        if isLoading || isLoadingArchived {
                            ProgressView("Loading articles...")
                        } else if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                        } else {
                            List {
                                if selectedTab == 0 {
                                    ForEach(refreshedInboxArticles, id: \.id) { article in
                                        NavigationLink(destination: ArticleDetailView(article: article)
                                            .environmentObject(webViewSettings)
                                        ) {
                                            HStack(alignment: .center, spacing: 12) {
                                                if article.starred {
                                                    Image(systemName: "star.fill")
                                                        .foregroundColor(.yellow)
                                                        .font(.system(size: 16, weight: .medium))
                                                }
                                                
                                                VStack(alignment: .leading) {
                                                    Text(article.title ?? "")
                                                        .font(.headline)
                                                    if let author = article.author, !author.isEmpty, let site = article.siteName, !site.isEmpty {
                                                        Text("\(author) · \(site)")
                                                            .font(.caption)
                                                            .foregroundColor(.gray)
                                                    } else if let author = article.author, !author.isEmpty {
                                                        Text(author)
                                                            .font(.caption)
                                                            .foregroundColor(.gray)
                                                    } else if let site = article.siteName, !site.isEmpty {
                                                        Text(site)
                                                            .font(.caption)
                                                            .foregroundColor(.gray)
                                                    }
                                                }
                                                .padding(.vertical, 8)
                                                .padding(.horizontal, 16)
                                                .background(Color(.systemBackground))
                                                .cornerRadius(12)
                                                .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.04), radius: 2, x: 0, y: 1)
                                            }
                                        }
                                        .clipped()
                                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                            Button {
                                                toggleStar(for: article)
                                            } label: {
                                                Label(article.starred ? "Unstar" : "Star", systemImage: article.starred ? "star.slash" : "star")
                                            }
                                            .tint(article.starred ? .gray : .yellow)
                                        }
                                    }
                                } else {
                                    ForEach(filteredArchivedArticles(), id: \.id) { article in
                                        NavigationLink(destination: ArticleDetailView(article: article)
                                            .environmentObject(webViewSettings)
                                        ) {
                                            HStack(alignment: .center, spacing: 12) {
                                                if article.starred {
                                                    Image(systemName: "star.fill")
                                                        .foregroundColor(.yellow)
                                                        .font(.system(size: 16, weight: .medium))
                                                }
                                                
                                                VStack(alignment: .leading) {
                                                    Text(article.title ?? "")
                                                        .font(.headline)
                                                    if let author = article.author, !author.isEmpty, let site = article.siteName, !site.isEmpty {
                                                        Text("\(author) · \(site)")
                                                            .font(.caption)
                                                            .foregroundColor(.gray)
                                                    } else if let author = article.author, !author.isEmpty {
                                                        Text(author)
                                                            .font(.caption)
                                                            .foregroundColor(.gray)
                                                    } else if let site = article.siteName, !site.isEmpty {
                                                        Text(site)
                                                            .font(.caption)
                                                            .foregroundColor(.gray)
                                                    }
                                                }
                                                .padding(.vertical, 8)
                                                .padding(.horizontal, 16)
                                                .background(Color(.systemBackground))
                                                .cornerRadius(12)
                                                .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.04), radius: 2, x: 0, y: 1)
                                            }
                                        }
                                        .clipped()
                                        .onAppear {
                                            if article == filteredArchivedArticles().last {
                                                loadMoreArchivedArticlesIfNeeded()
                                            }
                                        }
                                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                            Button {
                                                toggleStar(for: article)
                                            } label: {
                                                Label(article.starred ? "Unstar" : "Star", systemImage: article.starred ? "star.slash" : "star")
                                            }
                                            .tint(article.starred ? .gray : .yellow)
                                        }
                                    }
                                }
                            }
                            .listStyle(PlainListStyle())
                        }
                    }
                    .navigationTitle(selectedTab == 0 ? "Inbox" : "Archived")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            NavigationLink(destination: SettingsView().environmentObject(webViewSettings)) {
                                Image(systemName: "gear")
                            }
                        }
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: { checkPendingActionsBeforeClear() }) {
                                Image(systemName: "arrow.clockwise")
                            }
                            .help("Clear and Redownload Articles")
                        }
                    }
                }
            }
        }
        .alert("Clear and Redownload Articles?", isPresented: $showClearAlert, actions: {
            Button("Cancel", role: .cancel) {}
            Button("Clear & Redownload", role: .destructive) {
                Task {
                    await clearAndRedownloadArticles()
                }
            }
        }, message: {
            Text("This will delete all current articles and redownload from the server.")
        })
        .alert("Pending Actions Detected", isPresented: $showPendingActionsAlert, actions: {
            Button("Apply Actions and Redownload", role: .destructive) {
                Task {
                    await applyPendingActionsAndRedownload()
                }
            }
            Button("Redownload Without Applying", role: .cancel) {
                Task {
                    await clearAndRedownloadArticles()
                }
            }
        }, message: {
            Text("There are \(pendingActionsCount) pending actions that haven't been synced. Would you like to apply them before redownloading?")
        })
        // Only run loadArticles if not in Xcode Previews
        .modifier(LoadArticlesTaskModifier(isPreview: ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1", loadArticles: loadArticles))
        .onChange(of: selectedTab) {
            if selectedTab == 1 {
                Task { await loadArchivedArticles(reset: true) }
            }
        }
        .onAppear {
            startGlobalSummarizePolling()
            // Force refresh of inbox articles when view appears
            refreshTrigger = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ArticleArchived"))) { _ in
            // Force refresh when an article is archived
            refreshTrigger = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ArticleDeleted"))) { _ in
            // Force refresh when an article is deleted
            
            // Add a small delay to ensure the deletion is processed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Force a context refresh to ensure the fetch request updates
                viewContext.refreshAllObjects()
                
                // Force the fetch request to refresh
                refreshInboxArticles()
                
                refreshTrigger = UUID()
                
                // Toggle force refresh to ensure view updates
                self.forceRefresh.toggle()
                
                // Additional verification
                let fetchRequest: NSFetchRequest<Article> = Article.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "status == %@", "inbox")
                do {
                    let manualFetch = try viewContext.fetch(fetchRequest)
                    
                    // Verify that the fetch request results match the manual fetch
                    if manualFetch.count != self.inboxArticles.count {
                        // Force another refresh
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.viewContext.refreshAllObjects()
                            self.refreshTrigger = UUID()
                            self.forceRefresh.toggle()
                        }
                    }
                } catch {
                    // Handle error silently
                }
            }
        }
        .onDisappear {
            summarizePollingTask?.cancel()
        }
    }
    
    private func loadArticles() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let service = ArticleService(context: viewContext)
            try await service.fetchArticles()
        } catch {
            errorMessage = "Failed to load articles: \(error.localizedDescription)"
        }
    }
    
    private func toggleStar(for article: Article) {
        article.starred.toggle()
        if (article.starred) {
            ArticleActionSyncManager.shared.addAction(articleId: article.id, actionType: "star")
        } else {
            ArticleActionSyncManager.shared.addAction(articleId: article.id, actionType: "unstar")
        }
        try? viewContext.save()
    }
    
    private func checkPendingActionsBeforeClear() {
        let fetchRequest: NSFetchRequest<ArticleAction> = ArticleAction.fetchRequest()
        do {
            let actions = try viewContext.fetch(fetchRequest)
            pendingActionsCount = actions.count
            if actions.count > 0 {
                showPendingActionsAlert = true
            } else {
                showClearAlert = true
            }
        } catch {
            showClearAlert = true
        }
    }
    
    private func clearAndRedownloadArticles() async {
        // Set flag to prevent sync manager interference
        ArticleActionSyncManager.shared.setClearingAndRedownloading(true)
        
        // Cancel the polling task to prevent interference
        summarizePollingTask?.cancel()
        
        // Clear all articles
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Article.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs
        
        do {
            let result = try viewContext.execute(deleteRequest) as? NSBatchDeleteResult
            let objectIDArray = result?.result as? [NSManagedObjectID] ?? []
            let changes = [NSDeletedObjectsKey: objectIDArray]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [viewContext])
            
            try viewContext.save()
            
            // Force a context refresh to ensure deletion is fully committed
            viewContext.refreshAllObjects()
            
            // Add a longer delay to ensure the deletion is fully processed
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Verify that articles are actually deleted
            let verifyRequest: NSFetchRequest<Article> = Article.fetchRequest()
            let remainingArticles = try viewContext.fetch(verifyRequest)
            if !remainingArticles.isEmpty {
                // If articles still exist, try a more aggressive deletion
                for article in remainingArticles {
                    viewContext.delete(article)
                }
                try viewContext.save()
                viewContext.refreshAllObjects()
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            }
        } catch {
            // Handle error silently
        }
        
        // Redownload articles
        await loadArticles()
        
        // Final verification: check for duplicates
        await viewContext.perform {
            let allArticles = (try? viewContext.fetch(Article.fetchRequest())) ?? []
            let articleIds = allArticles.map { $0.id }
            let uniqueIds = Set(articleIds)
            
            if articleIds.count != uniqueIds.count {
                // Remove duplicates by keeping only the first occurrence of each ID
                var seenIds = Set<Int64>()
                var articlesToDelete: [Article] = []
                
                for article in allArticles {
                    if seenIds.contains(article.id) {
                        articlesToDelete.append(article)
                    } else {
                        seenIds.insert(article.id)
                    }
                }
                
                for article in articlesToDelete {
                    viewContext.delete(article)
                }
                
                try? viewContext.save()
            }
        }
        
        // Restart the polling task
        startGlobalSummarizePolling()
        
        // Clear the flag to allow normal sync operations
        ArticleActionSyncManager.shared.setClearingAndRedownloading(false)
    }
    
    private func applyPendingActionsAndRedownload() async {
        // Set flag to prevent sync manager interference
        ArticleActionSyncManager.shared.setClearingAndRedownloading(true)
        
        // Cancel the polling task to prevent interference
        summarizePollingTask?.cancel()
        
        // Apply pending actions first
        ArticleActionSyncManager.shared.triggerSync()
        
        // Add a delay to ensure actions are processed
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Then clear and redownload
        await clearAndRedownloadArticles()
        
        // Clear the flag to allow normal sync operations
        ArticleActionSyncManager.shared.setClearingAndRedownloading(false)
    }
    
    private func startGlobalSummarizePolling() {
        summarizePollingTask?.cancel()
        summarizePollingTask = Task {
            var pollingStartTimes: [Int64: Date] = [:]
            while !Task.isCancelled {
                let summarizeActions = fetchPendingSummarizeActions()
                
                // Only proceed if there are actually pending summarize actions
                if !summarizeActions.isEmpty {
                    let now = Date()
                    for action in summarizeActions {
                        let articleId = action.articleId
                        if pollingStartTimes[articleId] == nil {
                            pollingStartTimes[articleId] = now
                        }
                        // Only poll for up to 1 minute per article
                        if let start = pollingStartTimes[articleId], now.timeIntervalSince(start) > 60 {
                            continue
                        }
                    }
                    
                    // Only fetch articles if we have active polling
                    let activeActions = summarizeActions.filter { action in
                        let start = pollingStartTimes[action.articleId] ?? now
                        return now.timeIntervalSince(start) <= 60
                    }
                    
                    if !activeActions.isEmpty {
                        do {
                            let service = ArticleService(context: viewContext)
                            try await service.fetchArticles()
                        } catch {
                            // Handle error silently
                        }
                    }
                }
                
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            }
        }
    }
    
    private func fetchPendingSummarizeActions() -> [ArticleAction] {
        let fetchRequest: NSFetchRequest<ArticleAction> = ArticleAction.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "actionType == %@", "summarize")
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            return []
        }
    }
    
    private func refreshInboxArticles() {
        // Force the fetch request to refresh
        inboxArticles.nsPredicate = NSPredicate(format: "status == %@", "inbox")
        
        // Force the view to update by invalidating the fetch request
        viewContext.refreshAllObjects()
        
        // Trigger a view update
        DispatchQueue.main.async {
            self.refreshTrigger = UUID()
        }
    }

    private func filteredArchivedArticles() -> [Article] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -configViewModel.archivedRetentionDays, to: Date()) ?? Date.distantPast
        return archivedArticles.filter { article in
            guard let archivedAt = article.archivedAt else { return true }
            return archivedAt >= cutoff
        }
    }

    private func loadArchivedArticles(reset: Bool = false) async {
        if isLoadingArchived { return }
        isLoadingArchived = true
        defer { isLoadingArchived = false }
        if reset {
            archivedArticles = []
            archivedPage = 1
            archivedTotalPages = 1
        }
        let service = ArticleService(context: viewContext)
        do {
            let response = try await service.fetchArchivedArticles(page: archivedPage, pageSize: 20)
            let newArticles = response.data.map { resp -> Article in
                // Upsert logic: fetch by id
                let fetchRequest: NSFetchRequest<Article> = Article.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %lld", resp.id)
                fetchRequest.fetchLimit = 1
                let article: Article
                if let existing = try? viewContext.fetch(fetchRequest).first {
                    article = existing
                } else {
                    article = Article(context: viewContext)
                    article.id = resp.id
                }
                article.userId = resp.userId
                article.url = resp.url
                article.title = resp.title
                article.content = resp.content
                article.excerpt = resp.excerpt
                article.googleDriveFileId = resp.googleDriveFileId
                article.featuredImage = resp.featuredImage
                article.author = resp.author
                article.siteName = resp.siteName
                article.status = resp.status
                article.starred = resp.starred
                article.readAt = resp.readAt
                article.archivedAt = resp.archivedAt
                article.summarizedAt = resp.summarizedAt
                article.summary = resp.summary
                article.createdAt = resp.createdAt
                article.updatedAt = resp.updatedAt
                // Only persist if within retention window
                let cutoff = Calendar.current.date(byAdding: .day, value: -configViewModel.archivedRetentionDays, to: Date()) ?? Date.distantPast
                if let archivedAt = article.archivedAt, archivedAt >= cutoff {
                    try? viewContext.save()
                }
                return article
            }
            archivedArticles.append(contentsOf: newArticles)
            archivedPage = response.currentPage + 1
            archivedTotalPages = response.lastPage
        } catch {
            errorMessage = "Failed to load archived articles: \(error.localizedDescription)"
        }
    }

    private func loadMoreArchivedArticlesIfNeeded() {
        if archivedPage <= archivedTotalPages && !isLoadingArchived {
            Task { await loadArchivedArticles() }
        }
    }
}

// Helper view modifier to conditionally run .task
private struct LoadArticlesTaskModifier: ViewModifier {
    let isPreview: Bool
    let loadArticles: () async -> Void
    func body(content: Content) -> some View {
        if isPreview {
            content
        } else {
            content.task {
                await loadArticles()
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    // Remove existing articles (if any)
    let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Article.fetchRequest()
    let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
    _ = try? context.execute(deleteRequest)
    // Add mock inbox articles
    for i in 1...2 {
        let article = Article(context: context)
        article.title = "Inbox Article \(i)"
        article.excerpt = "This is a preview inbox article."
        article.status = "inbox"
        article.createdAt = Date().addingTimeInterval(Double(-i * 60))
        if i == 1 {
            article.starred = true
            article.summary = "<p>This is a <b>summary</b> for Inbox Article 1.</p>"
        }
    }
    // Add mock archived articles
    for i in 1...2 {
        let article = Article(context: context)
        article.title = "Archived Article \(i)"
        article.excerpt = "This is a preview archived article."
        article.status = "archived"
        article.createdAt = Date().addingTimeInterval(Double(-i * 120))
    }
    try? context.save()
    return ContentView().environment(\.managedObjectContext, context).environmentObject(WebViewSettings()).environmentObject(InstallationConfigViewModel())
}
