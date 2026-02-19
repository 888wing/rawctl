//
//  RenderContextBuilderTests.swift
//  rawctlTests
//
//  AppState.makeRenderContext regression coverage.
//

import Foundation
import Testing
@testable import rawctl

@MainActor
struct RenderContextBuilderTests {
    @Test func makeRenderContextBuildsUnifiedState() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent(
            "latent-render-context-builder-\(UUID().uuidString)",
            isDirectory: true
        )
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let assetURL = dir.appendingPathComponent("context.jpg")
        try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: assetURL, options: .atomic)
        let asset = PhotoAsset(url: assetURL)

        let appState = AppState()
        appState.assets = [asset]

        var recipe = EditRecipe()
        recipe.exposure = 0.95
        appState.recipes[asset.id] = recipe

        var node = ColorNode(name: "Local", type: .serial)
        node.adjustments.contrast = 18
        appState.localNodes[asset.url] = [node]

        let aiEdit = AIEdit(operation: .enhance, resultPath: "ai/edit.jpg")
        appState.aiEditsByURL[asset.url] = [aiEdit]

        var layer = AILayer(
            type: .enhance,
            prompt: "Enhance subject",
            originalPrompt: "Enhance subject",
            generatedImagePath: "ai/layer.jpg",
            creditsUsed: 1
        )
        layer.opacity = 0.6
        appState.aiLayerStacks[asset.id] = AILayerStack(documentId: asset.id, layers: [layer])

        let context = appState.makeRenderContext(for: asset)
        #expect(context.assetId == asset.id)
        #expect(context.recipe.exposure == 0.95)
        #expect(context.localNodes.count == 1)
        #expect(context.localNodes.first?.adjustments.contrast == 18)
        #expect(context.aiEdits.count == 1)
        #expect(context.aiEdits.first?.resultPath == "ai/edit.jpg")
        #expect(context.aiLayers.count == 1)
        #expect(context.aiLayers.first?.opacity == 0.6)
    }

    @Test func makeRenderContextPrefersExplicitOverrides() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent(
            "latent-render-context-override-\(UUID().uuidString)",
            isDirectory: true
        )
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let assetURL = dir.appendingPathComponent("override.jpg")
        try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: assetURL, options: .atomic)
        let asset = PhotoAsset(url: assetURL)

        let appState = AppState()
        appState.assets = [asset]
        appState.recipes[asset.id] = EditRecipe()
        appState.localNodes[asset.url] = [ColorNode(name: "Stored", type: .serial)]

        var explicitRecipe = EditRecipe()
        explicitRecipe.exposure = 1.7

        var explicitNode = ColorNode(name: "Explicit", type: .serial)
        explicitNode.adjustments.shadows = 22
        let explicitNodes = [explicitNode]

        let context = appState.makeRenderContext(
            for: asset,
            recipe: explicitRecipe,
            localNodes: explicitNodes
        )

        #expect(context.recipe.exposure == 1.7)
        #expect(context.localNodes.count == 1)
        #expect(context.localNodes.first?.name == "Explicit")
        #expect(context.localNodes.first?.adjustments.shadows == 22)
    }
}
