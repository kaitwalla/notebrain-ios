import Foundation
import CoreData

class APIService {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    var baseURL: String? {
        guard let config = try? context.fetch(InstallationConfig.fetchRequest()).first,
              let baseURL = config.installationURL else {
            return nil
        }
        return baseURL
    }
    
    var apiToken: String? {
        guard let config = try? context.fetch(InstallationConfig.fetchRequest()).first,
              let token = config.apiToken as? String else {
            return nil
        }
        return token
    }
    
    func fetch<T: Decodable>(_ endpoint: String) async throws -> T {
        guard let baseURL = baseURL,
              let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        print(url)
        print(apiToken)
        if let token = apiToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(T.self, from: data)
    }
} 
