//
//  SidecarServiceTests.swift
//  rawctlTests
//
//  Sidecar persistence correctness tests (debounce + AI edit preservation)
//

import Foundation
import Testing
@testable import Latent

struct SidecarServiceTests {
    @Test func saveRecipe_preservesAIEditsAndAILayers() async throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("latent-sidecar-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let assetURL = dir.appendingPathComponent("a.jpg")
        try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: assetURL, options: .atomic) // minimal JPEG marker bytes

        let aiEdit = AIEdit(operation: .enhance, resultPath: "ai/result.jpg")
        await SidecarService.shared.saveAIEdits([aiEdit], for: assetURL)
        let aiLayer = AILayer(
            type: .enhance,
            prompt: "Enhance subject",
            originalPrompt: "Enhance subject",
            generatedImagePath: "ai/layer.jpg",
            creditsUsed: 1
        )
        await SidecarService.shared.saveAILayers([aiLayer], for: assetURL)

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
        let layers = await SidecarService.shared.loadAILayers(for: assetURL)
        #expect(layers.count == 1)
        #expect(layers.first?.generatedImagePath == "ai/layer.jpg")
    }

    @Test func saveRecipe_debouncesIndependentlyPerAsset() async throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("latent-sidecar-\(UUID().uuidString)", isDirectory: true)
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

    @Test func saveRecipeOnly_skipsSemanticNoOpWrite() async throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("latent-sidecar-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let assetURL = dir.appendingPathComponent("noop.jpg")
        try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: assetURL, options: .atomic)

        var recipe = EditRecipe()
        recipe.exposure = 0.75

        await SidecarService.shared.saveRecipeOnly(recipe, for: assetURL)
        let sidecarURL = FileSystemService.sidecarURL(for: assetURL)
        let firstData = try Data(contentsOf: sidecarURL)
        let first = try JSONDecoder().decode(SidecarFile.self, from: firstData)

        try await Task.sleep(nanoseconds: 80_000_000)
        await SidecarService.shared.saveRecipeOnly(recipe, for: assetURL)

        let secondData = try Data(contentsOf: sidecarURL)
        let second = try JSONDecoder().decode(SidecarFile.self, from: secondData)
        #expect(first.updatedAt == second.updatedAt)
    }

    @Test func saveAIEdits_skipsSemanticNoOpWrite() async throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("latent-sidecar-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let assetURL = dir.appendingPathComponent("ai-noop.jpg")
        try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: assetURL, options: .atomic)

        let aiEdit = AIEdit(operation: .enhance, resultPath: "ai/enhance.jpg")
        await SidecarService.shared.saveAIEdits([aiEdit], for: assetURL)

        let sidecarURL = FileSystemService.sidecarURL(for: assetURL)
        let firstData = try Data(contentsOf: sidecarURL)
        let first = try JSONDecoder().decode(SidecarFile.self, from: firstData)

        try await Task.sleep(nanoseconds: 80_000_000)
        await SidecarService.shared.saveAIEdits([aiEdit], for: assetURL)

        let secondData = try Data(contentsOf: sidecarURL)
        let second = try JSONDecoder().decode(SidecarFile.self, from: secondData)
        #expect(first.updatedAt == second.updatedAt)
    }

    @Test func saveAILayers_skipsSemanticNoOpWrite() async throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("latent-sidecar-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let assetURL = dir.appendingPathComponent("layers-noop.jpg")
        try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: assetURL, options: .atomic)

        let aiLayer = AILayer(
            type: .transform,
            prompt: "Transform lighting",
            originalPrompt: "Transform lighting",
            generatedImagePath: "ai/layer-1.jpg",
            creditsUsed: 1
        )
        await SidecarService.shared.saveAILayers([aiLayer], for: assetURL)

        let sidecarURL = FileSystemService.sidecarURL(for: assetURL)
        let firstData = try Data(contentsOf: sidecarURL)
        let first = try JSONDecoder().decode(SidecarFile.self, from: firstData)

        try await Task.sleep(nanoseconds: 80_000_000)
        await SidecarService.shared.saveAILayers([aiLayer], for: assetURL)

        let secondData = try Data(contentsOf: sidecarURL)
        let second = try JSONDecoder().decode(SidecarFile.self, from: secondData)
        #expect(first.updatedAt == second.updatedAt)
    }

    @Test func flushPendingDebouncedSaves_writesImmediately() async throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("latent-sidecar-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let assetURL = dir.appendingPathComponent("flush.jpg")
        try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: assetURL, options: .atomic)

        var recipe = EditRecipe()
        recipe.exposure = 1.4
        await SidecarService.shared.saveRecipe(recipe, snapshots: [], for: assetURL)

        await SidecarService.shared.flushPendingDebouncedSaves()
        let loaded = await SidecarService.shared.loadRecipeAndSnapshots(for: assetURL)
        #expect(loaded != nil)
        #expect(loaded?.0.exposure == 1.4)
    }

    @Test func writeMetrics_tracksQueuedSkippedFlushedAndWritten() async throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("latent-sidecar-metrics-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let assetURL = dir.appendingPathComponent("metrics.jpg")
        try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: assetURL, options: .atomic)

        let service = SidecarService()
        await service.resetWriteMetrics()

        var recipe = EditRecipe()
        recipe.exposure = 0.8

        await service.saveRecipe(recipe, snapshots: [], for: assetURL)
        let afterQueue = await service.currentWriteMetrics()
        #expect(afterQueue.queued == 1)

        await service.flushPendingDebouncedSaves()
        let afterFlush = await service.currentWriteMetrics()
        #expect(afterFlush.flushed == 1)
        #expect(afterFlush.written == 1)

        await service.saveRecipeOnly(recipe, for: assetURL)
        let final = await service.currentWriteMetrics()
        #expect(final.skippedNoOp >= 1)
        #expect(final.written == 1)
    }
}
