//
//  BrushMaskBitmap.swift
//  rawctl
//
//  Lightweight value-type representation of a brush mask for use in ColorNode
//

import Foundation
import AppKit
import CoreImage

/// Lightweight value-type representation of a brush mask for use in ColorNode.
/// Stores the rendered mask as PNG data so it can be serialised alongside the
/// node graph without embedding a full BrushMask (class with UI state).
struct BrushMaskBitmap: Codable, Equatable {
    var pngData: Data
    var width: Int
    var height: Int

    init(pngData: Data, width: Int, height: Int) {
        self.pngData = pngData
        self.width = width
        self.height = height
    }

    // MARK: - Factory

    /// Create a BrushMaskBitmap from an NSImage by encoding it as PNG.
    /// Returns nil if the image cannot be represented as PNG.
    static func from(image: NSImage) -> BrushMaskBitmap? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        return BrushMaskBitmap(
            pngData: png,
            width: Int(image.size.width),
            height: Int(image.size.height)
        )
    }

    // MARK: - Rendering

    /// Convert the stored PNG data back to a CIImage for use in the rendering pipeline.
    func toCIImage() -> CIImage? {
        CIImage(data: pngData)
    }
}
