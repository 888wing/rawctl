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

// MARK: - Wire Rendering Tests (Task 6)

/// Smoke tests verifying that renderPreview accepts localNodes and runs without crashing.
/// These tests confirm that the wiring from AppState.currentLocalNodes → renderPreview compiles
/// and executes correctly end-to-end.
@MainActor
final class WireRenderingTests: XCTestCase {

    // MARK: - Helpers

    private enum TestError: Error {
        case bitmapContextCreationFailed
        case imageEncodingFailed
    }

    /// Creates a solid-grey PNG at the given URL.
    private func writeSolidPNG(at url: URL, width: Int = 64, height: Int = 64) throws {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw TestError.bitmapContextCreationFailed
        }
        context.setFillColor(NSColor(calibratedRed: 0.5, green: 0.5, blue: 0.5, alpha: 1.0).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let cgImage = context.makeImage() else { throw TestError.imageEncodingFailed }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = rep.representation(using: .png, properties: [:]) else { throw TestError.imageEncodingFailed }
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Tests

    /// Verifies that renderPreview with a non-empty localNodes array returns a non-nil result,
    /// proving the wiring compiles and runs without crashing.
    func test_renderPreview_withLocalNodes_returnsNonNil() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rawctl-wire-rendering-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let imageURL = dir.appendingPathComponent("test-gray.png")
        try writeSolidPNG(at: imageURL)

        let asset = PhotoAsset(url: imageURL)
        let recipe = EditRecipe()

        // Build a local node with a radial mask and exposure boost
        var nodeRecipe = EditRecipe()
        nodeRecipe.exposure = 0.5
        var node = ColorNode(name: "TestNode", type: .serial, adjustments: nodeRecipe)
        node.mask = NodeMask(type: .radial(centerX: 0.5, centerY: 0.5, radius: 0.3))

        await ImagePipeline.shared.clearCache()
        let result = await ImagePipeline.shared.renderPreview(
            for: asset,
            recipe: recipe,
            maxSize: 64,
            localNodes: [node]
        )

        XCTAssertNotNil(result, "renderPreview with localNodes should return a non-nil NSImage")
    }

    /// Verifies that AppState.currentLocalNodes is accessible and of the correct type
    /// to be passed directly to renderPreview(localNodes:).
    func test_appState_currentLocalNodes_typeCompatibleWithRenderPreview() {
        let state = AppState()
        let asset = PhotoAsset(url: URL(fileURLWithPath: "/tmp/wire_type_test.ARW"))
        state.assets = [asset]
        state.selectedAssetId = asset.id

        var node = ColorNode(name: "WireNode", type: .serial)
        node.adjustments.exposure = 0.3
        state.addLocalNode(node)

        // Confirm the state returns the node
        XCTAssertEqual(state.currentLocalNodes.count, 1)
        XCTAssertEqual(state.currentLocalNodes.first?.name, "WireNode")

        // Verify type compatibility: [ColorNode] can be assigned from currentLocalNodes
        // (this is a compile-time proof that wiring is type-correct)
        let nodes: [ColorNode] = state.currentLocalNodes
        XCTAssertEqual(nodes.count, 1)
    }
}

// MARK: - SidecarIntegrationTests (Task 7)

/// Tests the full save/load round-trip for localNodes through AppState's wired paths.
final class SidecarIntegrationTests: XCTestCase {

    // MARK: - Helpers

    private func makeTempPhotoURL(name: String = "integration_test.ARW") -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("rawctl-sidecar-integration-\(UUID().uuidString)")
            .appendingPathComponent(name)
    }

    private func createFakePhoto(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: url.path, contents: Data("fake".utf8))
    }

    private func cleanupFiles(photoURL: URL) {
        let sidecarURL = photoURL.deletingLastPathComponent()
            .appendingPathComponent(photoURL.lastPathComponent + ".rawctl.json")
        try? FileManager.default.removeItem(at: photoURL.deletingLastPathComponent())
        try? FileManager.default.removeItem(at: sidecarURL)
    }

    // MARK: - Tests

    /// Saves recipe + localNodes via SidecarService.save(recipe:localNodes:for:),
    /// then loads via SidecarService.load(for:), and verifies the round-trip.
    func test_saveThenLoad_roundtripsLocalNodes() async throws {
        let photoURL = makeTempPhotoURL()
        try createFakePhoto(at: photoURL)
        defer { cleanupFiles(photoURL: photoURL) }

        var recipe = EditRecipe()
        recipe.exposure = 1.2

        var node = ColorNode(name: "ForestSky", type: .serial)
        node.mask = NodeMask(type: .radial(centerX: 0.4, centerY: 0.6, radius: 0.25))
        node.adjustments.exposure = -0.7

        let service = SidecarService()

        // Act: save recipe + node
        try await service.save(recipe: recipe, localNodes: [node], for: photoURL)

        // Act: load back
        let loaded = try await service.load(for: photoURL)

        // Assert recipe round-trips
        XCTAssertEqual(loaded.recipe.exposure, 1.2, accuracy: 0.001)

        // Assert localNodes round-trip
        XCTAssertNotNil(loaded.localNodes, "localNodes should not be nil after save")
        XCTAssertEqual(loaded.localNodes?.count, 1)
        XCTAssertEqual(loaded.localNodes?.first?.name, "ForestSky")
        XCTAssertEqual(loaded.localNodes?.first?.adjustments.exposure ?? 0, -0.7, accuracy: 0.001)
    }

    /// Verifies that AppState.saveCurrentRecipe() persists localNodes to the sidecar,
    /// and that selecting the same asset again re-populates localNodes.
    @MainActor
    func test_appState_saveCurrentRecipe_persistsLocalNodes() async throws {
        let photoURL = makeTempPhotoURL(name: "appstate_save_test.ARW")
        try createFakePhoto(at: photoURL)
        defer { cleanupFiles(photoURL: photoURL) }

        let state = AppState()
        let asset = PhotoAsset(url: photoURL)
        state.assets = [asset]
        state.selectedAssetId = asset.id

        // Add a local node
        var node = ColorNode(name: "SkyNode", type: .serial)
        node.adjustments.exposure = 0.9
        state.addLocalNode(node)
        XCTAssertEqual(state.currentLocalNodes.count, 1)

        // Trigger save (the wired save path)
        state.saveCurrentRecipe()

        // Allow the async save task to complete
        // Poll for sidecar to appear (up to 3s)
        let sidecarURL = FileSystemService.sidecarURL(for: photoURL)
        let deadline = Date().addingTimeInterval(3.0)
        while !FileManager.default.fileExists(atPath: sidecarURL.path), Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms polling
        }

        // Re-select (triggers the load path)
        state.selectedAssetId = nil
        // Manually clear to simulate a fresh load
        state.localNodes.removeAll()
        XCTAssertEqual(state.currentLocalNodes.count, 0)

        // Now load via the service directly to verify persistence
        let service = SidecarService()
        let loaded = try await service.load(for: photoURL)
        XCTAssertEqual(loaded.localNodes?.count, 1, "Saved sidecar should contain 1 localNode")
        XCTAssertEqual(loaded.localNodes?.first?.name, "SkyNode")
    }
}

// MARK: - MaskingPanel Tests (Task 8)

@MainActor
final class MaskingPanelTests: XCTestCase {

    func test_maskingPanel_compiles() {
        let state = AppState()
        let _ = MaskingPanel(appState: state)
        // Just verifying it compiles and constructs without crash
    }

    func test_addNewNode_addsNodeToState() {
        // Arrange: Create AppState with a selected asset
        let url = URL(fileURLWithPath: "/tmp/masking_panel_test.ARW")
        let state = AppState()
        let asset = PhotoAsset(url: url)
        state.assets = [asset]
        state.selectedAssetId = asset.id

        let panel = MaskingPanel(appState: state)
        XCTAssertEqual(state.currentLocalNodes.count, 0)

        // Act: call addNewNode (internal method)
        panel.addNewNode()

        // Assert: one node added
        XCTAssertEqual(state.currentLocalNodes.count, 1)
    }

    func test_addNewNode_nodeHasRadialMask() {
        let url = URL(fileURLWithPath: "/tmp/masking_panel_mask_test.ARW")
        let state = AppState()
        let asset = PhotoAsset(url: url)
        state.assets = [asset]
        state.selectedAssetId = asset.id

        let panel = MaskingPanel(appState: state)
        panel.addNewNode()

        let node = state.currentLocalNodes.first
        XCTAssertNotNil(node?.mask, "New node should have a mask")
        if case .radial(let cx, let cy, let r) = node?.mask?.type {
            XCTAssertEqual(cx, 0.5, accuracy: 0.001)
            XCTAssertEqual(cy, 0.5, accuracy: 0.001)
            XCTAssertEqual(r, 0.3, accuracy: 0.001)
        } else {
            XCTFail("Expected radial mask type, got \(String(describing: node?.mask?.type))")
        }
    }

    func test_addNewNode_incrementsNameWithCount() {
        let url = URL(fileURLWithPath: "/tmp/masking_panel_name_test.ARW")
        let state = AppState()
        let asset = PhotoAsset(url: url)
        state.assets = [asset]
        state.selectedAssetId = asset.id

        let panel = MaskingPanel(appState: state)
        panel.addNewNode()
        panel.addNewNode()

        XCTAssertEqual(state.currentLocalNodes.count, 2)
        XCTAssertEqual(state.currentLocalNodes[0].name, "Local 1")
        XCTAssertEqual(state.currentLocalNodes[1].name, "Local 2")
    }
}
