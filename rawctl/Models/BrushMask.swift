//
//  BrushMask.swift
//  rawctl
//
//  Brush mask data structure for AI inpainting
//

import Foundation
import AppKit
import CoreGraphics

// MARK: - Brush Stroke

/// A single brush stroke with multiple points
struct BrushStroke: Codable, Identifiable, Equatable {
    let id: UUID
    var points: [CGPoint]
    var width: CGFloat
    var isEraser: Bool
    var opacity: CGFloat
    
    init(
        id: UUID = UUID(),
        points: [CGPoint] = [],
        width: CGFloat = 20,
        isEraser: Bool = false,
        opacity: CGFloat = 1.0
    ) {
        self.id = id
        self.points = points
        self.width = width
        self.isEraser = isEraser
        self.opacity = opacity
    }
    
    /// Add a point to this stroke
    mutating func addPoint(_ point: CGPoint) {
        points.append(point)
    }
    
    /// Check if stroke has enough points to draw
    var isDrawable: Bool {
        points.count >= 2
    }
}

// MARK: - Brush Mask

/// Collection of brush strokes that form a mask
class BrushMask: ObservableObject {
    @Published var strokes: [BrushStroke] = []
    @Published var currentStroke: BrushStroke?
    
    // Brush settings
    @Published var brushSize: CGFloat = 30
    @Published var brushOpacity: CGFloat = 1.0
    @Published var isEraserMode: Bool = false
    
    // Canvas size (for coordinate system)
    var canvasSize: CGSize = .zero
    
    // MARK: - Stroke Management
    
    /// Start a new stroke at point
    func beginStroke(at point: CGPoint) {
        currentStroke = BrushStroke(
            points: [point],
            width: brushSize,
            isEraser: isEraserMode,
            opacity: brushOpacity
        )
    }
    
    /// Continue current stroke to point
    func continueStroke(to point: CGPoint) {
        currentStroke?.addPoint(point)
        objectWillChange.send()
    }
    
    /// End current stroke
    func endStroke() {
        if let stroke = currentStroke, stroke.isDrawable {
            if strokes.count >= 200 {
                strokes.removeFirst()  // Drop oldest stroke to keep count bounded
            }
            strokes.append(stroke)
        }
        currentStroke = nil
    }
    
    /// Clear all strokes
    func clear() {
        strokes.removeAll()
        currentStroke = nil
    }
    
    /// Undo last stroke
    func undo() {
        guard !strokes.isEmpty else { return }
        strokes.removeLast()
    }
    
    /// Check if mask has any strokes
    var isEmpty: Bool {
        strokes.isEmpty && currentStroke == nil
    }
    
    // MARK: - Rendering
    
    /// Render mask to NSImage.
    /// - Parameters:
    ///   - targetSize: The output image size (typically original image size)
    ///   - includeBackground: true renders black background + strokes;
    ///     false renders transparent background with stroke pixels only.
    func render(to targetSize: CGSize, includeBackground: Bool = true) -> NSImage {
        let image = NSImage(size: targetSize)
        
        image.lockFocus()
        
        if includeBackground {
            // Black background (areas to keep)
            NSColor.black.setFill()
            NSRect(origin: .zero, size: targetSize).fill()
        } else {
            NSColor.clear.setFill()
            NSRect(origin: .zero, size: targetSize).fill()
        }
        
        // Calculate scale from canvas to target
        let scaleX = targetSize.width / max(canvasSize.width, 1)
        let scaleY = targetSize.height / max(canvasSize.height, 1)
        
        // Draw all strokes
        let allStrokes = strokes + (currentStroke.map { [$0] } ?? [])
        
        for stroke in allStrokes {
            drawStroke(stroke, scaleX: scaleX, scaleY: scaleY)
        }
        
        image.unlockFocus()
        
        return image
    }
    
    /// Draw a single stroke
    private func drawStroke(_ stroke: BrushStroke, scaleX: CGFloat, scaleY: CGFloat) {
        guard stroke.points.count >= 2 else { return }
        
        let path = NSBezierPath()
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.lineWidth = stroke.width * min(scaleX, scaleY)
        
        // Scale points to target size
        let scaledPoints = stroke.points.map { point in
            CGPoint(x: point.x * scaleX, y: point.y * scaleY)
        }
        
        // Create smooth path through points
        path.move(to: scaledPoints[0])
        
        for i in 1..<scaledPoints.count {
            let current = scaledPoints[i]
            let previous = scaledPoints[i - 1]
            let midPoint = CGPoint(
                x: (previous.x + current.x) / 2,
                y: (previous.y + current.y) / 2
            )
            
            if i == 1 {
                path.line(to: midPoint)
            } else {
                path.curve(to: midPoint, controlPoint1: previous, controlPoint2: previous)
            }
        }
        
        // Last point
        if let lastPoint = scaledPoints.last {
            path.line(to: lastPoint)
        }
        
        // Set color based on eraser mode
        if stroke.isEraser {
            NSColor.black.withAlphaComponent(stroke.opacity).setStroke()
        } else {
            NSColor.white.withAlphaComponent(stroke.opacity).setStroke()
        }
        
        path.stroke()
    }
    
    /// Render to PNG data
    func renderToPNG(targetSize: CGSize) -> Data? {
        let image = render(to: targetSize, includeBackground: true)
        
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        return bitmap.representation(using: .png, properties: [:])
    }

    /// Render stroke changes only (transparent background) to PNG.
    func renderDeltaToPNG(targetSize: CGSize) -> Data? {
        let image = render(to: targetSize, includeBackground: false)

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }
    
    /// Save mask to file
    func save(to url: URL, targetSize: CGSize) throws {
        guard let pngData = renderToPNG(targetSize: targetSize) else {
            throw BrushMaskError.renderFailed
        }
        try pngData.write(to: url)
    }
    
    // MARK: - Serialization
    
    /// Export strokes to JSON data
    func exportStrokes() throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(strokes)
    }
    
    /// Import strokes from JSON data
    func importStrokes(from data: Data) throws {
        let decoder = JSONDecoder()
        strokes = try decoder.decode([BrushStroke].self, from: data)
    }
}

// MARK: - Errors

enum BrushMaskError: LocalizedError {
    case renderFailed
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .renderFailed:
            return "Failed to render mask image"
        case .saveFailed:
            return "Failed to save mask file"
        }
    }
}

// MARK: - Preview Helper

#if DEBUG
extension BrushMask {
    /// Create a sample mask for previews
    static var sample: BrushMask {
        let mask = BrushMask()
        mask.canvasSize = CGSize(width: 800, height: 600)
        
        // Add some sample strokes
        var stroke1 = BrushStroke(width: 30, isEraser: false, opacity: 1.0)
        stroke1.points = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 150, y: 120),
            CGPoint(x: 200, y: 100),
            CGPoint(x: 250, y: 150)
        ]
        mask.strokes.append(stroke1)
        
        var stroke2 = BrushStroke(width: 50, isEraser: false, opacity: 1.0)
        stroke2.points = [
            CGPoint(x: 300, y: 300),
            CGPoint(x: 350, y: 350),
            CGPoint(x: 400, y: 300)
        ]
        mask.strokes.append(stroke2)
        
        return mask
    }
}
#endif
