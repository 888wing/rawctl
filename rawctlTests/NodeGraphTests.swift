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
        XCTAssertEqual(sidecar.schemaVersion, 5)
    }

    func test_sidecarFile_encodesAndDecodesLocalNodes() throws {
        var node = ColorNode(name: "Brighten Face", type: .serial)
        node.mask = NodeMask(type: .radial(centerX: 0.5, centerY: 0.3, radius: 0.2))
        node.adjustments.exposure = 0.8

        let url = URL(fileURLWithPath: "/tmp/test.ARW")
        var sidecar = SidecarFile(for: url, recipe: EditRecipe())
        sidecar.localNodes = [node]

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(sidecar)
        let jsonString = String(data: data, encoding: .utf8)!
        XCTAssertTrue(jsonString.contains("\"schemaVersion\" : 6"), "Expected schemaVersion 6 in JSON, got: \(jsonString)")
        let decoded = try JSONDecoder().decode(SidecarFile.self, from: data)
        XCTAssertEqual(decoded.schemaVersion, 6)
        XCTAssertNotNil(decoded.localNodes)
        XCTAssertEqual(decoded.localNodes?.count, 1)
        XCTAssertEqual(decoded.localNodes?.first?.name, "Brighten Face")
        XCTAssertEqual(decoded.localNodes?.first?.adjustments.exposure, 0.8)
    }

    // MARK: - SidecarService v6

    func test_sidecarService_roundtrip_localNodes() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
        let fakePhotoURL = tmpDir.appendingPathComponent("svc_roundtrip_test.ARW")
        FileManager.default.createFile(atPath: fakePhotoURL.path, contents: Data("fake".utf8))
        let sidecarURL = fakePhotoURL.deletingLastPathComponent()
            .appendingPathComponent(fakePhotoURL.lastPathComponent + ".rawctl.json")
        defer {
            try? FileManager.default.removeItem(at: fakePhotoURL)
            try? FileManager.default.removeItem(at: sidecarURL)
        }

        var recipe = EditRecipe()
        recipe.exposure = 0.5

        var node = ColorNode(name: "Sky", type: .serial)
        node.mask = NodeMask(type: .linear(angle: 0, position: 0.3, falloff: 0.4))
        node.adjustments.exposure = -0.5

        // Save with localNodes
        let service = SidecarService()
        try await service.save(recipe: recipe, localNodes: [node], for: fakePhotoURL)

        // Load
        let loaded = try await service.load(for: fakePhotoURL)
        XCTAssertEqual(loaded.recipe.exposure, 0.5)
        XCTAssertEqual(loaded.localNodes?.count, 1)
        XCTAssertEqual(loaded.localNodes?.first?.name, "Sky")
        XCTAssertEqual(loaded.localNodes?.first?.adjustments.exposure, -0.5)
    }
}

// MARK: - AppState Local Nodes

@MainActor
final class AppStateLocalNodesTests: XCTestCase {

    private func makeState(withURL url: URL) -> AppState {
        let state = AppState()
        // Insert a fake PhotoAsset so selectedAsset returns something with the given URL
        let asset = PhotoAsset(url: url)
        state.assets = [asset]
        state.selectedAssetId = asset.id
        return state
    }

    func test_addLocalNode_appendsToCurrentPhoto() {
        let url = URL(fileURLWithPath: "/tmp/test_add.ARW")
        let state = makeState(withURL: url)

        let node = ColorNode(name: "Brighten", type: .serial)
        state.addLocalNode(node)

        XCTAssertEqual(state.currentLocalNodes.count, 1)
        XCTAssertEqual(state.currentLocalNodes.first?.name, "Brighten")
    }

    func test_removeLocalNode_removesById() {
        let url = URL(fileURLWithPath: "/tmp/test_remove.ARW")
        let state = makeState(withURL: url)

        let node1 = ColorNode(name: "Node A", type: .serial)
        let node2 = ColorNode(name: "Node B", type: .serial)
        state.addLocalNode(node1)
        state.addLocalNode(node2)

        state.removeLocalNode(id: node1.id)

        XCTAssertEqual(state.currentLocalNodes.count, 1)
        XCTAssertEqual(state.currentLocalNodes.first?.name, "Node B")
    }

    func test_updateLocalNode_replacesExistingNode() {
        let url = URL(fileURLWithPath: "/tmp/test_update.ARW")
        let state = makeState(withURL: url)

        var node = ColorNode(name: "Original", type: .serial)
        state.addLocalNode(node)

        node.name = "Updated"
        node.adjustments.exposure = 1.5
        state.updateLocalNode(node)

        XCTAssertEqual(state.currentLocalNodes.count, 1)
        XCTAssertEqual(state.currentLocalNodes.first?.name, "Updated")
        XCTAssertEqual(state.currentLocalNodes.first?.adjustments.exposure, 1.5)
    }

    func test_currentLocalNodes_returnsEmptyWhenNoPhoto() {
        let state = AppState()
        // No selected asset
        XCTAssertEqual(state.currentLocalNodes.count, 0)
    }

    func test_showMaskOverlay_defaultsFalse() {
        let state = AppState()
        XCTAssertFalse(state.showMaskOverlay)
    }
}
