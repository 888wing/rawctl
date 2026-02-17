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
}
