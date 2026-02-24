//
//  CullingUndoTests.swift
//  rawctlTests
//
import Foundation
import Testing
@testable import Latent

@MainActor
struct CullingUndoTests {

    @Test func cullingUndoSnapshotCapturesExistingRatings() {
        // Given an AppState with a recipe that has rating=3
        let state = AppState()
        let assetId = UUID()
        var recipe = EditRecipe()
        recipe.rating = 3
        recipe.flag = .pick
        state.recipes[assetId] = recipe

        // When we capture the pre-cull snapshot
        let snapshot = state.capturePreCullSnapshot()

        // Then it should contain the existing rating and flag
        #expect(snapshot[assetId]?.rating == 3)
        #expect(snapshot[assetId]?.flag == .pick)
    }

    @Test func cullingUndoRestoresRatings() {
        let state = AppState()
        let assetId = UUID()
        var original = EditRecipe()
        original.rating = 4
        original.flag = .pick
        state.recipes[assetId] = original

        let snapshot = state.capturePreCullSnapshot()

        // Simulate culling overwriting the rating
        var culledRecipe = EditRecipe()
        culledRecipe.rating = 0
        culledRecipe.flag = .reject
        state.recipes[assetId] = culledRecipe

        // Undo should restore
        state.restorePreCullSnapshot(snapshot)
        #expect(state.recipes[assetId]?.rating == 4)
        #expect(state.recipes[assetId]?.flag == .pick)
    }

    @Test func cullingUndoSnapshotCapturesColorLabel() {
        let state = AppState()
        let assetId = UUID()
        var recipe = EditRecipe()
        recipe.colorLabel = .red
        state.recipes[assetId] = recipe

        let snapshot = state.capturePreCullSnapshot()

        #expect(snapshot[assetId]?.colorLabel == .red)
    }

    @Test func cullingUndoRestoresColorLabel() {
        let state = AppState()
        let assetId = UUID()
        var original = EditRecipe()
        original.colorLabel = .blue
        state.recipes[assetId] = original

        let snapshot = state.capturePreCullSnapshot()

        // Simulate cull overwriting color label
        state.recipes[assetId]?.colorLabel = .none

        state.restorePreCullSnapshot(snapshot)
        #expect(state.recipes[assetId]?.colorLabel == .blue)
    }

    /// Regression guard: restorePreCullSnapshot must always clear lastPreCullSnapshot,
    /// ensuring the undo window closes after restoration regardless of UI state.
    @Test func lastPreCullSnapshotClearedAfterRestore() {
        let state = AppState()
        let assetId = UUID()
        state.recipes[assetId] = EditRecipe()

        let snapshot = state.capturePreCullSnapshot()
        state.lastPreCullSnapshot = snapshot  // simulate "culling just ran"

        state.restorePreCullSnapshot(snapshot)

        #expect(state.lastPreCullSnapshot == nil)
    }
}
