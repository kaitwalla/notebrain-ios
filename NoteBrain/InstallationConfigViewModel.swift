import Foundation
import CoreData
import os.log

class InstallationConfigViewModel: ObservableObject {
    @Published var installationURL: String = "" {
        didSet { 
            self.logger.info("installationURL changed from '\(oldValue)' to '\(self.installationURL)'")
            self.debouncedSave()
        }
    }
    @Published var apiToken: String = "" {
        didSet { 
            self.logger.info("apiToken changed from '\(oldValue.isEmpty ? "empty" : "present")' to '\(self.apiToken.isEmpty ? "empty" : "present")'")
            self.debouncedSave()
        }
    }
    @Published var isConfigured: Bool = false
    @Published var archivedRetentionDays: Int = 30 {
        didSet { 
            self.logger.info("archivedRetentionDays changed from \(oldValue) to \(self.archivedRetentionDays)")
            self.debouncedSave()
        }
    }
    
    private let viewContext: NSManagedObjectContext = PersistenceController.shared.container.viewContext
    private let logger = Logger(subsystem: "com.notebrain", category: "InstallationConfig")
    private var saveWorkItem: DispatchWorkItem?
    
    init() {
        self.loadConfiguration()
    }
    
    func loadConfiguration() {
        let fetchRequest: NSFetchRequest<InstallationConfig> = InstallationConfig.fetchRequest()
        
        do {
            let results = try self.viewContext.fetch(fetchRequest)
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
                self.logger.info("Configuration loaded: URL=\(self.installationURL.prefix(10))..., Token=\(self.apiToken.isEmpty ? "empty" : "present")")
            } else {
                // No configuration exists, ensure we start fresh
                self.installationURL = ""
                self.apiToken = ""
                self.isConfigured = false
                self.archivedRetentionDays = 30
                self.logger.info("No existing configuration found")
            }
        } catch {
            // On error, assume no configuration exists
            self.isConfigured = false
            self.archivedRetentionDays = 30
            self.logger.error("Error loading configuration: \(error.localizedDescription)")
        }
    }
    
    private func saveConfiguration() {
        let fetchRequest: NSFetchRequest<InstallationConfig> = InstallationConfig.fetchRequest()
        
        do {
            let results = try self.viewContext.fetch(fetchRequest)
            let config: InstallationConfig
            
            if let existingConfig = results.first {
                config = existingConfig
                self.logger.info("Updating existing configuration")
            } else {
                config = InstallationConfig(context: self.viewContext)
                self.logger.info("Creating new configuration")
            }
            
            config.installationURL = self.installationURL
            config.apiToken = self.apiToken
            config.setValue(self.archivedRetentionDays, forKey: "archivedRetentionDays")
            
            // Verify the values were set correctly
            self.logger.info("Saving configuration: URL=\(self.installationURL.prefix(10))..., Token=\(self.apiToken.isEmpty ? "empty" : "present"), Days=\(self.archivedRetentionDays)")
            
            // Ensure we're on the correct queue for Core Data operations
            if self.viewContext.concurrencyType == .mainQueueConcurrencyType {
                try self.viewContext.save()
            } else {
                self.viewContext.performAndWait {
                    do {
                        try self.viewContext.save()
                    } catch {
                        self.logger.error("Error saving on background context: \(error.localizedDescription)")
                    }
                }
            }
            
            // Verify the save was successful by checking if the context has changes
            if self.viewContext.hasChanges {
                self.logger.warning("Context still has changes after save attempt")
                // Try to save again
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.retrySave()
                }
            } else {
                self.logger.info("Configuration saved successfully")
            }
            
            // Update the state on the main thread
            DispatchQueue.main.async {
                self.isConfigured = !self.installationURL.isEmpty && !self.apiToken.isEmpty
            }
        } catch {
            self.logger.error("Error saving configuration: \(error.localizedDescription)")
            // Don't update isConfigured on error
        }
    }
    
    private func retrySave() {
        do {
            try self.viewContext.save()
            self.logger.info("Retry save successful")
        } catch {
            self.logger.error("Retry save failed: \(error.localizedDescription)")
        }
    }
    
    func removeConfiguration() {
        let fetchRequest: NSFetchRequest<InstallationConfig> = InstallationConfig.fetchRequest()
        do {
            let results = try self.viewContext.fetch(fetchRequest)
            for config in results {
                self.viewContext.delete(config)
            }
            try self.viewContext.save()
            self.logger.info("Configuration removed successfully")
            DispatchQueue.main.async {
                self.installationURL = ""
                self.apiToken = ""
                self.isConfigured = false
            }
        } catch {
            self.logger.error("Error removing configuration: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Debug Methods
    
    func testTokenSaving() {
        self.logger.info("Testing token saving...")
        let testToken = "test_token_\(Date().timeIntervalSince1970)"
        self.apiToken = testToken
        
        // Force an immediate save
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.forceSave()
            
            // Check if the save was successful
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.verifyConfiguration()
                
                // Reload and check
                self.loadConfiguration()
                if self.apiToken == testToken {
                    self.logger.info("Token saving test PASSED")
                } else {
                    self.logger.error("Token saving test FAILED - token not persisted")
                }
            }
        }
    }
    
    func forceSave() {
        self.logger.info("Forcing configuration save...")
        // Cancel any pending debounced save
        self.saveWorkItem?.cancel()
        // Save immediately
        self.saveConfiguration()
    }
    
    func printCurrentState() {
        self.logger.info("Current state: URL=\(self.installationURL), Token=\(self.apiToken.isEmpty ? "empty" : "present"), Configured=\(self.isConfigured)")
    }
    
    func verifyConfiguration() {
        let fetchRequest: NSFetchRequest<InstallationConfig> = InstallationConfig.fetchRequest()
        
        do {
            let results = try self.viewContext.fetch(fetchRequest)
            if let config = results.first {
                let storedURL = config.installationURL ?? ""
                let storedToken = config.apiToken ?? ""
                let storedDays = config.value(forKey: "archivedRetentionDays") as? Int ?? 30
                
                self.logger.info("Stored configuration: URL=\(storedURL), Token=\(storedToken.isEmpty ? "empty" : "present"), Days=\(storedDays)")
                self.logger.info("Current configuration: URL=\(self.installationURL), Token=\(self.apiToken.isEmpty ? "empty" : "present"), Days=\(self.archivedRetentionDays)")
                
                if storedURL == self.installationURL && storedToken == self.apiToken && storedDays == self.archivedRetentionDays {
                    self.logger.info("Configuration verification PASSED - stored and current values match")
                } else {
                    self.logger.error("Configuration verification FAILED - stored and current values don't match")
                }
            } else {
                self.logger.warning("No configuration found in Core Data")
            }
        } catch {
            self.logger.error("Error verifying configuration: \(error.localizedDescription)")
        }
    }
    
    private func debouncedSave() {
        // Cancel any pending save
        self.saveWorkItem?.cancel()
        
        // Create a new save work item
        self.saveWorkItem = DispatchWorkItem { [weak self] in
            self?.saveConfiguration()
        }
        
        // Schedule the save after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: self.saveWorkItem!)
    }
} 