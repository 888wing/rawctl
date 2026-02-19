//
//  RenderContext.swift
//  rawctl
//
//  Unified render input contract for preview/export paths
//

import Foundation

/// Immutable render inputs shared by preview and export entry points.
struct RenderContext: Equatable {
    let assetId: UUID?
    let recipe: EditRecipe
    let localNodes: [ColorNode]
    let aiLayers: [AILayer]
    let aiEdits: [AIEdit]

    init(
        assetId: UUID? = nil,
        recipe: EditRecipe,
        localNodes: [ColorNode] = [],
        aiLayers: [AILayer] = [],
        aiEdits: [AIEdit] = []
    ) {
        self.assetId = assetId
        self.recipe = recipe
        self.localNodes = localNodes
        self.aiLayers = aiLayers
        self.aiEdits = aiEdits
    }
}

