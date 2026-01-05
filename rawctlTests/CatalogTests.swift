//
//  CatalogTests.swift
//  rawctlTests
//
//  Tests for Catalog model
//

import Foundation
import Testing
@testable import rawctl

struct CatalogTests {

    @Test func catalogInitializesWithDefaults() async throws {
        let libraryPath = URL(fileURLWithPath: "/Users/test/Pictures/rawctl")
        let catalog = Catalog(libraryPath: libraryPath)

        #expect(catalog.version == 1)
        #expect(catalog.projects.isEmpty)
        #expect(catalog.smartCollections.count == 5) // Built-in collections
    }

    @Test func catalogAddsProject() async throws {
        let libraryPath = URL(fileURLWithPath: "/Users/test/Pictures/rawctl")
        var catalog = Catalog(libraryPath: libraryPath)

        let project = Project(name: "Test", shootDate: Date(), projectType: .portrait)
        catalog.addProject(project)

        #expect(catalog.projects.count == 1)
        #expect(catalog.projects.first?.name == "Test")
    }

    @Test func catalogGroupsProjectsByMonth() async throws {
        let libraryPath = URL(fileURLWithPath: "/Users/test/Pictures/rawctl")
        var catalog = Catalog(libraryPath: libraryPath)

        let jan = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 5))!
        let feb = Calendar.current.date(from: DateComponents(year: 2025, month: 2, day: 10))!

        catalog.addProject(Project(name: "Jan Project", shootDate: jan, projectType: .wedding))
        catalog.addProject(Project(name: "Feb Project", shootDate: feb, projectType: .portrait))

        let grouped = catalog.projectsByMonth
        #expect(grouped.count == 2)
    }
}
