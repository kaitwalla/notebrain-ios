import Foundation
import CoreData

class ArticleService {
    private let apiService: APIService
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
        self.apiService = APIService(context: context)
    }
    
    func fetchArticles() async throws {
        let articles: [ArticleResponse] = try await apiService.fetch("/api/articles")
        
        // Save to Core Data
        await context.perform {
            for articleResponse in articles {
                let article = Article(context: self.context)
                article.id = articleResponse.id
                article.userId = articleResponse.userId
                article.url = articleResponse.url
                article.title = articleResponse.title
                article.content = articleResponse.content
                article.excerpt = articleResponse.excerpt
                article.googleDriveFileId = articleResponse.googleDriveFileId
                article.featuredImage = articleResponse.featuredImage
                article.author = articleResponse.author
                article.siteName = articleResponse.siteName
                article.status = articleResponse.status
                article.starred = articleResponse.starred
                article.readAt = articleResponse.readAt
                article.archivedAt = articleResponse.archivedAt
                article.summarizedAt = articleResponse.summarizedAt
                article.summary = articleResponse.summary
                article.createdAt = articleResponse.createdAt
                article.updatedAt = articleResponse.updatedAt
            }
            
            try? self.context.save()
        }
    }
}

// Response model for decoding JSON
private struct ArticleResponse: Codable {
    let id: Int64
    let userId: Int64
    let url: String
    let title: String
    let content: String
    let excerpt: String?
    let googleDriveFileId: String?
    let featuredImage: String?
    let author: String?
    let siteName: String?
    let status: String
    let starred: Bool
    let readAt: Date?
    let archivedAt: Date?
    let summarizedAt: Date?
    let summary: String?
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case url
        case title
        case content
        case excerpt
        case googleDriveFileId = "google_drive_file_id"
        case featuredImage = "featured_image"
        case author
        case siteName = "site_name"
        case status
        case starred
        case readAt = "read_at"
        case archivedAt = "archived_at"
        case summarizedAt = "summarized_at"
        case summary
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int64.self, forKey: .id)
        userId = try container.decode(Int64.self, forKey: .userId)
        url = try container.decode(String.self, forKey: .url)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        excerpt = try container.decodeIfPresent(String.self, forKey: .excerpt)
        googleDriveFileId = try container.decodeIfPresent(String.self, forKey: .googleDriveFileId)
        featuredImage = try container.decodeIfPresent(String.self, forKey: .featuredImage)
        author = try container.decodeIfPresent(String.self, forKey: .author)
        siteName = try container.decodeIfPresent(String.self, forKey: .siteName)
        status = try container.decode(String.self, forKey: .status)
        starred = try container.decode(Bool.self, forKey: .starred)
        
        // Handle date fields with custom decoding
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let readAtString = try container.decodeIfPresent(String.self, forKey: .readAt) {
            readAt = dateFormatter.date(from: readAtString)
        } else {
            readAt = nil
        }
        
        if let archivedAtString = try container.decodeIfPresent(String.self, forKey: .archivedAt) {
            archivedAt = dateFormatter.date(from: archivedAtString)
        } else {
            archivedAt = nil
        }
        
        if let summarizedAtString = try container.decodeIfPresent(String.self, forKey: .summarizedAt) {
            summarizedAt = dateFormatter.date(from: summarizedAtString)
        } else {
            summarizedAt = nil
        }
        
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        
        if let createdAtString = try container.decodeIfPresent(String.self, forKey: .createdAt) {
            createdAt = dateFormatter.date(from: createdAtString)
        } else {
            createdAt = nil
        }
        
        if let updatedAtString = try container.decodeIfPresent(String.self, forKey: .updatedAt) {
            updatedAt = dateFormatter.date(from: updatedAtString)
        } else {
            updatedAt = nil
        }
    }
} 