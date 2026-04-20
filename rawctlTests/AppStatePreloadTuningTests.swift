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
        #expect(AppState.sidecarLoadConcurrency(forAssetCount: 80) == 6)
        #expect(AppState.sidecarLoadConcurrency(forAssetCount: 900) == 3)
        #expect(AppState.sidecarLoadConcurrency(forAssetCount: 5_000) == 2)

        #expect(AppState.thumbnailPreloadConcurrency(forAssetCount: 120) == 5)
        #expect(AppState.thumbnailPreloadConcurrency(forAssetCount: 1_200) == 3)
        #expect(AppState.thumbnailPreloadConcurrency(forAssetCount: 5_000) == 2)
    }

    @Test func stagedScanUsesSmallerInitialWindowsForRemovableVolumes() async throws {
        #expect(AppState.stagedScanInitialBatchSize(isRemovableVolume: true) == 48)
        #expect(AppState.stagedScanInitialBatchSize(isRemovableVolume: false) == 72)
        #expect(AppState.stagedScanBatchSize(isRemovableVolume: true) == 96)
        #expect(AppState.stagedScanBatchSize(isRemovableVolume: false) == 160)
    }

    @Test func thumbnailWarmupDelayIncreasesForLargeRemovableLibraries() async throws {
        #expect(AppState.thumbnailWarmupDelayNs(forAssetCount: 120, isRemovableVolume: false) == 120_000_000)
        #expect(AppState.thumbnailWarmupDelayNs(forAssetCount: 900, isRemovableVolume: true) == 650_000_000)
        #expect(AppState.thumbnailWarmupDelayNs(forAssetCount: 1_800, isRemovableVolume: false) == 320_000_000)
    }

    private func makeAssets(count: Int) -> [PhotoAsset] {
        (0..<count).map { index in
            PhotoAsset(url: URL(fileURLWithPath: "/tmp/latent-preload-\(index).jpg"))
        }
    }
}
