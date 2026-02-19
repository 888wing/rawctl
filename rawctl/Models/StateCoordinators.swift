//
//  StateCoordinators.swift
//  rawctl
//
//  Focused state coordinators used by AppState facade.
//

import Foundation

@MainActor
final class SelectionCoordinator {
    private unowned let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func ensurePrimarySelection() -> Bool {
        if appState.selectedAssetId != nil {
            return true
        }

        if let first = appState.filteredAssets.first ?? appState.assets.first {
            appState.select(first, switchToSingleView: false)
            return true
        }

        return false
    }

    func switchToSingleViewIfPossible(showFeedback: Bool = true) -> Bool {
        guard ensurePrimarySelection() else {
            appState.viewMode = .grid
            if showFeedback {
                appState.showHUD("No photo selected")
            }
            return false
        }

        appState.viewMode = .single
        return true
    }

    func toggleSelection(_ assetId: UUID) {
        if appState.selectedAssetIds.contains(assetId) {
            appState.selectedAssetIds.remove(assetId)
            appState.selectedAssetId = appState.selectedAssetIds.first
        } else {
            appState.selectedAssetIds.insert(assetId)
            appState.selectedAssetId = assetId
        }
    }

    func extendSelection(to assetId: UUID) {
        guard let currentId = appState.selectedAssetId,
              let currentIndex = appState.filteredAssets.firstIndex(where: { $0.id == currentId }),
              let targetIndex = appState.filteredAssets.firstIndex(where: { $0.id == assetId }) else {
            appState.selectedAssetId = assetId
            appState.selectedAssetIds = [assetId]
            return
        }

        let start = min(currentIndex, targetIndex)
        let end = max(currentIndex, targetIndex)
        for index in start...end {
            appState.selectedAssetIds.insert(appState.filteredAssets[index].id)
        }
        appState.selectedAssetId = assetId
    }

    func clearMultiSelection() {
        appState.selectedAssetIds.removeAll()
    }

    func selectAll() {
        appState.selectedAssetIds = Set(appState.filteredAssets.map(\.id))
        appState.selectedAssetId = appState.filteredAssets.first?.id
    }

    func clearSelection() {
        appState.flushPendingRecipeSave()
        appState.selectedAssetId = nil
        appState.editingMaskId = nil
        appState.showMaskOverlay = false
        appState.viewMode = .grid
        appState.comparisonMode = .none
        appState.isZoomed = false
    }
}

@MainActor
final class EditStateCoordinator {
    private unowned let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func addLocalNode(_ node: ColorNode) {
        guard let url = appState.selectedAsset?.url else { return }
        var nodes = appState.localNodes[url] ?? []
        nodes.append(node)
        appState.localNodes[url] = nodes
        appState.saveCurrentRecipeDebounced()
    }

    func removeLocalNode(id: UUID) {
        guard let url = appState.selectedAsset?.url else { return }
        appState.localNodes[url]?.removeAll { $0.id == id }
        if appState.editingMaskId == id {
            appState.editingMaskId = nil
            appState.showMaskOverlay = false
        }
        appState.saveCurrentRecipeDebounced()
    }

    func updateLocalNode(_ node: ColorNode) {
        guard let url = appState.selectedAsset?.url else { return }
        guard let index = appState.localNodes[url]?.firstIndex(where: { $0.id == node.id }) else { return }
        appState.localNodes[url]?[index] = node
        appState.saveCurrentRecipeDebounced()
    }
}

@MainActor
final class LibrarySyncCoordinator {
    private unowned let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func clearProjectSelection() {
        appState.selectedProject = nil
        appState.activeSmartCollection = nil
        appState.isRecentImportsMode = false
    }

    func applySmartCollection(_ collection: SmartCollection?) {
        appState.activeSmartCollection = collection
        appState.isRecentImportsMode = false
        if collection != nil {
            appState.filterRating = 0
            appState.filterColor = nil
            appState.filterFlag = nil
            appState.filterTag = ""
        }
    }

    func applyRecentImportsFilter(days: Int = 7) {
        appState.recentImportsWindowDays = max(1, days)
        appState.isRecentImportsMode = true
        appState.activeSmartCollection = nil
    }

    func showAllPhotosInLibrary() {
        appState.isRecentImportsMode = false
        clearProjectSelection()
    }
}
