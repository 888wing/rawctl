//
//  CatalogServiceTests.swift
//  rawctlTests
//
//  Tests for CatalogService persistence
//

import Foundation
import Testing
@testable import rawctl

struct CatalogServiceTests {

    @Test func catalogServiceSavesAndLoads() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let catalogPath = tempDir.appendingPathComponent("rawctl-catalog.json")
        let service = CatalogService(catalogPath: catalogPath)

        var catalog = Catalog(libraryPath: tempDir)
        catalog.addProject(Project(name: "Test Project", shootDate: Date(), projectType: .portrait))

        try await service.save(catalog)

        let loaded = try await service.load()
        #expect(loaded != nil)
        #expect(loaded?.projects.count == 1)
        #expect(loaded?.projects.first?.name == "Test Project")
    }

    @Test func catalogServiceCreatesNewIfMissing() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let catalogPath = tempDir.appendingPathComponent("missing-catalog.json")
        let service = CatalogService(catalogPath: catalogPath)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let catalog = try await service.loadOrCreate(libraryPath: tempDir)

        #expect(catalog.version == Catalog.currentVersion)
        #expect(catalog.libraryPath == tempDir)
    }
}
