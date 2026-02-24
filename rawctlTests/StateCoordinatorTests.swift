//
//  StateCoordinatorTests.swift
//  rawctlTests
//
//  Regression coverage for Selection/Edit/Library coordinators behind AppState.
//

import Foundation
import Testing
@testable import Latent

@MainActor
struct StateCoordinatorTests {
    @Test func selectionCoordinatorHandlesToggleRangeAndClear() async throws {
        let appState = AppState()
        appState.sortCriteria = .filename
        appState.sortOrder = .ascending
        appState.assets = makeAssets(count: 6)

        appState.selectedAssetId = appState.assets[1].id
        appState.selectedAssetIds = [appState.assets[1].id]

        appState.toggleSelection(appState.assets[3].id)
        #expect(appState.selectedAssetIds.contains(appState.assets[3].id))
        #expect(appState.selectedAssetId == appState.assets[3].id)

        appState.extendSelection(to: appState.assets[5].id)
        #expect(appState.selectedAssetIds.contains(appState.assets[4].id))
        #expect(appState.selectedAssetIds.contains(appState.assets[5].id))
        #expect(appState.selectedAssetId == appState.assets[5].id)

        appState.clearSelection()
        #expect(appState.selectedAssetId == nil)
        #expect(appState.viewMode == .grid)
        #expect(appState.comparisonMode == .none)
        #expect(appState.isZoomed == false)
    }

    @Test func editStateCoordinatorMutatesLocalNodesAndMaskState() async throws {
        let appState = AppState()
        let asset = PhotoAsset(url: URL(fileURLWithPath: "/tmp/latent-node-asset.jpg"))
        appState.assets = [asset]
        appState.selectedAssetId = asset.id

        var node = ColorNode(name: "Mask", type: .serial)
        node.adjustments.exposure = 0.5
        appState.addLocalNode(node)
        #expect((appState.localNodes[asset.url] ?? []).count == 1)

        node.adjustments.exposure = 1.2
        appState.updateLocalNode(node)
        #expect((appState.localNodes[asset.url] ?? []).first?.adjustments.exposure == 1.2)

        appState.editingMaskId = node.id
        appState.showMaskOverlay = true
        appState.removeLocalNode(id: node.id)
        #expect((appState.localNodes[asset.url] ?? []).isEmpty)
        #expect(appState.editingMaskId == nil)
        #expect(appState.showMaskOverlay == false)
    }

    @Test func librarySyncCoordinatorTransitionsLibraryModes() async throws {
        let appState = AppState()

        appState.applyRecentImportsFilter(days: 3)
        #expect(appState.isRecentImportsMode == true)
        #expect(appState.activeSmartCollection == nil)

        appState.applySmartCollection(.fiveStars)
        #expect(appState.activeSmartCollection?.id == SmartCollection.fiveStars.id)
        #expect(appState.isRecentImportsMode == false)

        appState.showAllPhotosInLibrary()
        #expect(appState.isRecentImportsMode == false)
        #expect(appState.activeSmartCollection == nil)
        #expect(appState.selectedProject == nil)
    }

    private func makeAssets(count: Int) -> [PhotoAsset] {
        (0..<count).map { index in
            let filename = String(format: "latent-%03d.jpg", index)
            return PhotoAsset(url: URL(fileURLWithPath: "/tmp/\(filename)"))
        }
    }
}
