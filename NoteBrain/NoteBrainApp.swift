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
            }
        }
    }
}
