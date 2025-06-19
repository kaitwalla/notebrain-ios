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
    
    // Fetch inbox articles
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Article.createdAt, ascending: false)],
        predicate: NSPredicate(format: "status == %@", "inbox"),
        animation: .default)
    private var inboxArticles: FetchedResults<Article>
    
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
    @State private var archivedRetentionDays: Int = 30
    
    var body: some View {
        NavigationView {
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
                                ForEach(inboxArticles, id: \ .objectID) { article in
                                    ZStack(alignment: .topLeading) {
                                        if article.starred {
                                            ZStack {
                                                Rectangle()
                                                    .fill(Color(.systemGray))
                                                    .frame(width: 55, height: 22)
                                                    .rotationEffect(.degrees(-40))
                                                    .offset(x: -40, y: -20)
                                                Image(systemName: "star.fill")
                                                    .foregroundColor(Color(.systemGray5))
                                                    .font(.system(size: 10))
                                                    .offset(x: -40, y: -15)
                                                    .zIndex(1)
                                            }
                                        }
                                        NavigationLink(destination: ArticleDetailView(article: article)) {
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
                                            .padding(.horizontal, 0)
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
                            } else {
                                ForEach(filteredArchivedArticles(), id: \ .objectID) { article in
                                    ZStack(alignment: .topLeading) {
                                        if article.starred {
                                            ZStack {
                                                Rectangle()
                                                    .fill(Color(.systemGray))
                                                    .frame(width: 55, height: 22)
                                                    .rotationEffect(.degrees(-40))
                                                    .offset(x: -40, y: -20)
                                                Image(systemName: "star.fill")
                                                    .foregroundColor(Color(.systemGray5))
                                                    .font(.system(size: 10))
                                                    .offset(x: -40, y: -15)
                                                    .zIndex(1)
                                            }
                                        }
                                        NavigationLink(destination: ArticleDetailView(article: article)) {
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
                                            .padding(.horizontal, 0)
                                        }
                                    }
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
                    }
                }
                .navigationTitle(selectedTab == 0 ? "Inbox" : "Archived")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: SettingsView(context: viewContext)) {
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
        .onChange(of: selectedTab) { newTab in
            if newTab == 1 {
                Task { await loadArchivedArticles(reset: true) }
            }
        }
        .onAppear {
            startGlobalSummarizePolling()
            loadArchivedRetentionDays()
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
    
    private func clearAndRedownloadArticles() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Article.fetchRequest()
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try viewContext.execute(batchDeleteRequest)
            try viewContext.save()
            viewContext.reset()
            await loadArticles()
        } catch {
            errorMessage = "Failed to clear and redownload articles: \(error.localizedDescription)"
        }
    }

    private func checkPendingActionsBeforeClear() {
        let fetchRequest: NSFetchRequest<ArticleAction> = ArticleAction.fetchRequest() as! NSFetchRequest<ArticleAction>
        fetchRequest.fetchLimit = 1
        do {
            let count = try viewContext.count(for: fetchRequest)
            if count > 0 {
                pendingActionsCount = count
                showPendingActionsAlert = true
            } else {
                showClearAlert = true
            }
        } catch {
            showClearAlert = true
        }
    }

    private func applyPendingActionsAndRedownload() async {
        // Recreate a sync manager for one-off sync
        await ArticleActionSyncManager.oneTimeSync(context: viewContext)
        await clearAndRedownloadArticles()
    }

    private func toggleStar(for article: Article) {
        article.starred.toggle()
        let actionType = article.starred ? "star" : "unstar"
        ArticleActionSyncManager.shared.addAction(articleId: article.id, actionType: actionType)
        try? viewContext.save()
    }

    private func startGlobalSummarizePolling() {
        summarizePollingTask?.cancel()
        summarizePollingTask = Task {
            var pollingStartTimes: [Int64: Date] = [:]
            while !Task.isCancelled {
                let summarizeActions = fetchPendingSummarizeActions()
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
                    // Fetch latest articles
                    let service = ArticleService(context: viewContext)
                    try? await service.fetchArticles()
                    // Check if summary is now present
                    if let article = fetchArticleById(articleId: articleId), let summary = article.summary, !summary.isEmpty {
                        pollingStartTimes.removeValue(forKey: articleId)
                    }
                }
                try? await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
            }
        }
    }

    private func fetchPendingSummarizeActions() -> [ArticleAction] {
        let fetchRequest: NSFetchRequest<ArticleAction> = ArticleAction.fetchRequest() as! NSFetchRequest<ArticleAction>
        fetchRequest.predicate = NSPredicate(format: "actionType == %@", "summarize")
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            return []
        }
    }

    private func fetchArticleById(articleId: Int64) -> Article? {
        let fetchRequest: NSFetchRequest<Article> = Article.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %lld", articleId)
        fetchRequest.fetchLimit = 1
        return (try? viewContext.fetch(fetchRequest))?.first
    }

    private func loadArchivedRetentionDays() {
        let fetchRequest: NSFetchRequest<InstallationConfig> = InstallationConfig.fetchRequest()
        if let config = try? viewContext.fetch(fetchRequest).first,
           let days = config.value(forKey: "archivedRetentionDays") as? Int {
            archivedRetentionDays = days
        } else {
            archivedRetentionDays = 30
        }
    }

    private func filteredArchivedArticles() -> [Article] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -archivedRetentionDays, to: Date()) ?? Date.distantPast
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
                let cutoff = Calendar.current.date(byAdding: .day, value: -archivedRetentionDays, to: Date()) ?? Date.distantPast
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
    return ContentView().environment(\.managedObjectContext, context)
}
