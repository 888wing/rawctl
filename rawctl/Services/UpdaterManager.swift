//
//  UpdaterManager.swift
//  rawctl
//
//  Distribution-aware update manager.
//

import Foundation
import SwiftUI

#if DISTRIBUTION_CHANNEL_MAS

/// MAS builds are updated exclusively via the Mac App Store.
@MainActor
final class UpdaterManager: ObservableObject {
    static let shared = UpdaterManager()

    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var lastUpdateCheckDate: Date?

    private init() {}

    func checkForUpdates() {
        // No-op by design for Mac App Store builds.
    }

    var automaticallyChecksForUpdates: Bool {
        get { false }
        set { }
    }

    var automaticallyDownloadsUpdates: Bool {
        get { false }
        set { }
    }

    var updateCheckInterval: TimeInterval {
        get { 0 }
        set { }
    }
}

struct UpdateSettingsView: View {
    var body: some View {
        Form {
            Section {
                Text("This build updates through the Mac App Store.")
                    .foregroundStyle(.secondary)

                if let subscriptionsURL = URL(string: "macappstore://showUpdatesPage") {
                    Link("Open App Store Updates", destination: subscriptionsURL)
                }
            } header: {
                Text("Mac App Store Updates")
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#else

import Sparkle

/// Manages automatic updates using Sparkle framework.
@MainActor
final class UpdaterManager: ObservableObject {
    static let shared = UpdaterManager()

    private let updaterController: SPUStandardUpdaterController

    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var lastUpdateCheckDate: Date?

    private init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheckForUpdates)

        updaterController.updater.publisher(for: \.lastUpdateCheckDate)
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastUpdateCheckDate)
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    var automaticallyChecksForUpdates: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set { updaterController.updater.automaticallyChecksForUpdates = newValue }
    }

    var automaticallyDownloadsUpdates: Bool {
        get { updaterController.updater.automaticallyDownloadsUpdates }
        set { updaterController.updater.automaticallyDownloadsUpdates = newValue }
    }

    var updateCheckInterval: TimeInterval {
        get { updaterController.updater.updateCheckInterval }
        set { updaterController.updater.updateCheckInterval = newValue }
    }
}

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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#endif

#Preview {
    UpdateSettingsView()
}
