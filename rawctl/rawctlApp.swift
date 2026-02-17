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
                    NotificationCenter.default.post(name: .rawctlOpenFolderCommand, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            // View menu (Grid / Single) commands use focused AppState.
            RawctlViewCommands()

            // Photo menu
            CommandMenu("Photo") {
                Button("Export…") {
                    NotificationCenter.default.post(name: .rawctlExportCommand, object: nil)
                }
                .keyboardShortcut("e", modifiers: .command)

                Divider()

                Button("Reset Adjustments") {
                    NotificationCenter.default.post(name: .rawctlResetAdjustmentsCommand, object: nil)
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
        if ProcessInfo.processInfo.environment["RAWCTL_DISABLE_WHATS_NEW"] == "1" {
            return
        }

        // Delay slightly to let the main window appear first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if VersionTracker.shouldShowWhatsNew {
                showWhatsNew = true
            }
        }
    }
}
