import SwiftUI
import CoreData

struct ArticleDetailView: View {
    let article: Article
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var isStarred: Bool
    @State private var selectedTab: Int = 0 // 0: Summary, 1: Full Article
    
    // Observe pending summarize actions for this article
    @FetchRequest private var pendingSummarizeActions: FetchedResults<ArticleAction>
    
    init(article: Article) {
        self.article = article
        _isStarred = State(initialValue: article.starred)
        // Setup fetch request for pending summarize actions
        let predicate = NSPredicate(format: "articleId == %lld AND actionType == %@", article.id, "summarize")
        _pendingSummarizeActions = FetchRequest<ArticleAction>(
            sortDescriptors: [],
            predicate: predicate,
            animation: .default
        )
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
                        .edgesIgnoringSafeArea(.bottom)
                } else {
                    WebView(htmlContent: article.content ?? "")
                        .edgesIgnoringSafeArea(.bottom)
                }
            } else {
                WebView(htmlContent: article.content ?? "")
                    .edgesIgnoringSafeArea(.bottom)
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
                }
                .padding()
                Button(action: deleteArticle) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .padding()
                if shouldShowSummarizeButton {
                    Button(action: requestSummarize) {
                        Image(systemName: "text.alignleft")
                    }
                    .padding()
                }
            }
            .background(Color(.systemGray6))
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
        viewContext.delete(article)
        try? viewContext.save()
        dismiss()
    }
    
    private func archiveArticle() {
        article.status = "archived"
        article.archivedAt = Date()
        ArticleActionSyncManager.shared.addAction(articleId: article.id, actionType: "archive")
        try? viewContext.save()
        dismiss()
    }
    
    private func requestSummarize() {
        ArticleActionSyncManager.shared.addAction(articleId: article.id, actionType: "summarize")
        try? viewContext.save()
    }
    
    private func logAction(type: String) {
        ArticleActionSyncManager.shared.addAction(articleId: article.id, actionType: type)
    }
    
    // Computed property to determine if the summarize button should be shown
    private var shouldShowSummarizeButton: Bool {
        // Hide if summary exists
        if let summary = article.summary, !summary.isEmpty {
            return false
        }
        // Hide if a pending summarize action exists (reactive)
        return pendingSummarizeActions.isEmpty
    }
}

#Preview {
    // Provide a mock Article for preview
    let context = PersistenceController.preview.container.viewContext
    let article = Article(context: context)
    article.title = "Sample Article"
    article.content = "<h1>Hello World</h1><p>This is a test article.</p>"
    article.summary = "<p>This is a <b>summary</b> of the article.</p>"
    article.starred = false
    return ArticleDetailView(article: article).environment(\.managedObjectContext, context)
} 
