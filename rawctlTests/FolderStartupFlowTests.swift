//
//  FolderStartupFlowTests.swift
//  rawctlTests
//
//  Coverage for folder startup priority, migration, and recent/saved wiring.
//

import Foundation
import Testing
@testable import Latent

@MainActor
struct FolderStartupFlowTests {
    @Test func startupChoicePrefersDefaultFolderOverLastOpened() async throws {
        let defaultURL = URL(fileURLWithPath: "/tmp/latent-default")
        let lastOpenedPath = "/tmp/latent-last"

        let choice = AppState.resolveStartupFolderChoice(
            defaultFolderURL: defaultURL,
            lastOpenedFolderPath: lastOpenedPath
        )

        #expect(choice == .defaultFolder(defaultURL))
    }

    @Test func startupChoiceFallsBackToLastOpenedWhenNoDefault() async throws {
        let lastOpenedPath = "/tmp/latent-last-only"

        let choice = AppState.resolveStartupFolderChoice(
            defaultFolderURL: nil,
            lastOpenedFolderPath: lastOpenedPath
        )

        #expect(choice == .lastOpened(URL(fileURLWithPath: lastOpenedPath)))
    }

    @Test func folderManagerMigratesLegacyNamespaceKeys() async throws {
        let isolated = makeIsolatedDefaults()
        defer { isolated.reset() }

        let legacyManager = FolderManager(
            userDefaults: isolated.defaults,
            namespace: "rawctl",
            legacyNamespaces: []
        )

        let folder = try makeTemporaryFolder(name: "legacy-folder")
        defer { try? FileManager.default.removeItem(at: folder) }

        _ = legacyManager.addFolder(folder)
        #expect(isolated.defaults.data(forKey: "rawctl.folderSources") != nil)

        let migratedManager = FolderManager(
            userDefaults: isolated.defaults,
            namespace: "latent",
            legacyNamespaces: ["rawctl"]
        )

        #expect(migratedManager.sources.count == 1)
        #expect(migratedManager.recentFolders.count == 1)
        #expect(migratedManager.recentFolders.first?.path == folder.standardizedFileURL.path)
        #expect(isolated.defaults.data(forKey: "latent.folderSources") != nil)
        #expect(isolated.defaults.array(forKey: "latent.recentFolders") != nil)
    }

    @Test func folderManagerKeepsRecentUniqueAndMovesReopenedFolderToFront() async throws {
        let isolated = makeIsolatedDefaults()
        defer { isolated.reset() }

        let manager = FolderManager(
            userDefaults: isolated.defaults,
            namespace: "latent",
            legacyNamespaces: []
        )

        let first = try makeTemporaryFolder(name: "recent-first")
        let second = try makeTemporaryFolder(name: "recent-second")
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }

        _ = manager.addFolder(first)
        _ = manager.addFolder(second)
        _ = manager.addFolder(first)

        #expect(manager.recentFolders.count == 2)
        #expect(manager.recentFolders.first?.path == first.standardizedFileURL.path)
        #expect(manager.recentFolders.last?.path == second.standardizedFileURL.path)
    }

    @Test func appStateMigratesLegacyFolderKeysAndRegistersOpenedFolder() async throws {
        let isolated = makeIsolatedDefaults()
        defer { isolated.reset() }

        let defaults = isolated.defaults
        let manager = FolderManager(
            userDefaults: defaults,
            namespace: "latent",
            legacyNamespaces: []
        )

        let folder = try makeTemporaryFolder(name: "startup-migration")
        defer { try? FileManager.default.removeItem(at: folder) }

        defaults.set(folder.path, forKey: "lastOpenedFolder")
        defaults.set(folder.path, forKey: "defaultFolderPath")

        let appState = AppState(userDefaults: defaults, folderManager: manager)
        let migratedLastOpened = defaults.string(forKey: "latent.lastOpenedFolder")
        #expect(migratedLastOpened == folder.path)
        #expect(manager.defaultFolderURL?.path == folder.standardizedFileURL.path)
        #expect(defaults.string(forKey: "defaultFolderPath") == nil)

        let imagePath = folder.appendingPathComponent("sample.jpg")
        FileManager.default.createFile(atPath: imagePath.path, contents: Data([0x01, 0x02, 0x03]))

        let didOpen = await appState.openFolderFromPath(folder.path, registerInFolderHistory: true)
        #expect(didOpen == true)
        #expect(manager.source(for: folder) != nil)
        #expect(manager.recentFolders.first?.path == folder.standardizedFileURL.path)
        #expect(defaults.string(forKey: "latent.lastOpenedFolder") == folder.path)

        appState.cancelBackgroundAssetLoading(resetThumbnailProgress: true, cancelStagedScan: true)
        try? await Task.sleep(nanoseconds: 100_000_000)
    }
}

private func makeIsolatedDefaults() -> (suiteName: String, defaults: UserDefaults, reset: () -> Void) {
    let suiteName = "rawctl.tests.folder-startup.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return (
        suiteName: suiteName,
        defaults: defaults,
        reset: {
            defaults.removePersistentDomain(forName: suiteName)
        }
    )
}

private func makeTemporaryFolder(name: String) throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("latent-tests-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent(name, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}
