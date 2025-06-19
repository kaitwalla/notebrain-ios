import Foundation
import CoreData

class InstallationConfigViewModel: ObservableObject {
    @Published var installationURL: String = ""
    @Published var apiToken: String = ""
    @Published var isConfigured: Bool = false
    @Published var archivedRetentionDays: Int = 30
    
    private let viewContext: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
        loadConfiguration()
    }
    
    func loadConfiguration() {
        let fetchRequest: NSFetchRequest<InstallationConfig> = InstallationConfig.fetchRequest()
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            if let config = results.first {
                self.installationURL = config.installationURL ?? ""
                self.apiToken = config.apiToken ?? ""
                self.isConfigured = !self.installationURL.isEmpty && !self.apiToken.isEmpty
                // Load archivedRetentionDays if present, else default to 30
                if let days = config.value(forKey: "archivedRetentionDays") as? Int {
                    self.archivedRetentionDays = days
                } else {
                    self.archivedRetentionDays = 30
                }
                print("Loaded existing configuration: \(self.isConfigured)")
            } else {
                // No configuration exists, ensure we start fresh
                self.installationURL = ""
                self.apiToken = ""
                self.isConfigured = false
                self.archivedRetentionDays = 30
                print("No existing configuration found")
            }
        } catch {
            print("Error loading configuration: \(error)")
            // On error, assume no configuration exists
            self.isConfigured = false
            self.archivedRetentionDays = 30
        }
    }
    
    func saveConfiguration() {
        print("Attempting to save configuration...")
        
        // Validate URL format
        guard let url = URL(string: installationURL), url.scheme != nil else {
            print("Invalid URL format")
            return
        }
        
        let fetchRequest: NSFetchRequest<InstallationConfig> = InstallationConfig.fetchRequest()
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            let config: InstallationConfig
            
            if let existingConfig = results.first {
                config = existingConfig
                print("Updating existing configuration")
            } else {
                config = InstallationConfig(context: viewContext)
                print("Creating new configuration")
            }
            
            config.installationURL = installationURL
            config.apiToken = apiToken
            config.setValue(archivedRetentionDays, forKey: "archivedRetentionDays")
            
            try viewContext.save()
            print("Configuration saved successfully")
            
            // Update the state on the main thread
            DispatchQueue.main.async {
                self.isConfigured = true
                print("isConfigured set to true")
            }
        } catch {
            print("Error saving configuration: \(error)")
        }
    }
    
    func removeConfiguration() {
        let fetchRequest: NSFetchRequest<InstallationConfig> = InstallationConfig.fetchRequest()
        do {
            let results = try viewContext.fetch(fetchRequest)
            for config in results {
                viewContext.delete(config)
            }
            try viewContext.save()
            DispatchQueue.main.async {
                self.installationURL = ""
                self.apiToken = ""
                self.isConfigured = false
            }
        } catch {
            print("Error removing configuration: \(error)")
        }
    }
} 