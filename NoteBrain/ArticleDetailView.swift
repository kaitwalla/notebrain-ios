import SwiftUI
import CoreData

struct ArticleDetailView: View {
    let article: Article
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var isStarred: Bool
    @State private var selectedTab: Int = 0 // 0: Summary, 1: Full Article
    @State private var isSummarizing: Bool = false
    
    // Observe pending summarize actions for this article (only in non-preview mode)
    @FetchRequest private var pendingSummarizeActions: FetchedResults<ArticleAction>
    
    @EnvironmentObject var webViewSettings: WebViewSettings
    
    init(article: Article) {
        self.article = article
        _isStarred = State(initialValue: article.starred)
        
        // Only setup fetch request if not in preview mode
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            // Create a dummy fetch request for preview mode
            _pendingSummarizeActions = FetchRequest<ArticleAction>(
                sortDescriptors: [],
                predicate: NSPredicate(format: "FALSEPREDICATE"),
                animation: .default
            )
        } else {
            // Setup fetch request for pending summarize actions
            let predicate = NSPredicate(format: "articleId == %lld AND actionType == %@", article.id, "summarize")
            _pendingSummarizeActions = FetchRequest<ArticleAction>(
                sortDescriptors: [],
                predicate: predicate,
                animation: .default
            )
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(article.title ?? "")
                .font(.title)
                .padding([.top, .horizontal])
            Divider()
            if let summary = article.summary, !summary.isEmpty {
                Picker("View", selection: $selectedTab) {
                    Text("Summary").tag(0)
                    Text("Full Article").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding([.horizontal, .bottom])
                if selectedTab == 0 {
                    WebView(htmlContent: summary)
                        .environmentObject(webViewSettings)
                        .frame(maxWidth: .infinity, minHeight: 400)
                } else {
                    WebView(htmlContent: article.content ?? "")
                        .environmentObject(webViewSettings)
                        .frame(maxWidth: .infinity, minHeight: 400)
                }
            } else {
                WebView(htmlContent: article.content ?? "")
                    .environmentObject(webViewSettings)
                    .frame(maxWidth: .infinity, minHeight: 400)
            }
            Divider()
            HStack {
                Button(action: toggleStar) {
                    Image(systemName: isStarred ? "star.fill" : "star")
                        .foregroundColor(isStarred ? .yellow : .gray)
                    
                }
                .padding()
                Spacer()
                Button(action: archiveArticle) {
                    Image(systemName: "archivebox")
                        .foregroundColor(.blue)
                }
                .padding()
                Button(action: deleteArticle) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .padding()
                if shouldShowSummarizeButton {
                    Button(action: requestSummarize) {
                        HStack {
                            if isSummarizing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Image(systemName: "text.alignleft")
                        }
                    }
                    .disabled(isSummarizing)
                    .padding()
                }
            }
            .background(Color(.secondarySystemBackground))
        }
        .navigationTitle("Article")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func toggleStar() {
        isStarred.toggle()
        article.starred = isStarred
        if (isStarred) {
            ArticleActionSyncManager.shared.addAction(articleId: article.id, actionType: "star")
        } else {
            ArticleActionSyncManager.shared.addAction(articleId: article.id, actionType: "unstar")
        }
        try? viewContext.save()
    }
    
    private func deleteArticle() {
        ArticleActionSyncManager.shared.addAction(articleId: article.id, actionType: "delete")
        
        // Ensure we're on the main thread for Core Data operations
        DispatchQueue.main.async {
            self.viewContext.delete(self.article)
            
            do {
                try self.viewContext.save()
                
                // Post notification to refresh ContentView
                NotificationCenter.default.post(name: NSNotification.Name("ArticleDeleted"), object: nil)
            } catch {
                // Try to refresh the context and save again
                self.viewContext.refreshAllObjects()
                do {
                    try self.viewContext.save()
                    NotificationCenter.default.post(name: NSNotification.Name("ArticleDeleted"), object: nil)
                } catch {
                    // Handle error silently
                }
            }
        }
        
        dismiss()
    }
    
    private func archiveArticle() {
        article.status = "archived"
        article.archivedAt = Date()
        
        ArticleActionSyncManager.shared.addAction(articleId: article.id, actionType: "archive")
        
        do {
            try viewContext.save()
            
            // Post notification to refresh ContentView
            NotificationCenter.default.post(name: NSNotification.Name("ArticleArchived"), object: nil)
        } catch {
            // Handle error silently
        }
        
        dismiss()
    }
    
    private func requestSummarize() {
        isSummarizing = true
        
        ArticleActionSyncManager.shared.addAction(articleId: article.id, actionType: "summarize")
        
        // Save the article changes to the view context
        do {
            try viewContext.save()
        } catch {
            // Handle error silently
        }
        
        // Reset loading state after a short delay to show the action was processed
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isSummarizing = false
        }
    }
    
    private func logAction(type: String) {
        ArticleActionSyncManager.shared.addAction(articleId: article.id, actionType: type)
    }
    
    // Computed property to determine if the summarize button should be shown
    private var shouldShowSummarizeButton: Bool {
        // Hide if summary exists and is not empty
        if let summary = article.summary, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        
        // For preview mode, always show the button
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return true
        }
        
        // Hide if a pending summarize action exists
        return pendingSummarizeActions.isEmpty
    }
}

#Preview {
    // Create a simple mock article for preview without complex Core Data setup
    let context = PersistenceController.preview.container.viewContext
    
    // Create a mock article
    let article = Article(context: context)
    article.title = "Sample Article Title"
    article.content = """
    <h1>Sample Article</h1>
    <p>This is a sample article content for preview purposes. It contains some HTML formatting to test the WebView rendering.</p>
    <h2>Subsection</h2>
    <p>Here's another paragraph with <strong>bold text</strong> and <em>italic text</em>.</p>
    <ul>
        <li>First bullet point</li>
        <li>Second bullet point</li>
        <li>Third bullet point</li>
    </ul>
    """
    article.summary = "<p>This is a <strong>summary</strong> of the article with some <em>formatted text</em>.</p>"
    article.starred = true
    article.id = 123
    article.author = "John Doe"
    article.siteName = "Sample Site"
    
    return NavigationView {
        ArticleDetailView(article: article)
            .environment(\.managedObjectContext, context)
            .environmentObject(WebViewSettings())
    }
} 
