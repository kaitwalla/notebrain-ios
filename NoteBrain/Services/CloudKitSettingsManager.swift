import Foundation
import CloudKit
import CoreData
import os.log
import SwiftUI

enum DarkModeOption: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

@MainActor
class CloudKitSettingsManager: ObservableObject {
    static let shared = CloudKitSettingsManager()
    
    // MARK: - Published Properties
    @Published var installationURL: String = ""
    @Published var apiToken: String = ""
    @Published var archivedRetentionDays: Int = 30
    @Published var fontSize: CGFloat = 30
    @Published var fontFamily: String = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif"
    @Published var textColor: String = "#000000"
    @Published var backgroundColor: String = "#ffffff"
    @Published var lineHeight: CGFloat = 1.7
    @Published var darkModeOption: DarkModeOption = .system
    @Published var paragraphSpacing: CGFloat = 1.0
    @Published var isConfigured: Bool = false
    @Published var isLoading: Bool = false
    @Published var lastSyncDate: Date?
    
    // MARK: - Private Properties
    private let container = CKContainer.default()
    private let database: CKDatabase
    private let logger = Logger(subsystem: "kait.dev.NoteBrain", category: "CloudKitSettings")
    private let settingsRecordType = "AppSettings"
    private var saveWorkItem: DispatchWorkItem?
    private let viewContext: NSManagedObjectContext = PersistenceController.shared.container.viewContext
    
    // MARK: - Initialization
    private init() {
        self.database = container.privateCloudDatabase
        Task {
            await loadSettings()
        }
    }
    
    // MARK: - Public Methods
    
    func saveSettings() {
        // Cancel any pending save
        saveWorkItem?.cancel()
        
        // Create a new save work item
        saveWorkItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                await self?.performSave()
            }
        }
        
        // Schedule the save after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: saveWorkItem!)
    }
    
    func forceSave() {
        saveWorkItem?.cancel()
        Task {
            await performSave()
        }
    }
    
    func removeAllSettings() {
        Task {
            await performRemoveAllSettings()
        }
    }
    
    // MARK: - Test Methods
    
    func testCloudKitConnectivity() async -> Bool {
        do {
            let status = try await container.accountStatus()
            logger.info("CloudKit account status: \(status.rawValue)")
            return status == .available
        } catch {
            logger.error("CloudKit connectivity test failed: \(error.localizedDescription)")
            return false
        }
    }
    
    func testSettingsPersistence() async -> Bool {
        // Save a test value
        let testValue = "test_\(Date().timeIntervalSince1970)"
        installationURL = testValue
        
        // Force save
        await performSave()
        
        // Wait a moment for sync
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Try to fetch and verify
        do {
            let record = try await fetchSettingsRecord()
            let savedValue = record?["installationURL"] as? String
            let success = savedValue == testValue
            logger.info("Settings persistence test: \(success ? "PASSED" : "FAILED")")
            return success
        } catch {
            logger.error("Settings persistence test failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func loadSettings() async {
        isLoading = true
        
        do {
            // Check CloudKit availability
            let status = try await container.accountStatus()
            guard status == .available else {
                logger.warning("CloudKit not available: \(status.rawValue)")
                await loadFromUserDefaults()
                isLoading = false
                return
            }
            
            // Try to fetch settings from CloudKit
            let record = try await fetchSettingsRecord()
            
            if let record = record {
                await updateFromRecord(record)
                logger.info("Settings loaded from CloudKit")
            } else {
                // No CloudKit record exists, try to load from UserDefaults and migrate
                await loadFromUserDefaults()
                // Save to CloudKit for future sync
                await performSave()
                logger.info("Settings migrated from UserDefaults to CloudKit")
            }
            
            lastSyncDate = Date()
            
        } catch {
            logger.error("Error loading settings: \(error.localizedDescription)")
            // Fallback to UserDefaults
            await loadFromUserDefaults()
        }
        
        isLoading = false
        updateConfiguredState()
    }
    
    private func fetchSettingsRecord() async throws -> CKRecord? {
        let predicate = NSPredicate(value: true) // Get the first (and only) settings record
        let query = CKQuery(recordType: settingsRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]
        
        let result = try await database.records(matching: query, resultsLimit: 1)
        if let firstResult = result.matchResults.first {
            return try firstResult.1.get()
        }
        return nil
    }
    
    private func syncToCoreData() {
        // Validate and clean the apiToken
        let cleanApiToken = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanApiToken.contains("CloudKit not available") || cleanApiToken.contains("[APIService]") {
            // Don't save corrupted token
            return
        }
        
        // Save to UserDefaults as well
        let defaults = UserDefaults.standard
        defaults.set(installationURL, forKey: "InstallationURL")
        defaults.set(cleanApiToken, forKey: "APIToken")
        defaults.set(archivedRetentionDays, forKey: "ArchivedRetentionDays")
        
        // Save WebView settings to UserDefaults for immediate persistence
        defaults.set(fontSize, forKey: "WebViewFontSize")
        defaults.set(fontFamily, forKey: "WebViewFontFamily")
        defaults.set(textColor, forKey: "WebViewTextColor")
        defaults.set(backgroundColor, forKey: "WebViewBackgroundColor")
        defaults.set(lineHeight, forKey: "WebViewLineHeight")
        defaults.set(darkModeOption.rawValue, forKey: "WebViewUseDarkMode")
        defaults.set(paragraphSpacing, forKey: "WebViewParagraphSpacing")
        
        let fetchRequest: NSFetchRequest<InstallationConfig> = InstallationConfig.fetchRequest()
        let config: InstallationConfig
        if let existing = try? viewContext.fetch(fetchRequest).first {
            config = existing
        } else {
            config = InstallationConfig(context: viewContext)
        }
        config.installationURL = self.installationURL
        config.apiToken = cleanApiToken
        config.archivedRetentionDays = Int32(self.archivedRetentionDays)
        try? viewContext.save()
    }
    
    private func updateFromRecord(_ record: CKRecord) async {
        installationURL = record["installationURL"] as? String ?? ""
        apiToken = record["apiToken"] as? String ?? ""
        archivedRetentionDays = record["archivedRetentionDays"] as? Int ?? 30
        fontSize = CGFloat(record["fontSize"] as? Double ?? 30.0)
        fontFamily = record["fontFamily"] as? String ?? "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif"
        textColor = record["textColor"] as? String ?? "#000000"
        backgroundColor = record["backgroundColor"] as? String ?? "#ffffff"
        lineHeight = CGFloat(record["lineHeight"] as? Double ?? 1.7)
        
        // Handle migration from old boolean useDarkMode to new string-based darkModeOption
        if let darkModeString = record["useDarkMode"] as? String {
            // New format - already a string
            darkModeOption = DarkModeOption(rawValue: darkModeString) ?? .system
        } else if let darkModeBool = record["useDarkMode"] as? Bool {
            // Old format - boolean value exists
            darkModeOption = darkModeBool ? .dark : .light
            logger.info("Migrated useDarkMode from boolean to string format in CloudKit record")
        } else {
            // No value exists, use default
            darkModeOption = .system
        }
        
        paragraphSpacing = CGFloat(record["paragraphSpacing"] as? Double ?? 1.0)
        
        // Save to UserDefaults for immediate persistence
        let defaults = UserDefaults.standard
        defaults.set(fontSize, forKey: "WebViewFontSize")
        defaults.set(fontFamily, forKey: "WebViewFontFamily")
        defaults.set(textColor, forKey: "WebViewTextColor")
        defaults.set(backgroundColor, forKey: "WebViewBackgroundColor")
        defaults.set(lineHeight, forKey: "WebViewLineHeight")
        defaults.set(darkModeOption.rawValue, forKey: "WebViewUseDarkMode")
        defaults.set(paragraphSpacing, forKey: "WebViewParagraphSpacing")
        
        syncToCoreData()
    }
    
    private func loadFromUserDefaults() async {
        let defaults = UserDefaults.standard
        
        // Load installation settings from UserDefaults
        installationURL = defaults.string(forKey: "InstallationURL") ?? ""
        apiToken = defaults.string(forKey: "APIToken") ?? ""
        archivedRetentionDays = defaults.integer(forKey: "ArchivedRetentionDays")
        if archivedRetentionDays == 0 {
            archivedRetentionDays = 30 // Default value
        }
        
        // Load WebView settings from UserDefaults
        fontSize = defaults.object(forKey: "WebViewFontSize") as? CGFloat ?? CGFloat(30)
        fontFamily = defaults.string(forKey: "WebViewFontFamily") ?? "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif"
        textColor = defaults.string(forKey: "WebViewTextColor") ?? "#000000"
        backgroundColor = defaults.string(forKey: "WebViewBackgroundColor") ?? "#ffffff"
        lineHeight = defaults.object(forKey: "WebViewLineHeight") as? CGFloat ?? CGFloat(1.7)
        
        // Handle migration from old boolean useDarkMode to new string-based darkModeOption
        if let oldDarkModeString = defaults.string(forKey: "WebViewUseDarkMode") {
            // New format - already a string
            darkModeOption = DarkModeOption(rawValue: oldDarkModeString) ?? .system
        } else if defaults.object(forKey: "WebViewUseDarkMode") != nil {
            // Old format - boolean value exists
            let oldDarkModeBool = defaults.bool(forKey: "WebViewUseDarkMode")
            darkModeOption = oldDarkModeBool ? .dark : .light
            // Update UserDefaults to new format
            defaults.set(darkModeOption.rawValue, forKey: "WebViewUseDarkMode")
            logger.info("Migrated useDarkMode from boolean to string format")
        } else {
            // No value exists, use default
            darkModeOption = .system
        }
        
        paragraphSpacing = defaults.object(forKey: "WebViewParagraphSpacing") as? CGFloat ?? CGFloat(1.0)
        syncToCoreData()
    }
    
    private func performSave() async {
        do {
            // Check CloudKit availability
            let status = try await container.accountStatus()
            guard status == .available else {
                logger.warning("CloudKit not available for save: \(status.rawValue)")
                // Still sync to Core Data even when CloudKit is not available
                syncToCoreData()
                updateConfiguredState()
                return
            }
            
            let record = try await fetchSettingsRecord() ?? CKRecord(recordType: settingsRecordType)
            
            // Update record with current values
            record.setValue(installationURL, forKey: "installationURL")
            record.setValue(apiToken, forKey: "apiToken")
            record.setValue(archivedRetentionDays, forKey: "archivedRetentionDays")
            record.setValue(Double(fontSize), forKey: "fontSize")
            record.setValue(fontFamily, forKey: "fontFamily")
            record.setValue(textColor, forKey: "textColor")
            record.setValue(backgroundColor, forKey: "backgroundColor")
            record.setValue(Double(lineHeight), forKey: "lineHeight")
            record.setValue(darkModeOption.rawValue, forKey: "useDarkMode")
            record.setValue(Double(paragraphSpacing), forKey: "paragraphSpacing")
            record.setValue(Date(), forKey: "lastModified")
            
            // Save to CloudKit
            let savedRecord = try await database.save(record)
            logger.info("Settings saved to CloudKit: \(savedRecord.recordID.recordName)")
            
            lastSyncDate = Date()
            syncToCoreData()
            
        } catch {
            logger.error("Error saving settings to CloudKit: \(error.localizedDescription)")
            // Still sync to Core Data even if CloudKit save fails
            syncToCoreData()
        }
        
        // Update the configured state after save attempt
        updateConfiguredState()
    }
    
    private func performRemoveAllSettings() async {
        do {
            // Check CloudKit availability
            let status = try await container.accountStatus()
            guard status == .available else {
                logger.warning("CloudKit not available for removal: \(status.rawValue)")
                return
            }
            
            if let record = try await fetchSettingsRecord() {
                try await database.deleteRecord(withID: record.recordID)
                logger.info("Settings removed from CloudKit")
            }
            
            // Reset all values
            installationURL = ""
            apiToken = ""
            archivedRetentionDays = 30
            fontSize = CGFloat(30)
            fontFamily = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif"
            textColor = "#000000"
            backgroundColor = "#ffffff"
            lineHeight = CGFloat(1.7)
            darkModeOption = .system
            paragraphSpacing = CGFloat(1.0)
            
            updateConfiguredState()
            
        } catch {
            logger.error("Error removing settings from CloudKit: \(error.localizedDescription)")
        }
    }
    
    private func updateConfiguredState() {
        let newConfiguredState = !installationURL.isEmpty && !apiToken.isEmpty
        if self.isConfigured != newConfiguredState {
            logger.info("isConfigured state changing from \(self.isConfigured) to \(newConfiguredState)")
            isConfigured = newConfiguredState
        }
    }
    
    // MARK: - Migration Helper
    
    func migrateFromCoreDataAndUserDefaults() async {
        // This method will be called during app startup to migrate existing data
        logger.info("Starting migration from Core Data and UserDefaults to CloudKit")
        
        // Load installation config from Core Data
        await loadInstallationConfigFromCoreData()
        
        // Load WebView settings from UserDefaults
        await loadFromUserDefaults()
        
        // Save to CloudKit
        await performSave()
        
        logger.info("Migration completed")
    }
    
    private func loadInstallationConfigFromCoreData() async {
        let fetchRequest: NSFetchRequest<InstallationConfig> = InstallationConfig.fetchRequest()
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            if let config = results.first {
                installationURL = config.installationURL ?? ""
                apiToken = config.apiToken ?? ""
                if let days = config.value(forKey: "archivedRetentionDays") as? Int {
                    archivedRetentionDays = days
                }
                logger.info("Installation config loaded from Core Data")
            }
        } catch {
            logger.error("Error loading installation config from Core Data: \(error.localizedDescription)")
        }
    }
} 