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

    var body: some Scene {
        WindowGroup {
            Group {
                if configViewModel.isConfigured {
                    ContentView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .environmentObject(webViewSettings)
                        .environmentObject(configViewModel)
                } else {
                    InstallationConfigView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .environmentObject(webViewSettings)
                        .environmentObject(configViewModel)
                }
            }
        }
    }
}
