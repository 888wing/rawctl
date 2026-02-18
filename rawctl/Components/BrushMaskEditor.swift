//
//  BrushMaskEditor.swift
//  rawctl
//
//  Brush mask editor overlay for local adjustment nodes
//

import SwiftUI
import AppKit

/// Editor view for drawing brush masks over the photo for a local adjustment node.
///
/// Presents `MaskCanvasView` for drawing and `BrushToolbar` for brush controls.
/// After each stroke ends, the mask is rendered to PNG and written into the
/// node's `.brush(data:)` mask type.
struct BrushMaskEditor: View {
    @Binding var node: ColorNode
    @ObservedObject var appState: AppState
    let imageSize: CGSize  // Original image pixel dimensions

    @StateObject private var brushMask = BrushMask()
    @State private var baseMaskData: Data?
    @State private var baseMaskPreview: NSImage?
    @State private var showBrushToolbar = true

    var body: some View {
        ZStack {
            if let preview = baseMaskPreview {
                Image(nsImage: preview)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .colorMultiply(.red)
                    .opacity(0.25)
                    .allowsHitTesting(false)
            }

            // Canvas fills available space; no background image — the photo is behind the overlay
            MaskCanvasView(
                mask: brushMask,
                backgroundImage: nil,
                imageSize: imageSize
            ) {
                commitBrushMask()
            }

            VStack {
                Spacer()
                if showBrushToolbar {
                    BrushToolbar(
                        mask: brushMask,
                        onClear: {
                            brushMask.clear()
                            baseMaskData = nil
                            baseMaskPreview = nil
                            commitBrushMask()
                        },
                        onUndo: {
                            brushMask.undo()
                            commitBrushMask()
                        }
                    )
                }
            }
        }
        .onAppear {
            loadBaseMaskFromNode()
        }
    }

    // MARK: - Commit

    /// Render at reduced resolution (≤2048px long edge) for interactive feedback;
    /// full-resolution rendering would block the main thread for large RAW files.
    private var renderSize: CGSize {
        let maxPx: CGFloat = 2048
        let longEdge = max(imageSize.width, imageSize.height)
        guard longEdge > maxPx else { return imageSize }
        let scale = maxPx / longEdge
        return CGSize(width: (imageSize.width * scale).rounded(), height: (imageSize.height * scale).rounded())
    }

    /// Renders current brush strokes to PNG and stores the bytes in node.mask.
    func commitBrushMask() {
        let hasStrokeChanges = !brushMask.isEmpty
        let deltaData = hasStrokeChanges ? brushMask.renderDeltaToPNG(targetSize: renderSize) : nil
        let fullStrokeData = hasStrokeChanges ? brushMask.renderToPNG(targetSize: renderSize) : nil

        let finalData: Data?
        if let base = baseMaskData, let delta = deltaData {
            finalData = compositeMask(base: base, delta: delta, targetSize: renderSize)
        } else if let base = baseMaskData {
            finalData = base
        } else if let full = fullStrokeData {
            finalData = full
        } else {
            finalData = blackMaskData(targetSize: renderSize)
        }

        guard let pngData = finalData else { return }
        if node.mask == nil {
            node.mask = NodeMask(type: .brush(data: pngData))
        } else {
            node.mask?.type = .brush(data: pngData)
        }
        // Note: the binding setter (set: { appState.updateLocalNode($0) }) in SingleView
        // already calls updateLocalNode on every write to `node`, so no explicit call is needed here.
    }

    private func loadBaseMaskFromNode() {
        guard case .brush(let data) = node.mask?.type, !data.isEmpty else {
            baseMaskData = nil
            baseMaskPreview = nil
            return
        }
        baseMaskData = data
        baseMaskPreview = NSImage(data: data)
    }

    private func compositeMask(base: Data, delta: Data, targetSize: CGSize) -> Data? {
        guard let baseImage = NSImage(data: base), let deltaImage = NSImage(data: delta) else { return nil }
        let rect = NSRect(origin: .zero, size: targetSize)
        let image = NSImage(size: targetSize)
        image.lockFocus()
        NSColor.black.setFill()
        rect.fill()
        baseImage.draw(in: rect)
        deltaImage.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
        image.unlockFocus()
        return pngData(from: image)
    }

    private func blackMaskData(targetSize: CGSize) -> Data? {
        let rect = NSRect(origin: .zero, size: targetSize)
        let image = NSImage(size: targetSize)
        image.lockFocus()
        NSColor.black.setFill()
        rect.fill()
        image.unlockFocus()
        return pngData(from: image)
    }

    private func pngData(from image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
