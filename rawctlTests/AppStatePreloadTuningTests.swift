//
//  AppStatePreloadTuningTests.swift
//  rawctlTests
//
//  Regression coverage for large-library preload window/backpressure tuning.
//

import Foundation
import Testing
@testable import Latent

@MainActor
struct AppStatePreloadTuningTests {
    @Test func sidecarPriorityOrderStartsFromSelectionAndKeepsAllAssets() async throws {
        let assets = makeAssets(count: 24)
        let selected = assets[12]

        let ordered = AppState.prioritizedAssetOrder(
            for: assets,
            preferredAssetId: selected.id,
            prioritizeWindowSize: 9,
            includeRemainder: true
        )

        #expect(ordered.count == assets.count)
        #expect(Set(ordered.map(\.id)).count == assets.count)
        #expect(ordered.first?.id == selected.id)
    }

    @Test func thumbnailWindowPlanCapsLargeLibraryPreload() async throws {
        let assets = makeAssets(count: 2_000)
        let selected = assets[1_000]
        let window = AppState.thumbnailPreloadWindowSize(forAssetCount: assets.count)

        let planned = AppState.prioritizedAssetOrder(
            for: assets,
            preferredAssetId: selected.id,
            prioritizeWindowSize: window,
            includeRemainder: false
        )

        #expect(planned.count == window)
        #expect(planned.contains(where: { $0.id == selected.id }))
        #expect(!planned.contains(where: { $0.id == assets[0].id }))
    }

    @Test func backpressureConcurrencyTiersShrinkForHugeLibraries() async throws {
        #expect(AppState.sidecarLoadConcurrency(forAssetCount: 120) == 8)
        #expect(AppState.sidecarLoadConcurrency(forAssetCount: 900) == 4)
        #expect(AppState.sidecarLoadConcurrency(forAssetCount: 5_000) == 3)

        #expect(AppState.thumbnailPreloadConcurrency(forAssetCount: 120) == 6)
        #expect(AppState.thumbnailPreloadConcurrency(forAssetCount: 1_200) == 4)
        #expect(AppState.thumbnailPreloadConcurrency(forAssetCount: 5_000) == 3)
    }

    private func makeAssets(count: Int) -> [PhotoAsset] {
        (0..<count).map { index in
            PhotoAsset(url: URL(fileURLWithPath: "/tmp/latent-preload-\(index).jpg"))
        }
    }
}
