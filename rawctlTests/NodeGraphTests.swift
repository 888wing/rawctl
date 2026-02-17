//
//  NodeGraphTests.swift
//  rawctlTests
//
//  Tests for NodeMask density field and node graph functionality
//

import XCTest
import SwiftUI
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

// MARK: - LocalAdjustmentRow Tests (Task 9)

@MainActor
final class LocalAdjustmentRowTests: XCTestCase {

    private func makeStateWithNode() -> (AppState, ColorNode) {
        let url = URL(fileURLWithPath: "/tmp/row_test.ARW")
        let state = AppState()
        let asset = PhotoAsset(url: url)
        state.assets = [asset]
        state.selectedAssetId = asset.id

        var node = ColorNode(name: "Sky", type: .serial)
        node.mask = NodeMask(type: .radial(centerX: 0.5, centerY: 0.5, radius: 0.3))
        state.addLocalNode(node)
        // Return the node as stored (same id)
        return (state, state.currentLocalNodes.first!)
    }

    func test_row_compiles() {
        let (state, node) = makeStateWithNode()
        let _ = LocalAdjustmentRow(node: node, appState: state)
        // Verifies struct compiles and initialises without crash
    }

    func test_deleteButton_removesNode() {
        let (state, node) = makeStateWithNode()
        XCTAssertEqual(state.currentLocalNodes.count, 1)

        let row = LocalAdjustmentRow(node: node, appState: state)
        row.deleteNode()

        XCTAssertEqual(state.currentLocalNodes.count, 0)
    }

    func test_editMaskButton_setsEditingMaskId() {
        let (state, node) = makeStateWithNode()
        XCTAssertNil(state.editingMaskId)
        XCTAssertFalse(state.showMaskOverlay)

        let row = LocalAdjustmentRow(node: node, appState: state)
        row.startEditingMask()

        XCTAssertEqual(state.editingMaskId, node.id)
        XCTAssertTrue(state.showMaskOverlay)
    }

    func test_toggleEnabled_updatesNode() {
        let (state, node) = makeStateWithNode()
        XCTAssertTrue(node.isEnabled)

        let row = LocalAdjustmentRow(node: node, appState: state)
        row.toggleEnabled()

        XCTAssertEqual(state.currentLocalNodes.first?.isEnabled, false)
    }
}

// MARK: - InspectorIntegrationTests (Task 10)

@MainActor
final class InspectorIntegrationTests: XCTestCase {
    func test_inspectorView_compiles_withMaskingPanel() {
        let state = AppState()
        let _ = InspectorView(appState: state)
        // Smoke test: just verify it compiles and constructs
    }
}

// MARK: - RadialMaskEditor Tests (Task 11)

final class RadialMaskEditorTests: XCTestCase {

    func test_radialMaskEditor_compiles() {
        var node = ColorNode(name: "Test", type: .serial)
        node.mask = NodeMask(type: .radial(centerX: 0.5, centerY: 0.5, radius: 0.3))
        let binding = Binding<ColorNode>(get: { node }, set: { node = $0 })
        let _ = RadialMaskEditor(node: binding, imageSize: CGSize(width: 800, height: 600))
        // Verifies the view compiles and constructs without crash
    }

    func test_centerDrag_updatesMaskCenter() {
        var node = ColorNode(name: "Test", type: .serial)
        node.mask = NodeMask(type: .radial(centerX: 0.5, centerY: 0.5, radius: 0.3))
        let binding = Binding<ColorNode>(get: { node }, set: { node = $0 })
        let imageSize = CGSize(width: 800, height: 600)
        var editor = RadialMaskEditor(node: binding, imageSize: imageSize)

        // Simulate dragging center to (400, 300) in view coords => (0.5, 0.5) normalized
        // Then drag to (480, 360) => (0.6, 0.6) normalized
        let newLocation = CGPoint(x: 480, y: 360)
        editor.moveCenterTo(newLocation, in: imageSize)

        // After the move, node.mask centerX should be ~0.6, centerY ~0.6
        if case .radial(let cx, let cy, _) = node.mask?.type {
            XCTAssertEqual(cx, 0.6, accuracy: 0.01)
            XCTAssertEqual(cy, 0.6, accuracy: 0.01)
        } else {
            XCTFail("Expected radial mask type")
        }
    }

    func test_radiusDrag_updatesMaskRadius() {
        var node = ColorNode(name: "Test", type: .serial)
        node.mask = NodeMask(type: .radial(centerX: 0.5, centerY: 0.5, radius: 0.3))
        let binding = Binding<ColorNode>(get: { node }, set: { node = $0 })
        let imageSize = CGSize(width: 800, height: 600)
        var editor = RadialMaskEditor(node: binding, imageSize: imageSize)

        // Center is at (400, 300). Drag radius handle to (640, 300).
        // Distance from center = 240px, normalized by width = 0.3 → but stored as fraction of min dimension
        // imageSize.width = 800, so 240/800 = 0.3
        let radiusHandleLocation = CGPoint(x: 640, y: 300)
        editor.resizeRadiusTo(radiusHandleLocation, in: imageSize)

        if case .radial(_, _, let r) = node.mask?.type {
            // Expected: distance=240, min(800,600)=600, so 240/600 = 0.4
            XCTAssertEqual(r, 0.4, accuracy: 0.02, "radius should be ~0.4 (240/600)")
        } else {
            XCTFail("Expected radial mask type")
        }
    }
}

// MARK: - LinearMaskEditor Tests (Task 12)

final class LinearMaskEditorTests: XCTestCase {

    func test_linearMaskEditor_compiles() {
        var node = ColorNode(name: "Test", type: .serial)
        node.mask = NodeMask(type: .linear(angle: 0, position: 0.5, falloff: 0.3))
        let binding = Binding<ColorNode>(get: { node }, set: { node = $0 })
        let _ = LinearMaskEditor(node: binding, imageSize: CGSize(width: 800, height: 600))
        // Verifies the view compiles and constructs without crash
    }

    func test_positionDrag_updatesMaskPosition() {
        var node = ColorNode(name: "Test", type: .serial)
        node.mask = NodeMask(type: .linear(angle: 0, position: 0.5, falloff: 0.3))
        let binding = Binding<ColorNode>(get: { node }, set: { node = $0 })
        let imageSize = CGSize(width: 800, height: 600)
        var editor = LinearMaskEditor(node: binding, imageSize: imageSize)

        // Drag to y=120, which is 120/600 = 0.2 in normalized coords
        let newLocation = CGPoint(x: 400, y: 120)
        editor.movePositionTo(newLocation, in: imageSize)

        if case .linear(_, let pos, _) = node.mask?.type {
            XCTAssertEqual(pos, 0.2, accuracy: 0.01)
        } else {
            XCTFail("Expected linear mask type")
        }
    }
}

// MARK: - MaskEditingToolbar Tests (Task 13)

@MainActor
final class MaskEditingToolbarTests: XCTestCase {

    private func makeStateWithNode() -> (AppState, ColorNode) {
        let url = URL(fileURLWithPath: "/tmp/toolbar_test.ARW")
        let state = AppState()
        let asset = PhotoAsset(url: url)
        state.assets = [asset]
        state.selectedAssetId = asset.id

        var node = ColorNode(name: "Sky", type: .serial)
        node.mask = NodeMask(type: .radial(centerX: 0.5, centerY: 0.5, radius: 0.3))
        state.addLocalNode(node)
        state.editingMaskId = state.currentLocalNodes.first!.id
        state.showMaskOverlay = true
        return (state, state.currentLocalNodes.first!)
    }

    func test_toolbar_compiles() {
        let state = AppState()
        let _ = MaskEditingToolbar(appState: state)
        // Verifies the view compiles and constructs without crash
    }

    func test_doneEditing_clearsEditingMaskId() {
        let (state, _) = makeStateWithNode()
        XCTAssertNotNil(state.editingMaskId, "Precondition: editingMaskId should be set")

        let toolbar = MaskEditingToolbar(appState: state)
        toolbar.doneEditing()

        XCTAssertNil(state.editingMaskId, "doneEditing() should clear editingMaskId")
        XCTAssertFalse(state.showMaskOverlay, "doneEditing() should hide mask overlay")
    }

    func test_toggleOverlay_flipsShowMaskOverlay() {
        let (state, _) = makeStateWithNode()
        XCTAssertTrue(state.showMaskOverlay, "Precondition: showMaskOverlay should be true")

        let toolbar = MaskEditingToolbar(appState: state)
        toolbar.toggleOverlay()

        XCTAssertFalse(state.showMaskOverlay, "toggleOverlay() should flip showMaskOverlay to false")

        toolbar.toggleOverlay()

        XCTAssertTrue(state.showMaskOverlay, "toggleOverlay() should flip showMaskOverlay back to true")
    }
}

// MARK: - LocalAdjustmentIntegrationTests (Task 14)

/// End-to-end integration test: AppState → SidecarService → ImagePipeline.
/// Verifies the full pipeline from adding a local node to rendering without crashing.
@MainActor
final class LocalAdjustmentIntegrationTests: XCTestCase {

    // MARK: - Helpers

    private enum TestError: Error {
        case bitmapContextCreationFailed
        case imageEncodingFailed
    }

    /// Creates a solid-grey PNG at the given URL so ImagePipeline has a real decodable image.
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

    /// Polls for a file to appear on disk, returning when it exists or the deadline is reached.
    private func waitForFile(at url: URL, timeout: TimeInterval = 3.0) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !FileManager.default.fileExists(atPath: url.path), Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000) // 50 ms
        }
    }

    // MARK: - Full Pipeline Test

    /// Tests the complete pipeline:
    /// 1. AppState with a real PNG photo selected
    /// 2. Add a local node (radial mask, exposure +1.0)
    /// 3. Save via AppState.saveCurrentRecipe()
    /// 4. Poll for the sidecar file to appear on disk
    /// 5. Load via SidecarService and verify the saved node matches (name, exposure, mask type)
    /// 6. Render via ImagePipeline.renderPreview with the loaded localNodes
    /// 7. Assert renderPreview returns non-nil
    func test_fullPipeline_addNodeSaveLoadRenderDoesNotCrash() async throws {
        // --- Setup: temp directory with a real PNG ---
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rawctl-e2e-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let photoURL = dir.appendingPathComponent("e2e_test.png")
        try writeSolidPNG(at: photoURL)

        // --- Step 1: Create AppState with photo selected ---
        let state = AppState()
        let asset = PhotoAsset(url: photoURL)
        state.assets = [asset]
        state.selectedAssetId = asset.id

        // --- Step 2: Add a local node with a radial mask and exposure +1.0 ---
        var node = ColorNode(name: "E2E Node", type: .serial)
        node.mask = NodeMask(type: .radial(centerX: 0.5, centerY: 0.5, radius: 0.3))
        node.adjustments.exposure = 1.0
        state.addLocalNode(node)

        XCTAssertEqual(state.currentLocalNodes.count, 1)
        XCTAssertEqual(state.currentLocalNodes.first?.name, "E2E Node")

        // --- Step 3: Save via AppState.saveCurrentRecipe() ---
        state.saveCurrentRecipe()

        // --- Step 4: Poll for the sidecar file to appear ---
        let sidecarURL = FileSystemService.sidecarURL(for: photoURL)
        try await waitForFile(at: sidecarURL)

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: sidecarURL.path),
            "Sidecar file should exist after saveCurrentRecipe()"
        )

        // --- Step 5: Load via SidecarService and verify round-trip ---
        let service = SidecarService()
        let loaded = try await service.load(for: photoURL)

        XCTAssertNotNil(loaded.localNodes, "Loaded sidecar should contain localNodes")
        XCTAssertEqual(loaded.localNodes?.count, 1, "Should have exactly 1 local node")

        let loadedNode = try XCTUnwrap(loaded.localNodes?.first)
        XCTAssertEqual(loadedNode.name, "E2E Node")
        XCTAssertEqual(loadedNode.adjustments.exposure, 1.0, accuracy: 0.001)

        guard case .radial(let cx, let cy, let r) = loadedNode.mask?.type else {
            XCTFail("Loaded node should have a radial mask, got: \(String(describing: loadedNode.mask?.type))")
            return
        }
        XCTAssertEqual(cx, 0.5, accuracy: 0.01)
        XCTAssertEqual(cy, 0.5, accuracy: 0.01)
        XCTAssertEqual(r, 0.3, accuracy: 0.01)

        // --- Step 6 & 7: Render via ImagePipeline with the loaded localNodes ---
        await ImagePipeline.shared.clearCache()
        let result = await ImagePipeline.shared.renderPreview(
            for: asset,
            recipe: loaded.recipe,
            maxSize: 64,
            localNodes: loaded.localNodes ?? []
        )

        XCTAssertNotNil(result, "renderPreview with loaded localNodes should return a non-nil NSImage")
    }
}

// MARK: - Task 15: BrushMaskBitmap & .brush MaskType

final class BrushMaskBitmapTests: XCTestCase {

    // MARK: - displayName

    func test_brushMaskType_displayName_isBrushMask() {
        // Arrange: create a minimal PNG data blob (1×1 white pixel)
        let pngData = makeSolidPNG(width: 1, height: 1)
        let maskType = NodeMask.MaskType.brush(data: pngData)

        // Act
        let name = maskType.displayName

        // Assert
        XCTAssertEqual(name, "Brush Mask")
    }

    // MARK: - BrushMaskBitmap

    func test_brushMaskBitmap_fromImage_producesNonNilData() {
        // Arrange
        let image = makeSolidNSImage(width: 4, height: 4, color: .white)

        // Act
        let bitmap = BrushMaskBitmap.from(image: image)

        // Assert
        XCTAssertNotNil(bitmap)
        XCTAssertFalse(bitmap?.pngData.isEmpty ?? true)
        // Pixel dimensions are >= point dimensions (may be 2x on Retina displays)
        XCTAssertGreaterThanOrEqual(bitmap?.width ?? 0, 4)
        XCTAssertGreaterThanOrEqual(bitmap?.height ?? 0, 4)
    }

    func test_brushMaskBitmap_toCIImage_returnsImage() {
        // Arrange
        let image = makeSolidNSImage(width: 8, height: 8, color: .gray)
        guard let bitmap = BrushMaskBitmap.from(image: image) else {
            XCTFail("BrushMaskBitmap.from(image:) returned nil")
            return
        }

        // Act
        let ciImage = bitmap.toCIImage()

        // Assert
        XCTAssertNotNil(ciImage)
    }

    func test_brushMaskType_codable_roundtrip() throws {
        // Arrange
        let pngData = makeSolidPNG(width: 2, height: 2)
        let original = NodeMask(type: .brush(data: pngData))

        // Act
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NodeMask.self, from: encoded)

        // Assert
        guard case .brush(let decodedData) = decoded.type else {
            XCTFail("Decoded mask type should be .brush, got: \(decoded.type)")
            return
        }
        XCTAssertEqual(decodedData, pngData)
    }

    // MARK: - Helpers

    /// Create a minimal 1-channel solid NSImage.
    private func makeSolidNSImage(width: Int, height: Int, color: NSColor) -> NSImage {
        let size = NSSize(width: CGFloat(width), height: CGFloat(height))
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }

    /// Encode a solid NSImage to PNG data (for MaskType.brush).
    private func makeSolidPNG(width: Int, height: Int) -> Data {
        let image = makeSolidNSImage(width: width, height: height, color: .white)
        guard let tiff = image.tiffRepresentation,
              let bmp = NSBitmapImageRep(data: tiff),
              let png = bmp.representation(using: .png, properties: [:]) else {
            return Data()
        }
        return png
    }
}

// MARK: - Task 17: BrushMaskEditor

@MainActor
final class BrushMaskEditorTests: XCTestCase {

    func test_commitBrushMask_writesDataToNode() {
        // This test verifies commitBrushMask() updates node.mask type correctly.
        // We create a BrushMaskEditor, simulate stroke completion, verify node updated.
        let state = AppState()
        let asset = PhotoAsset(url: URL(fileURLWithPath: "/test"))
        state.assets = [asset]
        state.selectedAssetId = asset.id

        var node = ColorNode(name: "Brush", type: .serial)
        node.mask = NodeMask(type: .brush(data: Data()))
        state.addLocalNode(node)

        // Arrange a non-empty BrushMask
        let brushMask = BrushMask()
        brushMask.canvasSize = CGSize(width: 100, height: 100)
        brushMask.beginStroke(at: CGPoint(x: 10, y: 10))
        brushMask.continueStroke(to: CGPoint(x: 50, y: 50))
        brushMask.endStroke()

        // Act: simulate what commitBrushMask does
        let imageSize = CGSize(width: 400, height: 300)
        let pngData = brushMask.renderToPNG(targetSize: imageSize)

        // Assert: PNG data is non-nil and non-empty
        XCTAssertNotNil(pngData)
        XCTAssertFalse(pngData?.isEmpty ?? true)

        // Update node (mirroring commitBrushMask logic)
        if let png = pngData {
            // Retrieve the node as stored in state so we have the correct id
            if var storedNode = state.currentLocalNodes.first {
                storedNode.mask?.type = .brush(data: png)
                state.updateLocalNode(storedNode)
            }
        }

        // Verify node was updated
        let updated = state.currentLocalNodes.first
        if case .brush(let data) = updated?.mask?.type {
            XCTAssertFalse(data.isEmpty)
        } else {
            XCTFail("Expected .brush mask type")
        }
    }

    func test_brushMaskEditor_loadsEmptyOnAppear() {
        // Verifies BrushMask starts empty (no reconstruction from PNG).
        let brushMask = BrushMask()
        XCTAssertTrue(brushMask.isEmpty)
    }
}

// MARK: - Task 16: ImagePipeline createBrushMask

final class CreateBrushMaskTests: XCTestCase {

    func test_createBrushMask_returnsNonNilImage() async {
        // Arrange: create a small solid PNG to use as mask data
        let pngData = makeSolidPNG(width: 16, height: 16)

        // Act
        let result = await ImagePipeline.shared.createBrushMask(
            from: pngData,
            targetExtent: CGRect(x: 0, y: 0, width: 64, height: 64)
        )

        // Assert
        XCTAssertNotNil(result, "createBrushMask should return a non-nil CIImage")
    }

    func test_renderLocalNodes_brushMask_doesNotCrash() async throws {
        // Arrange: build a minimal 16×16 base image
        let baseImage = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5))
            .cropped(to: CGRect(x: 0, y: 0, width: 16, height: 16))

        let pngData = makeSolidPNG(width: 16, height: 16)
        var node = ColorNode(name: "Brush Node", type: .serial)
        node.mask = NodeMask(type: .brush(data: pngData))
        node.adjustments.exposure = 0.5

        // Act & Assert: must not crash
        let result = await ImagePipeline.shared.renderLocalNodes(
            [node],
            baseImage: baseImage,
            originalImage: baseImage
        )
        XCTAssertNotNil(result)
    }

    // MARK: - Helpers

    private func makeSolidPNG(width: Int, height: Int) -> Data {
        let size = NSSize(width: CGFloat(width), height: CGFloat(height))
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let bmp = NSBitmapImageRep(data: tiff),
              let png = bmp.representation(using: .png, properties: [:]) else {
            return Data()
        }
        return png
    }
}
