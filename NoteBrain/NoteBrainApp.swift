//
//  NoteBrainApp.swift
//  NoteBrain
//
//  Created by Kaitlyn Concilio on 6/18/25.
//

import SwiftUI

@main
struct NoteBrainApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
