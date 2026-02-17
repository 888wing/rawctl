//
//  CropOverlayGeometryTests.swift
//  rawctlTests
//

import XCTest
@testable import rawctl

final class CropOverlayGeometryTests: XCTestCase {
    func testImageDisplayRect_letterboxesVerticallyForWideImage() {
        let imageSize = CGSize(width: 6000, height: 4000) // aspect 1.5
        let viewSize = CGSize(width: 1000, height: 1000)  // aspect 1.0

        let rect = CropOverlayGeometry.imageDisplayRect(imageSize: imageSize, viewSize: viewSize)

        XCTAssertEqual(rect.minX, 0, accuracy: 0.001)
        XCTAssertEqual(rect.width, 1000, accuracy: 0.001)
        XCTAssertEqual(rect.height, 666.667, accuracy: 0.01)
        XCTAssertEqual(rect.minY, 166.667, accuracy: 0.01)
    }

    func testImageDisplayRect_letterboxesHorizontallyForTallImage() {
        let imageSize = CGSize(width: 3000, height: 4000) // aspect 0.75
        let viewSize = CGSize(width: 1000, height: 600)   // aspect 1.666...

        let rect = CropOverlayGeometry.imageDisplayRect(imageSize: imageSize, viewSize: viewSize)

        XCTAssertEqual(rect.minY, 0, accuracy: 0.001)
        XCTAssertEqual(rect.height, 600, accuracy: 0.001)
        XCTAssertEqual(rect.width, 450, accuracy: 0.001)
        XCTAssertEqual(rect.minX, 275, accuracy: 0.001)
    }

    func testCropRect_mapsNormalizedRectInsideDisplayedImageRect() {
        let imageRect = CGRect(x: 0, y: 166.667, width: 1000, height: 666.667)
        let normalized = CropRect(x: 0.1, y: 0.2, w: 0.5, h: 0.3)

        let rect = CropOverlayGeometry.cropRect(for: normalized, in: imageRect)

        XCTAssertEqual(rect.minX, 100, accuracy: 0.01)
        XCTAssertEqual(rect.minY, 300, accuracy: 0.02)
        XCTAssertEqual(rect.width, 500, accuracy: 0.01)
        XCTAssertEqual(rect.height, 200, accuracy: 0.02)
    }

    func testNormalizedPoint_clampsToImageBounds() {
        let imageRect = CGRect(x: 100, y: 50, width: 400, height: 300)

        let inside = CropOverlayGeometry.normalizedPoint(CGPoint(x: 300, y: 200), in: imageRect)
        XCTAssertEqual(inside.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(inside.y, 0.5, accuracy: 0.001)

        let outside = CropOverlayGeometry.normalizedPoint(CGPoint(x: 700, y: -20), in: imageRect)
        XCTAssertEqual(outside.x, 1.0, accuracy: 0.001)
        XCTAssertEqual(outside.y, 0.0, accuracy: 0.001)
    }
}
