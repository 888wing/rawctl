//
//  SidecarServiceTests.swift
//  rawctlTests
//
//  Sidecar persistence correctness tests (debounce + AI edit preservation)
//

import Foundation
import Testing
@testable import rawctl

struct SidecarServiceTests {
    @Test func saveRecipe_preservesAIEdits() async throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("rawctl-sidecar-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let assetURL = dir.appendingPathComponent("a.jpg")
        try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: assetURL, options: .atomic) // minimal JPEG marker bytes

        let aiEdit = AIEdit(operation: .enhance, resultPath: "ai/result.jpg")
        await SidecarService.shared.saveAIEdits([aiEdit], for: assetURL)

        var recipe = EditRecipe()
        recipe.exposure = 1.25
        await SidecarService.shared.saveRecipe(recipe, snapshots: [], for: assetURL)

        // Debounce is 300ms; wait a bit longer so the write completes.
        try await Task.sleep(nanoseconds: 600_000_000)

        let loaded = await SidecarService.shared.loadRecipeAndAIEdits(for: assetURL)
        #expect(loaded != nil)
        #expect(loaded?.0.exposure == 1.25)
        #expect(loaded?.2.count == 1)
        #expect(loaded?.2.first?.operation == .enhance)
    }

    @Test func saveRecipe_debouncesIndependentlyPerAsset() async throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("rawctl-sidecar-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let assetA = dir.appendingPathComponent("a.jpg")
        let assetB = dir.appendingPathComponent("b.jpg")
        try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: assetA, options: .atomic)
        try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: assetB, options: .atomic)

        var recipeA = EditRecipe()
        recipeA.exposure = 0.5
        var recipeB = EditRecipe()
        recipeB.exposure = 2.0

        // Schedule two debounced saves back-to-back; both should persist.
        await SidecarService.shared.saveRecipe(recipeA, snapshots: [], for: assetA)
        await SidecarService.shared.saveRecipe(recipeB, snapshots: [], for: assetB)

        try await Task.sleep(nanoseconds: 600_000_000)

        let loadedA = await SidecarService.shared.loadRecipeAndSnapshots(for: assetA)
        let loadedB = await SidecarService.shared.loadRecipeAndSnapshots(for: assetB)
        #expect(loadedA != nil)
        #expect(loadedB != nil)
        #expect(loadedA?.0.exposure == 0.5)
        #expect(loadedB?.0.exposure == 2.0)
    }
}

