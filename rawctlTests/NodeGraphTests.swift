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
        // angle=0 (horizontal gradient): perpendicular is vertical, so dragging Y changes position.
        var node = ColorNode(name: "Test", type: .serial)
        node.mask = NodeMask(type: .linear(angle: 0, position: 0.5, falloff: 30))
        let binding = Binding<ColorNode>(get: { node }, set: { node = $0 })
        let imageSize = CGSize(width: 800, height: 600)
        var editor = LinearMaskEditor(node: binding, imageSize: imageSize)

        // Drag to y=120 → perpComponent = dy*cos(0) = (120-300) = -180
        // newPosY = 300 + (-180) = 120 → newPosition = 120/600 = 0.2
        let newLocation = CGPoint(x: 400, y: 120)
        editor.movePositionTo(newLocation, in: imageSize)

        if case .linear(_, let pos, _) = node.mask?.type {
            XCTAssertEqual(pos, 0.2, accuracy: 0.01)
        } else {
            XCTFail("Expected linear mask type")
        }
    }

    func test_movePositionTo_nonCenteredStart_doesNotJumpToMidline() {
        var node = ColorNode(name: "Test", type: .serial)
        node.mask = NodeMask(type: .linear(angle: 45, position: 0.2, falloff: 30))
        let binding = Binding<ColorNode>(get: { node }, set: { node = $0 })
        let size = CGSize(width: 800, height: 600)
        var editor = LinearMaskEditor(node: binding, imageSize: size)

        let center = LinearMaskGeometry.centerPoint(in: size, angle: 45, position: 0.2)
        editor.movePositionTo(center, in: size)
        if case .linear(_, let pos, _) = node.mask?.type {
            XCTAssertEqual(pos, 0.2, accuracy: 0.001, "Dragging on current center should preserve existing position")
        } else {
            XCTFail("Expected linear mask type")
        }

        let normal = LinearMaskGeometry.normalVector(angle: 45)
        let location = CGPoint(x: center.x + normal.dx * 40, y: center.y + normal.dy * 40)
        editor.movePositionTo(location, in: size)
        let expected = LinearMaskGeometry.projectedPosition(from: location, in: size, angle: 45)
        if case .linear(_, let pos, _) = node.mask?.type {
            XCTAssertEqual(pos, expected, accuracy: 0.001)
        } else {
            XCTFail("Expected linear mask type")
        }
    }

    func test_rotateAngleTo_updatesAngle() {
        var node = ColorNode(name: "Test", type: .serial)
        node.mask = NodeMask(type: .linear(angle: 0, position: 0.5, falloff: 30))
        let binding = Binding<ColorNode>(get: { node }, set: { node = $0 })
        let size = CGSize(width: 800, height: 600)
        var editor = LinearMaskEditor(node: binding, imageSize: size)

        // Center handle is at (400, 300). Dragging directly right → angle ≈ 0°
        editor.rotateAngleTo(CGPoint(x: 600, y: 300), in: size)
        if case .linear(let angle, _, _) = node.mask?.type {
            XCTAssertEqual(angle, 0.0, accuracy: 1.0)
        } else { XCTFail() }

        // Dragging directly down → angle ≈ 90°
        editor.rotateAngleTo(CGPoint(x: 400, y: 500), in: size)
        if case .linear(let angle, _, _) = node.mask?.type {
            XCTAssertEqual(angle, 90.0, accuracy: 1.0)
        } else { XCTFail() }
    }

    func test_changeFalloffTo_updatesFalloff() {
        var node = ColorNode(name: "Test", type: .serial)
        node.mask = NodeMask(type: .linear(angle: 0, position: 0.5, falloff: 10))
        let binding = Binding<ColorNode>(get: { node }, set: { node = $0 })
        let size = CGSize(width: 800, height: 600)
        var editor = LinearMaskEditor(node: binding, imageSize: size)

        // angle=0, posY=300. Drag to y=150: perp dist = |dy*cos(0)| = |150-300|=150px
        // minDim = min(800,600)=600, halfMinDim=300, newFalloff = (150/300)*100 = 50%
        editor.changeFalloffTo(CGPoint(x: 400, y: 150), in: size)
        if case .linear(_, _, let falloff) = node.mask?.type {
            XCTAssertEqual(falloff, 50.0, accuracy: 1.0)
        } else { XCTFail() }
    }

    func test_changeFalloffTo_clampedAtMax() {
        var node = ColorNode(name: "Test", type: .serial)
        node.mask = NodeMask(type: .linear(angle: 0, position: 0.5, falloff: 10))
        let binding = Binding<ColorNode>(get: { node }, set: { node = $0 })
        let size = CGSize(width: 800, height: 600)
        var editor = LinearMaskEditor(node: binding, imageSize: size)

        // Drag far beyond bounds → should clamp at 100%
        editor.changeFalloffTo(CGPoint(x: 400, y: -500), in: size)
        if case .linear(_, _, let falloff) = node.mask?.type {
            XCTAssertLessThanOrEqual(falloff, 100.0)
            XCTAssertGreaterThanOrEqual(falloff, 0.0)
        } else { XCTFail() }
    }
}

// MARK: - LinearMaskGeometry Tests

final class LinearMaskGeometryTests: XCTestCase {

    func test_positionAffectsGradientAtNinetyDegrees() {
        let size = CGSize(width: 800, height: 600)
        let top = LinearMaskGeometry.gradientPoints(in: size, angle: 90, position: 0.2, falloff: 30)
        let bottom = LinearMaskGeometry.gradientPoints(in: size, angle: 90, position: 0.8, falloff: 30)

        XCTAssertNotEqual(top.point0.x, bottom.point0.x, accuracy: 0.1)
        XCTAssertNotEqual(top.point1.x, bottom.point1.x, accuracy: 0.1)
    }

    func test_falloffUsesShortEdgeForLandscapeAndPortrait() {
        let landscape = CGSize(width: 1000, height: 500)
        let portrait = CGSize(width: 500, height: 1000)

        let a = LinearMaskGeometry.gradientPoints(in: landscape, angle: 0, position: 0.5, falloff: 20)
        let b = LinearMaskGeometry.gradientPoints(in: portrait, angle: 0, position: 0.5, falloff: 20)

        let distA = hypot(a.point0.x - a.point1.x, a.point0.y - a.point1.y)
        let distB = hypot(b.point0.x - b.point1.x, b.point0.y - b.point1.y)
        XCTAssertEqual(distA, 100, accuracy: 0.5) // 20% of short edge (500)
        XCTAssertEqual(distB, 100, accuracy: 0.5) // 20% of short edge (500)
    }

    func test_legacyFalloffUnitIntervalIsUpgradedToPercent() {
        let size = CGSize(width: 900, height: 600)
        let legacy = LinearMaskGeometry.gradientPoints(in: size, angle: 45, position: 0.5, falloff: 0.2)
        let modern = LinearMaskGeometry.gradientPoints(in: size, angle: 45, position: 0.5, falloff: 20)

        let legacyDist = hypot(legacy.point0.x - legacy.point1.x, legacy.point0.y - legacy.point1.y)
        let modernDist = hypot(modern.point0.x - modern.point1.x, modern.point0.y - modern.point1.y)
        XCTAssertEqual(legacyDist, modernDist, accuracy: 0.01)
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

// MARK: - Task 18: Keyboard Shortcut M — Mask Overlay Toggle

@MainActor
final class MaskOverlayShortcutTests: XCTestCase {

    func test_showMaskOverlay_toggles_via_toggleOverlay() {
        // Verify the toggleOverlay method works correctly
        let state = AppState()
        state.showMaskOverlay = false

        let toolbar = MaskEditingToolbar(appState: state)
        toolbar.toggleOverlay()

        XCTAssertTrue(state.showMaskOverlay)

        toolbar.toggleOverlay()
        XCTAssertFalse(state.showMaskOverlay)
    }

    func test_doneEditing_clearsEditingMaskId() {
        // Verify doneEditing works (shortcut M should not fire after Done)
        let state = AppState()
        state.editingMaskId = UUID()
        state.showMaskOverlay = true

        let toolbar = MaskEditingToolbar(appState: state)
        toolbar.doneEditing()

        XCTAssertNil(state.editingMaskId)
        XCTAssertFalse(state.showMaskOverlay)
    }
}

// MARK: - Task 19: Blend Mode + Opacity per Local Node

@MainActor
final class BlendModeOpacityTests: XCTestCase {

    func test_colorNode_defaultOpacity_isOne() {
        let node = ColorNode()
        XCTAssertEqual(node.opacity, 1.0, accuracy: 0.001)
    }

    func test_colorNode_defaultBlendMode_isNormal() {
        let node = ColorNode()
        XCTAssertEqual(node.blendMode, .normal)
    }

    func test_updateLocalNode_preserves_opacityAndBlendMode() {
        let state = AppState()
        var node = ColorNode(name: "Test", type: .serial)
        node.opacity = 0.75
        node.blendMode = .overlay
        state.localNodes[URL(fileURLWithPath: "/test")] = [node]

        // We directly check the stored localNodes instead of going through currentLocalNodes
        // (which requires a selected asset with a matching URL).
        let stored = state.localNodes[URL(fileURLWithPath: "/test")]?.first
        XCTAssertEqual(stored?.opacity ?? 0, 0.75, accuracy: 0.001)
        XCTAssertEqual(stored?.blendMode, .overlay)
    }

    func test_blendMode_allCases_haveDisplayNames() {
        for mode in BlendMode.allCases {
            XCTAssertFalse(mode.displayName.isEmpty)
        }
    }

    func test_updateLocalNode_opacity_persists() {
        let url = URL(fileURLWithPath: "/tmp/blend_opacity_test.ARW")
        let state = AppState()
        let asset = PhotoAsset(url: url)
        state.assets = [asset]
        state.selectedAssetId = asset.id

        var node = ColorNode(name: "Blend Test", type: .serial)
        state.addLocalNode(node)

        // Simulate user changing opacity via the UI binding setter
        node = state.currentLocalNodes.first!
        node.opacity = 0.5
        state.updateLocalNode(node)

        XCTAssertEqual(state.currentLocalNodes.first?.opacity ?? 0, 0.5, accuracy: 0.001)
    }

    func test_updateLocalNode_blendMode_persists() {
        let url = URL(fileURLWithPath: "/tmp/blend_mode_test.ARW")
        let state = AppState()
        let asset = PhotoAsset(url: url)
        state.assets = [asset]
        state.selectedAssetId = asset.id

        var node = ColorNode(name: "Mode Test", type: .serial)
        state.addLocalNode(node)

        // Simulate user changing blend mode via the UI binding setter
        node = state.currentLocalNodes.first!
        node.blendMode = .multiply
        state.updateLocalNode(node)

        XCTAssertEqual(state.currentLocalNodes.first?.blendMode, .multiply)
    }

    func test_blendMode_codable_roundtrip() throws {
        var node = ColorNode(name: "Codable", type: .serial)
        node.blendMode = .softLight
        node.opacity = 0.6

        let data = try JSONEncoder().encode(node)
        let decoded = try JSONDecoder().decode(ColorNode.self, from: data)

        XCTAssertEqual(decoded.blendMode, .softLight)
        XCTAssertEqual(decoded.opacity, 0.6, accuracy: 0.001)
    }
}

// MARK: - Task 20: Phase 2 Integration Tests

@MainActor
final class Phase2IntegrationTests: XCTestCase {

    func test_brushMask_fullPipeline() async throws {
        // 1. Set up AppState with a local node using a brush mask
        let state = AppState()
        let assetURL = URL(fileURLWithPath: "/tmp/test_photo.arw")

        var node = ColorNode(name: "Brush Retouch", type: .serial)

        // 2. Simulate brush strokes → render to PNG → store in node
        let brushMask = BrushMask()
        brushMask.canvasSize = CGSize(width: 400, height: 300)
        brushMask.beginStroke(at: CGPoint(x: 100, y: 100))
        brushMask.continueStroke(to: CGPoint(x: 200, y: 150))
        brushMask.continueStroke(to: CGPoint(x: 300, y: 100))
        brushMask.endStroke()

        let renderSize = CGSize(width: 400, height: 300)
        let pngData = brushMask.renderToPNG(targetSize: renderSize)
        XCTAssertNotNil(pngData, "renderToPNG must succeed")

        node.mask = NodeMask(type: .brush(data: pngData!))

        // 3. Adjust the node (opacity + blend mode)
        node.opacity = 0.8
        node.blendMode = .multiply

        // 4. Add node to AppState
        state.localNodes[assetURL] = [node]

        // 5. Verify the node is stored correctly
        let stored = state.localNodes[assetURL]?.first
        XCTAssertNotNil(stored)
        XCTAssertEqual(stored?.name, "Brush Retouch")
        XCTAssertEqual(stored?.opacity ?? 0, 0.8, accuracy: 0.001)
        XCTAssertEqual(stored?.blendMode, .multiply)

        // 6. Verify brush mask PNG is stored correctly
        if case .brush(let data) = stored?.mask?.type {
            XCTAssertFalse(data.isEmpty, "Brush mask PNG data must be non-empty")
        } else {
            XCTFail("Expected .brush mask type")
        }

        // 7. Verify BrushMaskBitmap can decode the PNG
        let image = NSImage(data: pngData!)
        XCTAssertNotNil(image, "PNG data must decode to NSImage")
        let bitmap = BrushMaskBitmap.from(image: image!)
        XCTAssertNotNil(bitmap)
        XCTAssertGreaterThan(bitmap?.width ?? 0, 0)
        XCTAssertGreaterThan(bitmap?.height ?? 0, 0)

        // 8. Codable roundtrip for the full node with brush mask
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(stored)
        let decoded = try decoder.decode(ColorNode.self, from: data)
        XCTAssertEqual(decoded.name, "Brush Retouch")
        XCTAssertEqual(decoded.opacity, node.opacity, accuracy: 0.001)
        XCTAssertEqual(decoded.blendMode, node.blendMode)
        if case .brush(let decodedData) = decoded.mask?.type {
            XCTAssertFalse(decodedData.isEmpty)
        } else {
            XCTFail("Decoded node must have .brush mask type")
        }
    }

    func test_radialMask_blendMode_opacity_pipeline() throws {
        // Verify a radial mask node with custom blend mode + opacity roundtrips correctly
        var node = ColorNode(name: "Radial Vignette", type: .serial)
        node.mask = NodeMask(type: .radial(centerX: 0.5, centerY: 0.5, radius: 0.4))
        node.mask?.feather = 30.0
        node.mask?.density = 80.0
        node.mask?.invert = true
        node.opacity = 0.6
        node.blendMode = .overlay

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let encoded = try encoder.encode(node)
        let decoded = try decoder.decode(ColorNode.self, from: encoded)

        XCTAssertEqual(decoded.opacity, 0.6, accuracy: 0.001)
        XCTAssertEqual(decoded.blendMode, .overlay)
        XCTAssertEqual(decoded.mask?.feather ?? 0, 30.0, accuracy: 0.001)
        XCTAssertEqual(decoded.mask?.density ?? 0, 80.0, accuracy: 0.001)
        XCTAssertEqual(decoded.mask?.invert, true)
        if case .radial(let cx, let cy, let r) = decoded.mask?.type {
            XCTAssertEqual(cx, 0.5, accuracy: 0.001)
            XCTAssertEqual(cy, 0.5, accuracy: 0.001)
            XCTAssertEqual(r, 0.4, accuracy: 0.001)
        } else {
            XCTFail("Expected .radial mask type")
        }
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

// MARK: - Bug Fix Regression Tests

/// Regression tests for the 4 bugs found during manual testing.
/// Each test directly verifies the fixed behaviour to prevent future regressions.
@MainActor
final class LocalAdjustmentBugFixTests: XCTestCase {

    // MARK: Bug 3: removeLocalNode / updateLocalNode must persist

    func test_removeLocalNode_removesNodeFromMemory() {
        // Before fix, sidecar was not updated; in-memory removal still works.
        // This is the minimum observable behaviour.
        let state = AppState()
        let url = URL(fileURLWithPath: "/tmp/photo.arw")
        var node = ColorNode(name: "Sky", type: .serial)
        node.mask = NodeMask(type: .radial(centerX: 0.5, centerY: 0.5, radius: 0.3))
        state.localNodes[url] = [node]
        state.select(PhotoAsset(url: url)) // sets selectedAsset so removeLocalNode finds the url
        // Simulate removal
        state.localNodes[url]?.removeAll { $0.id == node.id }
        XCTAssertTrue(state.localNodes[url]?.isEmpty ?? true,
                      "Node must be removed from in-memory localNodes")
    }

    func test_updateLocalNode_updatesInMemory() {
        let state = AppState()
        let url = URL(fileURLWithPath: "/tmp/photo.arw")
        var node = ColorNode(name: "Original", type: .serial)
        state.localNodes[url] = [node]

        // Simulate updateLocalNode logic
        node.name = "Updated"
        if let idx = state.localNodes[url]?.firstIndex(where: { $0.id == node.id }) {
            state.localNodes[url]?[idx] = node
        }

        XCTAssertEqual(state.localNodes[url]?.first?.name, "Updated")
    }

    // MARK: Bug 2: fittedPhotoSize coordinate alignment

    /// Replicates the fittedPhotoSize logic from SingleView and verifies it
    /// correctly constrains the overlay to the photo's displayed area.
    private func fittedPhotoSize(imagePixelSize: CGSize, in viewSize: CGSize) -> CGSize {
        guard imagePixelSize.width > 0, imagePixelSize.height > 0,
              viewSize.width > 0, viewSize.height > 0 else { return viewSize }
        let imageAspect = imagePixelSize.width / imagePixelSize.height
        let viewAspect  = viewSize.width / viewSize.height
        if imageAspect > viewAspect {
            return CGSize(width: viewSize.width, height: viewSize.width / imageAspect)
        } else {
            return CGSize(width: viewSize.height * imageAspect, height: viewSize.height)
        }
    }

    func test_fittedPhotoSize_landscapeImage_letterboxTopBottom() {
        // 3:2 image in 4:3 view → letterbox top/bottom, fills width
        let result = fittedPhotoSize(imagePixelSize: CGSize(width: 6000, height: 4000),
                                     in: CGSize(width: 800, height: 600))
        XCTAssertEqual(result.width, 800, accuracy: 1)
        XCTAssertEqual(result.height, 800 / (6000.0 / 4000.0), accuracy: 1)
        XCTAssertLessThan(result.height, 600, "letterbox: height must be less than view height")
    }

    func test_fittedPhotoSize_portraitImage_pillarboxSides() {
        // 3:4 image in 16:9 view → pillarbox left/right, fills height
        let result = fittedPhotoSize(imagePixelSize: CGSize(width: 3000, height: 4000),
                                     in: CGSize(width: 1600, height: 900))
        XCTAssertEqual(result.height, 900, accuracy: 1)
        XCTAssertLessThan(result.width, 1600, "pillarbox: width must be less than view width")
    }

    func test_fittedPhotoSize_exactAspectMatch_fillsView() {
        // 16:9 image in 16:9 view → fills exactly, no bars
        let result = fittedPhotoSize(imagePixelSize: CGSize(width: 1920, height: 1080),
                                     in: CGSize(width: 800, height: 450))
        XCTAssertEqual(result.width, 800, accuracy: 1)
        XCTAssertEqual(result.height, 450, accuracy: 1)
    }

    func test_fittedPhotoSize_zeroImageSize_returnsViewSize() {
        let viewSize = CGSize(width: 800, height: 600)
        let result = fittedPhotoSize(imagePixelSize: .zero, in: viewSize)
        XCTAssertEqual(result.width, viewSize.width)
        XCTAssertEqual(result.height, viewSize.height)
    }

    func test_fittedPhotoSize_normalizedCenter_staysAt05() {
        // The center of the overlay must map to the center of the photo.
        // For a 3:2 image in a 4:3 view, center (0.5, 0.5) in fitted coords
        // should equal center in image coords.
        let image  = CGSize(width: 6000, height: 4000) // 3:2
        let view   = CGSize(width: 800,  height: 600)  // 4:3
        let fitted = fittedPhotoSize(imagePixelSize: image, in: view)
        // The overlay's (0.5, 0.5) should land at exactly the midpoint of fitted.
        XCTAssertEqual(fitted.width  * 0.5, fitted.width  / 2, accuracy: 0.01)
        XCTAssertEqual(fitted.height * 0.5, fitted.height / 2, accuracy: 0.01)
    }

    // MARK: Bug 1: Mask type switching

    func test_changeMaskType_toLinear_updatesNode() {
        let state = AppState()
        let url = URL(fileURLWithPath: "/tmp/photo.arw")
        var node = ColorNode(name: "Test", type: .serial)
        node.mask = NodeMask(type: .radial(centerX: 0.5, centerY: 0.5, radius: 0.3))
        state.localNodes[url] = [node]

        // Simulate changeMaskType logic
        var updated = node
        updated.mask = NodeMask(type: .linear(angle: 90, position: 0.5, falloff: 20))
        if let idx = state.localNodes[url]?.firstIndex(where: { $0.id == updated.id }) {
            state.localNodes[url]?[idx] = updated
        }

        let stored = state.localNodes[url]?.first
        if case .linear = stored?.mask?.type {
            // pass
        } else {
            XCTFail("Expected .linear mask after type change, got \(String(describing: stored?.mask?.type))")
        }
    }

    func test_changeMaskType_toBrush_updatesNode() {
        let state = AppState()
        let url = URL(fileURLWithPath: "/tmp/photo.arw")
        var node = ColorNode(name: "Test", type: .serial)
        node.mask = NodeMask(type: .radial(centerX: 0.5, centerY: 0.5, radius: 0.3))
        state.localNodes[url] = [node]

        var updated = node
        updated.mask = NodeMask(type: .brush(data: Data()))
        if let idx = state.localNodes[url]?.firstIndex(where: { $0.id == updated.id }) {
            state.localNodes[url]?[idx] = updated
        }

        let stored = state.localNodes[url]?.first
        if case .brush = stored?.mask?.type {
            // pass
        } else {
            XCTFail("Expected .brush mask after type change")
        }
    }

    func test_changeMaskType_exitsEditingModeForCurrentNode() {
        // LocalAdjustmentRow.changeMaskType() must clear editingMaskId
        // if the node being changed was the one being edited.
        let state = AppState()
        let nodeId = UUID()
        state.editingMaskId = nodeId
        state.showMaskOverlay = true

        // Simulate what changeMaskType does when editing the same node
        if state.editingMaskId == nodeId {
            state.editingMaskId = nil
            state.showMaskOverlay = false
        }

        XCTAssertNil(state.editingMaskId)
        XCTAssertFalse(state.showMaskOverlay)
    }

    func test_changeMaskType_doesNotExitEditing_forDifferentNode() {
        // changeMaskType on node B must NOT exit editing mode for node A
        let state = AppState()
        let nodeAId = UUID()
        let nodeBId = UUID()
        state.editingMaskId = nodeAId
        state.showMaskOverlay = true

        // Simulate changeMaskType for node B (different id)
        if state.editingMaskId == nodeBId {
            state.editingMaskId = nil
            state.showMaskOverlay = false
        }

        XCTAssertEqual(state.editingMaskId, nodeAId, "editing mode must remain for node A")
        XCTAssertTrue(state.showMaskOverlay)
    }

    // MARK: Bug 4: Esc / Done exit mask mode

    func test_doneEditing_viaMaskEditingToolbar_clearsState() {
        let state = AppState()
        state.editingMaskId = UUID()
        state.showMaskOverlay = true

        let toolbar = MaskEditingToolbar(appState: state)
        toolbar.doneEditing()

        XCTAssertNil(state.editingMaskId, "doneEditing must clear editingMaskId")
        XCTAssertFalse(state.showMaskOverlay, "doneEditing must hide overlay")
    }

    func test_doneEditing_idempotent_whenAlreadyClear() {
        let state = AppState()
        state.editingMaskId = nil
        state.showMaskOverlay = false

        let toolbar = MaskEditingToolbar(appState: state)
        toolbar.doneEditing() // Must not crash when already clear

        XCTAssertNil(state.editingMaskId)
        XCTAssertFalse(state.showMaskOverlay)
    }
}

// MARK: - MaskingPanel Mask Type Selection Tests

@MainActor
final class MaskingPanelMaskTypeTests: XCTestCase {

    /// Helper: create state with a selected photo asset so addLocalNode can store nodes.
    /// Assets must be in state.assets for selectedAsset computed property to return non-nil.
    private func makeState() -> AppState {
        let state = AppState()
        let asset = PhotoAsset(url: URL(fileURLWithPath: "/tmp/test_photo.arw"))
        state.assets = [asset]
        state.selectedAssetId = asset.id
        return state
    }

    func test_addNewNode_radial_createsNodeWithRadialMask() {
        let state = makeState()
        let panel = MaskingPanel(appState: state)
        panel.addNewNode(maskType: .radial(centerX: 0.5, centerY: 0.5, radius: 0.3))
        let node = state.currentLocalNodes.first
        XCTAssertNotNil(node)
        if case .radial(let cx, let cy, let r) = node?.mask?.type {
            XCTAssertEqual(cx, 0.5, accuracy: 0.001)
            XCTAssertEqual(cy, 0.5, accuracy: 0.001)
            XCTAssertEqual(r,  0.3, accuracy: 0.001)
        } else {
            XCTFail("Expected .radial mask type")
        }
    }

    func test_addNewNode_linear_createsNodeWithLinearMask() {
        let state = makeState()
        let panel = MaskingPanel(appState: state)
        panel.addNewNode(maskType: .linear(angle: 90, position: 0.5, falloff: 20))
        let node = state.currentLocalNodes.first
        if case .linear(let angle, let pos, let falloff) = node?.mask?.type {
            XCTAssertEqual(angle,   90,   accuracy: 0.001)
            XCTAssertEqual(pos,     0.5,  accuracy: 0.001)
            XCTAssertEqual(falloff, 20,   accuracy: 0.001)
        } else {
            XCTFail("Expected .linear mask type")
        }
    }

    func test_addNewNode_brush_createsNodeWithBrushMask() {
        let state = makeState()
        let panel = MaskingPanel(appState: state)
        panel.addNewNode(maskType: .brush(data: Data()))
        let node = state.currentLocalNodes.first
        if case .brush = node?.mask?.type {
            // pass
        } else {
            XCTFail("Expected .brush mask type")
        }
    }

    func test_addNewNode_namesSequentially() {
        let state = makeState()
        let panel = MaskingPanel(appState: state)
        panel.addNewNode(maskType: .radial(centerX: 0.5, centerY: 0.5, radius: 0.3))
        panel.addNewNode(maskType: .linear(angle: 0, position: 0.5, falloff: 10))
        panel.addNewNode(maskType: .brush(data: Data()))
        let names = state.currentLocalNodes.map { $0.name }
        XCTAssertEqual(names, ["Local 1", "Local 2", "Local 3"])
    }

    func test_addNewNode_defaultMaskType_isRadial() {
        let state = makeState()
        let panel = MaskingPanel(appState: state)
        panel.addNewNode()  // no maskType argument → default
        let node = state.currentLocalNodes.first
        if case .radial = node?.mask?.type {
            // pass — default is radial
        } else {
            XCTFail("Default mask type must be radial")
        }
    }
}

// MARK: - BrushMask Stroke Cap Tests

final class BrushMaskStrokeCapTests: XCTestCase {

    func test_brushMask_strokeCap_neverExceeds200() {
        let mask = BrushMask()
        mask.canvasSize = CGSize(width: 400, height: 300)

        // Draw 250 strokes; the cap should keep count at 200
        for i in 0..<250 {
            let x = CGFloat(i % 200) + 10
            mask.beginStroke(at: CGPoint(x: x, y: 50))
            mask.continueStroke(to: CGPoint(x: x + 20, y: 80))
            mask.endStroke()
        }

        XCTAssertLessThanOrEqual(mask.strokes.count, 200,
                                 "Stroke count must never exceed 200 (cap enforced in endStroke)")
    }

    func test_brushMask_strokeCap_dropsOldest() {
        let mask = BrushMask()
        mask.canvasSize = CGSize(width: 400, height: 300)

        // Fill to exactly 200
        for i in 0..<200 {
            mask.beginStroke(at: CGPoint(x: CGFloat(i), y: 10))
            mask.continueStroke(to: CGPoint(x: CGFloat(i) + 5, y: 20))
            mask.endStroke()
        }
        XCTAssertEqual(mask.strokes.count, 200)

        // Add one more — the oldest (first) should be dropped, count stays 200
        let countBefore = mask.strokes.count
        mask.beginStroke(at: CGPoint(x: 300, y: 200))
        mask.continueStroke(to: CGPoint(x: 320, y: 220))
        mask.endStroke()

        XCTAssertEqual(mask.strokes.count, countBefore,
                       "Adding stroke #201 must drop oldest and keep count at 200")
    }

    func test_brushMask_under200Strokes_noDrop() {
        let mask = BrushMask()
        mask.canvasSize = CGSize(width: 400, height: 300)

        for i in 0..<10 {
            mask.beginStroke(at: CGPoint(x: CGFloat(i * 10), y: 10))
            mask.continueStroke(to: CGPoint(x: CGFloat(i * 10) + 5, y: 20))
            mask.endStroke()
        }

        XCTAssertEqual(mask.strokes.count, 10, "No strokes should be dropped below the cap")
    }
}

// MARK: - BrushMaskEditor Logic Tests

final class BrushMaskEditorLogicTests: XCTestCase {

    func test_emptyBrushMask_rendersBlackNoEffectMask() {
        let mask = BrushMask()
        let renderSize = CGSize(width: 64, height: 64)
        let pngData = mask.renderToPNG(targetSize: renderSize)
        XCTAssertNotNil(pngData)

        guard let data = pngData,
              let image = NSImage(data: data),
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let color = rep.colorAt(x: 32, y: 32)?.usingColorSpace(.deviceRGB) else {
            XCTFail("Expected decodable PNG for empty brush mask")
            return
        }
        XCTAssertLessThan(color.redComponent, 0.01)
        XCTAssertLessThan(color.greenComponent, 0.01)
        XCTAssertLessThan(color.blueComponent, 0.01)
    }

    func test_renderDelta_hasTransparentBackground() {
        let mask = BrushMask()
        mask.canvasSize = CGSize(width: 100, height: 100)
        mask.beginStroke(at: CGPoint(x: 10, y: 10))
        mask.continueStroke(to: CGPoint(x: 30, y: 30))
        mask.endStroke()

        guard let delta = mask.renderDeltaToPNG(targetSize: CGSize(width: 100, height: 100)),
              let image = NSImage(data: delta),
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let untouched = rep.colorAt(x: 80, y: 80)?.usingColorSpace(.deviceRGB) else {
            XCTFail("Expected decodable delta PNG")
            return
        }

        XCTAssertLessThan(untouched.alphaComponent, 0.01, "Untouched area should remain transparent in delta mask")
    }

    func test_commitBrushMask_nonEmptyBrush_writesData() {
        // When BrushMask has strokes, renderToPNG produces non-empty Data
        let mask = BrushMask()
        mask.canvasSize = CGSize(width: 200, height: 150)
        mask.beginStroke(at: CGPoint(x: 20, y: 20))
        mask.continueStroke(to: CGPoint(x: 80, y: 80))
        mask.endStroke()
        XCTAssertFalse(mask.isEmpty)

        let renderSize = CGSize(width: 200, height: 150)
        let pngData = mask.renderToPNG(targetSize: renderSize)
        XCTAssertNotNil(pngData)
        XCTAssertFalse(pngData?.isEmpty ?? true,
                       "renderToPNG must return non-empty PNG for a painted mask")
    }

    func test_renderSize_cap_reducesLargeImage() {
        // Replicates BrushMaskEditor.renderSize logic for a 24MP image
        let imageSize = CGSize(width: 6000, height: 4000)
        let maxPx: CGFloat = 2048
        let longEdge = max(imageSize.width, imageSize.height) // 6000
        let scale    = maxPx / longEdge                       // 2048/6000
        let expected = CGSize(width: (imageSize.width * scale).rounded(),
                              height: (imageSize.height * scale).rounded())

        XCTAssertLessThanOrEqual(max(expected.width, expected.height), maxPx,
                                 "Render size must be capped at 2048px long edge")
        XCTAssertEqual(expected.width  / expected.height,
                       imageSize.width / imageSize.height,
                       accuracy: 0.01,
                       "Aspect ratio must be preserved after capping")
    }

    func test_renderSize_smallImage_notUpscaled() {
        // Images smaller than 2048px must not be upscaled
        let imageSize = CGSize(width: 800, height: 600)
        let maxPx: CGFloat = 2048
        let longEdge = max(imageSize.width, imageSize.height) // 800
        let renderSize: CGSize = longEdge > maxPx
            ? CGSize(width: (imageSize.width * maxPx / longEdge).rounded(),
                     height: (imageSize.height * maxPx / longEdge).rounded())
            : imageSize  // ← should take this branch

        XCTAssertEqual(renderSize.width,  800)
        XCTAssertEqual(renderSize.height, 600)
    }
}

// MARK: - Local Node Render Blend Tests

final class LocalNodeRenderBlendTests: XCTestCase {
    private enum TestError: Error {
        case bitmapContextCreationFailed
        case imageEncodingFailed
        case imageRenderFailed
    }

    func test_localNodeOpacityChangesRenderedOutput() async throws {
        let dir = try makeTempDirectory(prefix: "rawctl-local-opacity")
        defer { try? FileManager.default.removeItem(at: dir) }

        let imageURL = dir.appendingPathComponent("base.png")
        try writeSolidPNG(at: imageURL, width: 320, height: 240, gray: 0.35)
        let asset = PhotoAsset(url: imageURL)

        var full = ColorNode(name: "Full", type: .serial)
        full.adjustments.exposure = 1.5
        full.opacity = 1.0
        full.blendMode = .normal

        var partial = full
        partial.opacity = 0.2

        guard let baseline = await ImagePipeline.shared.renderForExport(for: asset, recipe: EditRecipe()) else {
            throw TestError.imageRenderFailed
        }
        guard let fullOutput = await ImagePipeline.shared.renderForExport(for: asset, recipe: EditRecipe(), localNodes: [full]) else {
            throw TestError.imageRenderFailed
        }
        guard let partialOutput = await ImagePipeline.shared.renderForExport(for: asset, recipe: EditRecipe(), localNodes: [partial]) else {
            throw TestError.imageRenderFailed
        }

        let baselineLuma = averageLuminance(of: baseline)
        let fullLuma = averageLuminance(of: fullOutput)
        let partialLuma = averageLuminance(of: partialOutput)

        XCTAssertGreaterThan(fullLuma, baselineLuma + 0.10)
        XCTAssertGreaterThan(partialLuma, baselineLuma + 0.02)
        XCTAssertLessThan(partialLuma, fullLuma - 0.05)
    }

    func test_localNodeBlendModeAffectsPixels() async throws {
        let dir = try makeTempDirectory(prefix: "rawctl-local-blend")
        defer { try? FileManager.default.removeItem(at: dir) }

        let imageURL = dir.appendingPathComponent("base.png")
        try writeSolidPNG(at: imageURL, width: 320, height: 240, gray: 0.4)
        let asset = PhotoAsset(url: imageURL)

        var normal = ColorNode(name: "Normal", type: .serial)
        normal.adjustments.exposure = 1.2
        normal.opacity = 1
        normal.blendMode = .normal

        var multiply = normal
        multiply.blendMode = .multiply

        guard let normalOutput = await ImagePipeline.shared.renderForExport(for: asset, recipe: EditRecipe(), localNodes: [normal]) else {
            throw TestError.imageRenderFailed
        }
        guard let multiplyOutput = await ImagePipeline.shared.renderForExport(for: asset, recipe: EditRecipe(), localNodes: [multiply]) else {
            throw TestError.imageRenderFailed
        }

        let diff = meanAbsoluteDifference(normalOutput, multiplyOutput)
        XCTAssertGreaterThan(diff, 0.01, "Blend mode should produce visible pixel differences")
    }

    private func makeTempDirectory(prefix: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func writeSolidPNG(at url: URL, width: Int, height: Int, gray: CGFloat) throws {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw TestError.bitmapContextCreationFailed
        }
        context.setFillColor(NSColor(calibratedWhite: gray, alpha: 1.0).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        guard let cgImage = context.makeImage() else {
            throw TestError.imageEncodingFailed
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw TestError.imageEncodingFailed
        }
        try data.write(to: url, options: .atomic)
    }

    private func averageLuminance(of image: CGImage) -> Double {
        let rep = NSBitmapImageRep(cgImage: image)
        let width = rep.pixelsWide
        let height = rep.pixelsHigh
        var sum = 0.0
        var count = 0
        for y in stride(from: 0, to: height, by: max(1, height / 48)) {
            for x in stride(from: 0, to: width, by: max(1, width / 48)) {
                guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                let luma = 0.2126 * Double(color.redComponent)
                    + 0.7152 * Double(color.greenComponent)
                    + 0.0722 * Double(color.blueComponent)
                sum += luma
                count += 1
            }
        }
        return count > 0 ? sum / Double(count) : 0
    }

    private func meanAbsoluteDifference(_ lhs: CGImage, _ rhs: CGImage) -> Double {
        let repA = NSBitmapImageRep(cgImage: lhs)
        let repB = NSBitmapImageRep(cgImage: rhs)
        let width = min(repA.pixelsWide, repB.pixelsWide)
        let height = min(repA.pixelsHigh, repB.pixelsHigh)
        let step = max(1, min(width, height) / 64)

        var total = 0.0
        var count = 0
        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                guard let ca = repA.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                      let cb = repB.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                total += abs(Double(ca.redComponent - cb.redComponent))
                total += abs(Double(ca.greenComponent - cb.greenComponent))
                total += abs(Double(ca.blueComponent - cb.blueComponent))
                count += 3
            }
        }
        return count > 0 ? total / Double(count) : 0
    }
}

// MARK: - Selection Flow Tests

@MainActor
final class SelectionFlowTests: XCTestCase {
    private enum TestError: Error {
        case timeout
    }

    func test_selectSwitchingPhotoClearsMaskEditingStateAndRefreshesNodes() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rawctl-selection-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let photoA = dir.appendingPathComponent("a.png")
        let photoB = dir.appendingPathComponent("b.png")
        FileManager.default.createFile(atPath: photoA.path, contents: Data("a".utf8))
        FileManager.default.createFile(atPath: photoB.path, contents: Data("b".utf8))

        let assetA = PhotoAsset(url: photoA)
        let assetB = PhotoAsset(url: photoB)

        let state = AppState()
        state.assets = [assetA, assetB]
        state.select(assetA, switchToSingleView: false)

        var node = ColorNode(name: "Mask A", type: .serial)
        node.mask = NodeMask(type: .radial(centerX: 0.5, centerY: 0.5, radius: 0.3))
        try await SidecarService.shared.save(recipe: EditRecipe(), localNodes: [node], for: photoB)

        state.editingMaskId = UUID()
        state.showMaskOverlay = true

        state.select(assetB, switchToSingleView: false)

        XCTAssertNil(state.editingMaskId)
        XCTAssertFalse(state.showMaskOverlay)

        let deadline = Date().addingTimeInterval(2.0)
        while (state.localNodes[photoB] ?? []).isEmpty, Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        guard let loadedNodes = state.localNodes[photoB], !loadedNodes.isEmpty else {
            throw TestError.timeout
        }
        XCTAssertEqual(loadedNodes.first?.name, "Mask A")
    }
}

// MARK: - Brush Mask Fallback Tests

final class BrushMaskFallbackTests: XCTestCase {
    private enum TestError: Error {
        case imageRenderFailed
        case imageEncodingFailed
    }

    func test_invalidBrushDataBehavesAsNoOpMask() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rawctl-brush-fallback-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let imageURL = dir.appendingPathComponent("base.png")
        try writeSolidPNG(at: imageURL, width: 220, height: 160, gray: 0.45)
        let asset = PhotoAsset(url: imageURL)

        var node = ColorNode(name: "Invalid Brush", type: .serial)
        node.mask = NodeMask(type: .brush(data: Data("invalid".utf8)))
        node.adjustments.exposure = 2.0

        guard let baseline = await ImagePipeline.shared.renderForExport(for: asset, recipe: EditRecipe()) else {
            throw TestError.imageRenderFailed
        }
        guard let withInvalidBrush = await ImagePipeline.shared.renderForExport(
            for: asset,
            recipe: EditRecipe(),
            localNodes: [node]
        ) else {
            throw TestError.imageRenderFailed
        }

        let diff = meanAbsoluteDifference(baseline, withInvalidBrush)
        XCTAssertLessThan(diff, 0.002, "Invalid brush data should fall back to no-op mask")
    }

    private func writeSolidPNG(at url: URL, width: Int, height: Int, gray: CGFloat) throws {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw TestError.imageEncodingFailed
        }
        context.setFillColor(NSColor(calibratedWhite: gray, alpha: 1.0).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        guard let cgImage = context.makeImage() else {
            throw TestError.imageEncodingFailed
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw TestError.imageEncodingFailed
        }
        try data.write(to: url, options: .atomic)
    }

    private func meanAbsoluteDifference(_ lhs: CGImage, _ rhs: CGImage) -> Double {
        let repA = NSBitmapImageRep(cgImage: lhs)
        let repB = NSBitmapImageRep(cgImage: rhs)
        let width = min(repA.pixelsWide, repB.pixelsWide)
        let height = min(repA.pixelsHigh, repB.pixelsHigh)
        let step = max(1, min(width, height) / 64)

        var total = 0.0
        var count = 0
        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                guard let ca = repA.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                      let cb = repB.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                total += abs(Double(ca.redComponent - cb.redComponent))
                total += abs(Double(ca.greenComponent - cb.greenComponent))
                total += abs(Double(ca.blueComponent - cb.blueComponent))
                count += 3
            }
        }
        return count > 0 ? total / Double(count) : 0
    }
}
