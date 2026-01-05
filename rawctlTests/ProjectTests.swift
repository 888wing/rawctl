//
//  ProjectTests.swift
//  rawctlTests
//
//  Tests for Project model
//

import Foundation
import Testing
@testable import rawctl

struct ProjectTests {

    @Test func projectInitializesWithRequiredFields() async throws {
        let project = Project(
            name: "Wedding_2025-01-05",
            shootDate: Date(),
            projectType: .wedding
        )

        #expect(project.name == "Wedding_2025-01-05")
        #expect(project.projectType == .wedding)
        #expect(project.status == .importing)
        #expect(project.sourceFolders.isEmpty)
    }

    @Test func projectTypeHasCorrectCases() async throws {
        let allTypes: [ProjectType] = [.wedding, .portrait, .event, .landscape, .street, .product, .other]
        #expect(allTypes.count == 7)
    }

    @Test func projectStatusProgression() async throws {
        var project = Project(name: "Test", shootDate: Date(), projectType: .portrait)
        #expect(project.status == .importing)

        project.status = .culling
        #expect(project.status == .culling)

        project.status = .editing
        #expect(project.status == .editing)
    }
}
