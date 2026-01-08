//
//  rawctlApp.swift
//  rawctl
//
//  Main application entry point
//

import SwiftUI
import GoogleSignIn

@main
struct rawctlApp: App {
    // Initialize the updater manager
    @StateObject private var updaterManager = UpdaterManager.shared

    var body: some Scene {
        WindowGroup {
            MainLayoutView()
                .onOpenURL { url in
                    // Handle Google Sign-In callback
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // App menu - Check for Updates
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updaterManager.checkForUpdates()
                }
                .disabled(!updaterManager.canCheckForUpdates)
            }

            // File menu
            CommandGroup(replacing: .newItem) {
                Button("Open Folder…") {
                    // Will be handled by the view
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            
            // View menu
            CommandMenu("View") {
                Button("Grid View") {
                    // Will be handled by AppState
                }
                .keyboardShortcut("1", modifiers: .command)
                
                Button("Single View") {
                    // Will be handled by AppState
                }
                .keyboardShortcut("2", modifiers: .command)
            }
            
            // Photo menu
            CommandMenu("Photo") {
                Button("Export…") {
                    // Will be handled by export dialog
                }
                .keyboardShortcut("e", modifiers: .command)

                Divider()

                Button("Reset Adjustments") {
                    // Will be handled by AppState
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }

        // Settings window
        #if os(macOS)
        Settings {
            TabView {
                UpdateSettingsView()
                    .tabItem {
                        Label("Updates", systemImage: "arrow.down.circle")
                    }
            }
            .frame(width: 450, height: 250)
        }
        #endif
    }
}
