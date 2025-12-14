//
//  rawctlApp.swift
//  rawctl
//
//  Created by chui siufai on 14/12/2025.
//

import SwiftUI

@main
struct rawctlApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
