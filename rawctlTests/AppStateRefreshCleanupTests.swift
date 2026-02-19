//
//  AppStateRefreshCleanupTests.swift
//  rawctlTests
//
//  Regression coverage for incremental refresh state cleanup.
//

import Foundation
import Testing
@testable import rawctl

@MainActor
struct AppStateRefreshCleanupTests {
    @Test func refreshCurrentFolderCleansStateForDeleteMoveRename() async throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent(
            "latent-refresh-cleanup-\(UUID().uuidString)",
            isDirectory: true
        )
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let deletedURL = dir.appendingPathComponent("delete.jpg")
        let renameOldURL = dir.appendingPathComponent("rename_old.jpg")
        let moveOldURL = dir.appendingPathComponent("move_old.jpg")
        try writeJPEGPlaceholder(at: deletedURL)
        try writeJPEGPlaceholder(at: renameOldURL)
        try writeJPEGPlaceholder(at: moveOldURL)

        let appState = AppState()
        appState.selectedFolder = dir
        appState.assets = try await FileSystemService.scanFolder(dir)
        #expect(appState.assets.count == 3)

        // Seed in-memory edit state for every original asset.
        for asset in appState.assets {
            var recipe = EditRecipe()
            recipe.exposure = 0.8
            appState.recipes[asset.id] = recipe
            appState.snapshots[asset.id] = [RecipeSnapshot(name: "Seed", recipe: recipe)]
            appState.localNodes[asset.url] = [ColorNode(name: "Local", type: .serial)]
            appState.aiEditsByURL[asset.url] = [AIEdit(operation: .enhance, resultPath: "dummy.jpg")]
            appState.aiLayerStacks[asset.id] = AILayerStack(documentId: asset.id)
        }

        // Delete one file.
        try fm.removeItem(at: deletedURL)

        // Rename one file in-place.
        let renameNewURL = dir.appendingPathComponent("rename_new.jpg")
        try fm.moveItem(at: renameOldURL, to: renameNewURL)

        // Move one file to a subfolder.
        let movedDir = dir.appendingPathComponent("nested", isDirectory: true)
        try fm.createDirectory(at: movedDir, withIntermediateDirectories: true)
        let moveNewURL = movedDir.appendingPathComponent("move_new.jpg")
        try fm.moveItem(at: moveOldURL, to: moveNewURL)

        await appState.refreshCurrentFolder()

        let livePaths = Set(appState.assets.map { $0.url.standardizedFileURL.path })
        #expect(appState.assets.count == 2)
        #expect(!livePaths.contains(deletedURL.standardizedFileURL.path))
        #expect(!livePaths.contains(renameOldURL.standardizedFileURL.path))
        #expect(!livePaths.contains(moveOldURL.standardizedFileURL.path))
        #expect(livePaths.contains(renameNewURL.standardizedFileURL.path))
        #expect(livePaths.contains(moveNewURL.standardizedFileURL.path))

        // No stale in-memory edit state may remain for detached assets.
        let liveAssetIds = Set(appState.assets.map(\.id))
        #expect(Set(appState.recipes.keys).isSubset(of: liveAssetIds))
        #expect(Set(appState.snapshots.keys).isSubset(of: liveAssetIds))
        #expect(Set(appState.aiLayerStacks.keys).isSubset(of: liveAssetIds))

        let localNodePaths = Set(appState.localNodes.keys.map { $0.standardizedFileURL.path })
        let aiEditPaths = Set(appState.aiEditsByURL.keys.map { $0.standardizedFileURL.path })
        #expect(localNodePaths.isSubset(of: livePaths))
        #expect(aiEditPaths.isSubset(of: livePaths))
    }

    private func writeJPEGPlaceholder(at url: URL) throws {
        try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: url, options: .atomic)
    }
}
