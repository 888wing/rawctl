//
//  UpdaterManager.swift
//  rawctl
//
//  Manages app updates using Sparkle framework
//

import Foundation
import Sparkle

/// Manages automatic updates using Sparkle framework
@MainActor
final class UpdaterManager: ObservableObject {

    // MARK: - Shared Instance

    static let shared = UpdaterManager()

    // MARK: - Properties

    private let updaterController: SPUStandardUpdaterController

    /// Whether the updater can check for updates
    @Published private(set) var canCheckForUpdates = false

    /// Last time updates were checked
    @Published private(set) var lastUpdateCheckDate: Date?

    // MARK: - Initialization

    private init() {
        // Initialize the updater controller with automatic start
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        // Bind canCheckForUpdates
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheckForUpdates)

        // Bind lastUpdateCheckDate
        updaterController.updater.publisher(for: \.lastUpdateCheckDate)
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastUpdateCheckDate)
    }

    // MARK: - Public Methods

    /// Check for updates manually
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    /// Whether to automatically check for updates
    var automaticallyChecksForUpdates: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set { updaterController.updater.automaticallyChecksForUpdates = newValue }
    }

    /// Whether to automatically download updates
    var automaticallyDownloadsUpdates: Bool {
        get { updaterController.updater.automaticallyDownloadsUpdates }
        set { updaterController.updater.automaticallyDownloadsUpdates = newValue }
    }

    /// Update check interval in seconds
    var updateCheckInterval: TimeInterval {
        get { updaterController.updater.updateCheckInterval }
        set { updaterController.updater.updateCheckInterval = newValue }
    }
}

// MARK: - SwiftUI View for Settings

import SwiftUI

struct UpdateSettingsView: View {
    @ObservedObject private var updater = UpdaterManager.shared

    var body: some View {
        Form {
            Section {
                Toggle("Automatically check for updates", isOn: Binding(
                    get: { updater.automaticallyChecksForUpdates },
                    set: { updater.automaticallyChecksForUpdates = $0 }
                ))

                Toggle("Automatically download updates", isOn: Binding(
                    get: { updater.automaticallyDownloadsUpdates },
                    set: { updater.automaticallyDownloadsUpdates = $0 }
                ))
                .disabled(!updater.automaticallyChecksForUpdates)
            } header: {
                Text("Automatic Updates")
            }

            Section {
                Button("Check for Updates…") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)

                if let lastCheck = updater.lastUpdateCheckDate {
                    Text("Last checked: \(lastCheck, style: .relative) ago")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Manual Check")
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
    }
}

#Preview {
    UpdateSettingsView()
}
