//
//  NodeGraphTests.swift
//  rawctlTests
//
//  Tests for NodeMask density field and node graph functionality
//

import XCTest
@testable import rawctl

final class NodeGraphTests: XCTestCase {

    // MARK: - NodeMask

    func test_nodeMask_defaultDensity_is100() {
        let mask = NodeMask(type: .radial(centerX: 0.5, centerY: 0.5, radius: 0.3))
        XCTAssertEqual(mask.density, 100.0)
    }

    func test_nodeMask_invertDefaultsFalse() {
        let mask = NodeMask(type: .linear(angle: 0, position: 0.5, falloff: 0.3))
        XCTAssertFalse(mask.invert)
    }

    func test_nodeMask_codableRoundtrip_preservesDensity() throws {
        var mask = NodeMask(type: .radial(centerX: 0.5, centerY: 0.5, radius: 0.3))
        mask.density = 75.0
        mask.feather = 30.0
        let data = try JSONEncoder().encode(mask)
        let decoded = try JSONDecoder().decode(NodeMask.self, from: data)
        XCTAssertEqual(decoded.density, 75.0)
        XCTAssertEqual(decoded.feather, 30.0)
    }

    // MARK: - SidecarFile v6

    func test_sidecarFile_decodesLegacyV5_withoutLocalNodes() throws {
        let json = """
        {
          "schemaVersion": 5,
          "asset": { "originalFilename": "IMG_001.ARW", "fileSize": 1024, "modifiedTime": 0 },
          "edit": { "exposure": 0.5 },
          "updatedAt": 1234567890
        }
        """.data(using: .utf8)!
        let sidecar = try JSONDecoder().decode(SidecarFile.self, from: json)
        XCTAssertNil(sidecar.localNodes)
        XCTAssertEqual(sidecar.edit.exposure, 0.5)
    }

    func test_sidecarFile_encodesAndDecodesLocalNodes() throws {
        var node = ColorNode(name: "Brighten Face", type: .serial)
        node.mask = NodeMask(type: .radial(centerX: 0.5, centerY: 0.3, radius: 0.2))
        node.adjustments.exposure = 0.8

        let url = URL(fileURLWithPath: "/tmp/test.ARW")
        var sidecar = SidecarFile(for: url, recipe: EditRecipe())
        sidecar.localNodes = [node]

        let data = try JSONEncoder().encode(sidecar)
        let decoded = try JSONDecoder().decode(SidecarFile.self, from: data)
        XCTAssertNotNil(decoded.localNodes)
        XCTAssertEqual(decoded.localNodes?.count, 1)
        XCTAssertEqual(decoded.localNodes?.first?.name, "Brighten Face")
        XCTAssertEqual(decoded.localNodes?.first?.adjustments.exposure, 0.8)
    }
}
