//
//  NoteBrainApp.swift
//  NoteBrain
//
//  Created by Kaitlyn Concilio on 6/18/25.
//

import SwiftUI
import CoreData

@main
struct NoteBrainApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var configViewModel = InstallationConfigViewModel()
    @StateObject private var webViewSettings = WebViewSettings()
    @StateObject private var cloudKitSettings = CloudKitSettingsManager.shared
    @StateObject private var sharedURLProcessor = SharedURLProcessor.shared
    @StateObject private var memoryManager = MemoryManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if configViewModel.isConfigured {
                    ContentView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .environmentObject(webViewSettings)
                        .environmentObject(configViewModel)
                        .environmentObject(cloudKitSettings)
                } else {
                    InstallationConfigView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .environmentObject(webViewSettings)
                        .environmentObject(configViewModel)
                        .environmentObject(cloudKitSettings)
                }
            }
            .task {
                // Perform migration from existing data sources
                await cloudKitSettings.migrateFromCoreDataAndUserDefaults()
                
                // Start periodic memory monitoring
                startMemoryMonitoring()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                // Check for shared URLs when app becomes active
                sharedURLProcessor.checkForSharedURLs()
            }
        }
    }
    
    private func startMemoryMonitoring() {
        // Log memory usage every 30 seconds
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            memoryManager.logMemoryUsage()
        }
    }
}
