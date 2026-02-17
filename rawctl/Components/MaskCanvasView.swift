//
//  MaskCanvasView.swift
//  rawctl
//
//  Brush canvas for drawing masks for AI inpainting
//

import SwiftUI
import AppKit

/// Canvas view for drawing brush masks over an image
struct MaskCanvasView: View {
    @ObservedObject var mask: BrushMask
    let backgroundImage: NSImage?
    let imageSize: CGSize
    
    // Callbacks
    var onMaskChanged: (() -> Void)?
    
    @State private var canvasSize: CGSize = .zero
    @State private var showBrushPreview = false
    @State private var brushPreviewLocation: CGPoint = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background image
                if let image = backgroundImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Mask overlay (semi-transparent red for painted areas)
                MaskOverlayView(mask: mask, canvasSize: canvasSize)
                    .allowsHitTesting(false)
                
                // Brush preview cursor
                if showBrushPreview {
                    Circle()
                        .stroke(mask.isEraserMode ? Color.black : Color.white, lineWidth: 2)
                        .frame(width: mask.brushSize, height: mask.brushSize)
                        .position(brushPreviewLocation)
                        .allowsHitTesting(false)
                }
                
                // Gesture capture layer
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let point = value.location
                                
                                // Update brush preview
                                showBrushPreview = true
                                brushPreviewLocation = point
                                
                                if mask.currentStroke == nil {
                                    mask.beginStroke(at: point)
                                } else {
                                    mask.continueStroke(to: point)
                                }
                            }
                            .onEnded { _ in
                                mask.endStroke()
                                showBrushPreview = false
                                onMaskChanged?()
                            }
                    )
                    .onHover { isHovering in
                        showBrushPreview = isHovering
                    }
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            brushPreviewLocation = location
                            showBrushPreview = true
                        case .ended:
                            showBrushPreview = false
                        }
                    }
            }
            .onAppear {
                canvasSize = geometry.size
                mask.canvasSize = geometry.size
            }
            .onChange(of: geometry.size) { _, newSize in
                canvasSize = newSize
                mask.canvasSize = newSize
            }
        }
        .clipShape(Rectangle())
    }
}

// MARK: - Mask Overlay View

/// Renders the brush strokes as a semi-transparent overlay
struct MaskOverlayView: View {
    @ObservedObject var mask: BrushMask
    let canvasSize: CGSize
    
    var body: some View {
        Canvas { context, size in
            // Draw all completed strokes
            for stroke in mask.strokes {
                drawStroke(stroke, in: context, size: size)
            }
            
            // Draw current stroke being drawn
            if let currentStroke = mask.currentStroke {
                drawStroke(currentStroke, in: context, size: size)
            }
        }
        .allowsHitTesting(false)
    }
    
    private func drawStroke(_ stroke: BrushStroke, in context: GraphicsContext, size: CGSize) {
        guard stroke.points.count >= 2 else { return }
        
        var path = Path()
        path.move(to: stroke.points[0])
        
        for i in 1..<stroke.points.count {
            let current = stroke.points[i]
            let previous = stroke.points[i - 1]
            let midPoint = CGPoint(
                x: (previous.x + current.x) / 2,
                y: (previous.y + current.y) / 2
            )
            
            if i == 1 {
                path.addLine(to: midPoint)
            } else {
                path.addQuadCurve(to: midPoint, control: previous)
            }
        }
        
        if let lastPoint = stroke.points.last {
            path.addLine(to: lastPoint)
        }
        
        // Set stroke style
        let color: Color = stroke.isEraser ? .clear : .red.opacity(0.5 * stroke.opacity)
        
        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(
                lineWidth: stroke.width,
                lineCap: .round,
                lineJoin: .round
            )
        )
        
        // For eraser, use a separate draw call
        if stroke.isEraser {
            var eraserContext = context
            eraserContext.blendMode = .destinationOut
            eraserContext.stroke(
                path,
                with: .color(.white),
                style: StrokeStyle(
                    lineWidth: stroke.width,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
    }
}

// MARK: - Brush Toolbar

/// Toolbar for brush controls
struct BrushToolbar: View {
    @ObservedObject var mask: BrushMask
    let onClear: () -> Void
    let onUndo: () -> Void
    
    var body: some View {
        ViewThatFits(in: .horizontal) {
            regularToolbar
                .frame(minWidth: 760)
            compactToolbar
        }
        .background(.ultraThinMaterial)
    }

    private var regularToolbar: some View {
        HStack(spacing: 16) {
            // Brush/Eraser toggle
            toolToggleGroup
            
            Divider()
                .frame(height: 24)
            
            // Brush size
            brushSizeControl
            
            Divider()
                .frame(height: 24)
            
            // Actions
            actionButtons
            
            Spacer()
            
            // Stroke count indicator
            if !mask.strokes.isEmpty {
                Text("\(mask.strokes.count) strokes")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var compactToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                toolToggleGroup
                Divider().frame(height: 24)
                brushSizeControl
                Divider().frame(height: 24)
                actionButtons
                if !mask.strokes.isEmpty {
                    Text("\(mask.strokes.count) strokes")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var toolToggleGroup: some View {
        HStack(spacing: 4) {
            ToolButton(
                icon: "paintbrush.pointed.fill",
                label: "Brush",
                isSelected: !mask.isEraserMode
            ) {
                mask.isEraserMode = false
            }

            ToolButton(
                icon: "eraser.fill",
                label: "Eraser",
                isSelected: mask.isEraserMode
            ) {
                mask.isEraserMode = true
            }
        }
        .padding(4)
        .background(Color(white: 0.15))
        .cornerRadius(8)
    }

    private var brushSizeControl: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Size")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                Slider(value: $mask.brushSize, in: 5...100)
                    .frame(width: 120)

                Text("\(Int(mask.brushSize))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 30, alignment: .trailing)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button {
                onUndo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .disabled(mask.strokes.isEmpty)
            .help("Undo last stroke")

            Button {
                onClear()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(mask.isEmpty)
            .help("Clear all strokes")
        }
    }
}

// MARK: - Tool Button

private struct ToolButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(size: 9))
            }
            .frame(width: 50, height: 40)
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Mask Canvas") {
    VStack(spacing: 0) {
        BrushToolbar(
            mask: BrushMask.sample,
            onClear: {},
            onUndo: {}
        )

        MaskCanvasView(
            mask: BrushMask.sample,
            backgroundImage: nil,
            imageSize: CGSize(width: 800, height: 600)
        )
        .frame(width: 600, height: 400)
        .background(Color.gray.opacity(0.3))
    }
    .preferredColorScheme(.dark)
}
#endif
