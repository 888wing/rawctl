//
//  BrushMaskEditor.swift
//  rawctl
//
//  Brush mask editor overlay for local adjustment nodes
//

import SwiftUI

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
    @State private var showBrushToolbar = true

    var body: some View {
        ZStack {
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
        // No onAppear reconstruction from PNG — strokes cannot be recovered from a rasterised bitmap.
        // The canvas starts fresh each time the mask editor is opened.
    }

    // MARK: - Commit

    /// Renders current brush strokes to PNG and stores the bytes in node.mask.
    func commitBrushMask() {
        guard let pngData = brushMask.renderToPNG(targetSize: imageSize) else { return }
        if node.mask == nil {
            node.mask = NodeMask(type: .brush(data: pngData))
        } else {
            node.mask?.type = .brush(data: pngData)
        }
        appState.updateLocalNode(node)
    }
}
