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
    @StateObject private var configViewModel = InstallationConfigViewModel(context: PersistenceController.shared.container.viewContext)

    var body: some Scene {
        WindowGroup {
            Group {
                if configViewModel.isConfigured {
                    ContentView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                } else {
                    InstallationConfigView(context: persistenceController.container.viewContext)
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                }
            }
            .onChange(of: configViewModel.isConfigured) { newValue in
                print("App: isConfigured changed to: \(newValue)")
            }
        }
    }
}
