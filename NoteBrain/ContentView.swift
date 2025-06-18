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
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Article.createdAt, ascending: false)],
        animation: .default)
    private var articles: FetchedResults<Article>
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading articles...")
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                } else {
                    List {
                        ForEach(articles) { article in
                            VStack(alignment: .leading) {
                                Text(article.title ?? "")
                                    .font(.headline)
                                if let excerpt = article.excerpt {
                                    Text(excerpt)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Articles")
        }
        .task {
            await loadArticles()
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
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
