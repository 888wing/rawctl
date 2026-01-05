//
//  AppStateCatalogTests.swift
//  rawctlTests
//
//  Tests for AppState catalog integration
//

import Foundation
import Testing
@testable import rawctl

@MainActor
struct AppStateCatalogTests {

    @Test func appStateInitializesWithCatalog() async throws {
        let appState = AppState()

        // Initially nil until loaded
        #expect(appState.catalog == nil)
        #expect(appState.selectedProject == nil)
    }

    @Test func appStateSelectsProject() async throws {
        let appState = AppState()

        let libraryPath = URL(fileURLWithPath: "/tmp/test-library")
        var catalog = Catalog(libraryPath: libraryPath)
        let project = Project(name: "Test", shootDate: Date(), projectType: .portrait)
        catalog.addProject(project)

        appState.catalog = catalog
        appState.selectedProject = project

        #expect(appState.selectedProject?.name == "Test")
        #expect(appState.isProjectMode == true)
    }

    @Test func appStateFiltersAssetsForSmartCollection() async throws {
        let appState = AppState()

        // Add test assets
        let asset1 = PhotoAsset(url: URL(fileURLWithPath: "/tmp/photo1.arw"))
        let asset2 = PhotoAsset(url: URL(fileURLWithPath: "/tmp/photo2.arw"))
        appState.assets = [asset1, asset2]

        // Set up recipes
        var recipe1 = EditRecipe()
        recipe1.rating = 5
        appState.recipes[asset1.id] = recipe1

        // Apply 5-star filter
        appState.activeSmartCollection = .fiveStars

        #expect(appState.smartFilteredAssets.count == 1)
        #expect(appState.smartFilteredAssets.first?.id == asset1.id)
    }
}
