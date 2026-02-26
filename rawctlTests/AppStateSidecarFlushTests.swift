//
//  AppStateSidecarFlushTests.swift
//  rawctlTests
//
//  Regression coverage for lifecycle-safe sidecar flushing.
//

import Foundation
import Testing
@testable import Latent

@MainActor
struct AppStateSidecarFlushTests {
    @Test func flushPendingRecipeSaveAndWaitPersistsDebouncedRecipe() async throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent(
            "latent-appstate-flush-\(UUID().uuidString)",
            isDirectory: true
        )
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let assetURL = dir.appendingPathComponent("flush-debounced.jpg")
        try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: assetURL, options: .atomic)

        let asset = PhotoAsset(url: assetURL)
        let appState = AppState()
        appState.assets = [asset]
        appState.selectedAssetId = asset.id

        var recipe = EditRecipe()
        recipe.exposure = 1.6
        appState.recipes[asset.id] = recipe

        appState.saveCurrentRecipeDebounced()
        await appState.flushPendingRecipeSaveAndWait()

        let loaded = await SidecarService.shared.loadRecipeAndSnapshots(for: assetURL)
        #expect(loaded != nil)
        #expect(loaded?.0.exposure == 1.6)
    }

    @Test func switchingFolderFlushesDebouncedRecipeBeforeContextSwap() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(
            "latent-appstate-switch-flush-\(UUID().uuidString)",
            isDirectory: true
        )
        let folderA = root.appendingPathComponent("folder-a", isDirectory: true)
        let folderB = root.appendingPathComponent("folder-b", isDirectory: true)
        try fm.createDirectory(at: folderA, withIntermediateDirectories: true)
        try fm.createDirectory(at: folderB, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let assetAURL = folderA.appendingPathComponent("a.jpg")
        let assetBURL = folderB.appendingPathComponent("b.jpg")
        let jpegStub = Data([0xFF, 0xD8, 0xFF, 0xD9])
        try jpegStub.write(to: assetAURL, options: .atomic)
        try jpegStub.write(to: assetBURL, options: .atomic)

        let appState = AppState()
        let assetA = PhotoAsset(url: assetAURL)
        appState.assets = [assetA]
        appState.selectedAssetId = assetA.id
        appState.selectedFolder = folderA

        var recipe = EditRecipe()
        recipe.exposure = 2.2
        appState.recipes[assetA.id] = recipe
        appState.saveCurrentRecipeDebounced()

        await appState.openFolderFromPath(folderB.path)

        let loaded = await SidecarService.shared.loadRecipeAndSnapshots(for: assetAURL)
        #expect(loaded != nil)
        #expect(loaded?.0.exposure == 2.2)
    }
}
