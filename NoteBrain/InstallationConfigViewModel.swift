import Foundation
import CoreData
import os.log

@MainActor
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
    private let cloudKitSettings = CloudKitSettingsManager.shared
    
    init() {
        // Bind to CloudKit settings manager
        setupCloudKitBindings()
        self.loadConfiguration()
    }
    
    private func setupCloudKitBindings() {
        // Bind CloudKit settings to this view model
        cloudKitSettings.$installationURL
            .assign(to: &$installationURL)
        
        cloudKitSettings.$apiToken
            .assign(to: &$apiToken)
        
        cloudKitSettings.$archivedRetentionDays
            .assign(to: &$archivedRetentionDays)
        
        cloudKitSettings.$isConfigured
            .assign(to: &$isConfigured)
    }
    
    func loadConfiguration() {
        // The CloudKit settings manager handles loading automatically
        // This method is kept for backward compatibility and migration
        self.logger.info("Loading configuration from CloudKit settings manager")
        
        // Trigger a migration if needed
        Task {
            await cloudKitSettings.migrateFromCoreDataAndUserDefaults()
        }
    }
    
    private func saveConfiguration() {
        // Use CloudKit settings manager for saving
        cloudKitSettings.installationURL = self.installationURL
        cloudKitSettings.apiToken = self.apiToken
        cloudKitSettings.archivedRetentionDays = self.archivedRetentionDays
        cloudKitSettings.saveSettings()
        
        self.logger.info("Configuration saved via CloudKit settings manager")
    }
    
    func removeConfiguration() {
        Task {
            cloudKitSettings.removeAllSettings()
            self.logger.info("Configuration removed via CloudKit settings manager")
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
        self.logger.info("Verifying configuration with CloudKit settings manager")
        self.logger.info("Current configuration: URL=\(self.installationURL), Token=\(self.apiToken.isEmpty ? "empty" : "present"), Days=\(self.archivedRetentionDays)")
        
        // Check if CloudKit settings match
        if cloudKitSettings.installationURL == self.installationURL && 
           cloudKitSettings.apiToken == self.apiToken && 
           cloudKitSettings.archivedRetentionDays == self.archivedRetentionDays {
            self.logger.info("Configuration verification PASSED - CloudKit and local values match")
        } else {
            self.logger.error("Configuration verification FAILED - CloudKit and local values don't match")
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