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

    // What's New state
    @State private var showWhatsNew = false

    var body: some Scene {
        WindowGroup {
            MainLayoutView()
                .onOpenURL { url in
                    // Handle Google Sign-In callback
                    GIDSignIn.sharedInstance.handle(url)
                }
                .onAppear {
                    // Check if we should show What's New
                    checkForWhatsNew()
                }
                .sheet(isPresented: $showWhatsNew) {
                    WhatsNewView(release: ReleaseHistory.latest) {
                        VersionTracker.markCurrentVersionAsSeen()
                        showWhatsNew = false
                    }
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

                Divider()

                Button("What's New…") {
                    showWhatsNew = true
                }
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
                AboutView()
                    .tabItem {
                        Label("About", systemImage: "info.circle")
                    }

                UpdateSettingsView()
                    .tabItem {
                        Label("Updates", systemImage: "arrow.down.circle")
                    }
            }
            .frame(width: 450, height: 550)
        }
        #endif
    }

    // MARK: - What's New Check

    private func checkForWhatsNew() {
        // Delay slightly to let the main window appear first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if VersionTracker.shouldShowWhatsNew {
                showWhatsNew = true
            }
        }
    }
}
