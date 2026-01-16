//
//  CropOverlayView.swift
//  rawctl
//
//  Visual crop overlay for image cropping
//

import SwiftUI

/// Crop overlay view with draggable handles
struct CropOverlayView: View {
    @Binding var crop: Crop
    let imageSize: CGSize
    var gridOverlay: GridOverlay = .thirds

    @State private var dragStart: CGPoint = .zero
    @State private var dragHandle: DragHandle = .none
    @State private var initialRect: CropRect = CropRect()

    /// Local state for crop rect during drag - prevents continuous pipeline renders
    @State private var localRect: CropRect? = nil

    /// Background drag state (for drawing new crop area)
    @State private var isDrawingNewRect = false
    @State private var drawStartPoint: CGPoint = .zero

    /// Whether user is currently dragging the crop handles
    private var isDragging: Bool { localRect != nil }

    /// The rect to display - use localRect during drag, otherwise use binding
    private var displayRect: CropRect {
        localRect ?? crop.rect
    }

    enum DragHandle {
        case none
        case topLeft, topRight, bottomLeft, bottomRight
        case top, bottom, left, right
        case center
    }

    /// Current crop dimensions in pixels (uses displayRect for live feedback)
    private var cropDimensions: (width: Int, height: Int) {
        let w = Int(imageSize.width * displayRect.w)
        let h = Int(imageSize.height * displayRect.h)
        return (w, h)
    }

    /// Target aspect ratio (nil for free crop)
    private var targetAspect: Double? {
        if crop.aspect == .original {
            return imageSize.width / imageSize.height
        }
        return crop.aspect.aspectRatio
    }

    var body: some View {
        GeometryReader { geometry in
            let viewSize = geometry.size
            let cropRect = calculateCropRect(in: viewSize)

            ZStack {
                // Dimmed overlay for non-cropped areas - with background drag gesture
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: viewSize))
                }
                .fill(Color.black.opacity(0.5))
                .reverseMask {
                    Rectangle()
                        .frame(width: cropRect.width, height: cropRect.height)
                        .position(x: cropRect.midX, y: cropRect.midY)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { value in
                            handleBackgroundDrag(value: value, viewSize: viewSize)
                        }
                        .onEnded { _ in
                            commitBackgroundDrag()
                        }
                )

                // Crop rectangle
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: cropRect.width, height: cropRect.height)
                    .position(x: cropRect.midX, y: cropRect.midY)

                // Grid overlay (supports multiple types)
                if gridOverlay != .none {
                    drawGridOverlay(type: gridOverlay, in: cropRect)
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                }

                // Dimension label at bottom center
                VStack(spacing: 2) {
                    Text("\(cropDimensions.width) × \(cropDimensions.height)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)

                    if let aspect = crop.aspect.aspectRatio {
                        Text(crop.aspect.displayName)
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .position(x: cropRect.midX, y: cropRect.maxY + 24)

                // Corner handles
                ForEach(CornerPosition.allCases, id: \.self) { corner in
                    CornerHandle(corner: corner)
                        .position(cornerPosition(corner, in: cropRect))
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    handleCornerDrag(corner, value: value, viewSize: viewSize)
                                }
                                .onEnded { _ in
                                    commitCornerDrag()
                                }
                        )
                }

                // Center drag for moving the crop area
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: cropRect.width - 40, height: cropRect.height - 40)
                    .position(x: cropRect.midX, y: cropRect.midY)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                handleCenterDrag(value: value, viewSize: viewSize)
                            }
                            .onEnded { _ in
                                commitCenterDrag()
                            }
                    )
            }
        }
        .onChange(of: crop.aspect) { oldAspect, newAspect in
            withAnimation(.easeInOut(duration: 0.2)) {
                applyAspectRatio(newAspect)
            }
        }
    }

    private func calculateCropRect(in viewSize: CGSize) -> CGRect {
        // Use displayRect for immediate visual feedback during drag
        CGRect(
            x: viewSize.width * displayRect.x,
            y: viewSize.height * displayRect.y,
            width: viewSize.width * displayRect.w,
            height: viewSize.height * displayRect.h
        )
    }
    
    private func cornerPosition(_ corner: CornerPosition, in rect: CGRect) -> CGPoint {
        switch corner {
        case .topLeft: return CGPoint(x: rect.minX, y: rect.minY)
        case .topRight: return CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft: return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }
    
    private func handleCornerDrag(_ corner: CornerPosition, value: DragGesture.Value, viewSize: CGSize) {
        // Initialize local state on drag start (prevents continuous binding updates)
        if localRect == nil {
            localRect = crop.rect
            initialRect = crop.rect
        }

        let delta = CGPoint(
            x: value.translation.width / viewSize.width,
            y: value.translation.height / viewSize.height
        )

        var newRect = initialRect

        // Calculate new dimensions based on drag
        switch corner {
        case .topLeft:
            newRect.x = max(0, min(initialRect.x + initialRect.w - 0.1, initialRect.x + delta.x))
            newRect.y = max(0, min(initialRect.y + initialRect.h - 0.1, initialRect.y + delta.y))
            newRect.w = initialRect.w - (newRect.x - initialRect.x)
            newRect.h = initialRect.h - (newRect.y - initialRect.y)
        case .topRight:
            newRect.y = max(0, min(initialRect.y + initialRect.h - 0.1, initialRect.y + delta.y))
            newRect.w = max(0.1, min(1 - initialRect.x, initialRect.w + delta.x))
            newRect.h = initialRect.h - (newRect.y - initialRect.y)
        case .bottomLeft:
            newRect.x = max(0, min(initialRect.x + initialRect.w - 0.1, initialRect.x + delta.x))
            newRect.w = initialRect.w - (newRect.x - initialRect.x)
            newRect.h = max(0.1, min(1 - initialRect.y, initialRect.h + delta.y))
        case .bottomRight:
            newRect.w = max(0.1, min(1 - initialRect.x, initialRect.w + delta.x))
            newRect.h = max(0.1, min(1 - initialRect.y, initialRect.h + delta.y))
        }

        // Apply aspect ratio constraint if set
        if let aspect = targetAspect {
            // Convert to image-space aspect ratio
            let imageAspect = imageSize.width / imageSize.height
            let normalizedAspect = aspect / imageAspect

            // Constrain based on which dimension changed more
            let widthChange = abs(newRect.w - initialRect.w)
            let heightChange = abs(newRect.h - initialRect.h)

            if widthChange >= heightChange {
                // Width is primary - adjust height
                let targetH = newRect.w / normalizedAspect
                switch corner {
                case .topLeft, .topRight:
                    // Anchor bottom edge
                    let bottomY = initialRect.y + initialRect.h
                    newRect.h = min(targetH, bottomY)
                    newRect.y = bottomY - newRect.h
                case .bottomLeft, .bottomRight:
                    // Anchor top edge
                    newRect.h = min(targetH, 1 - initialRect.y)
                }
            } else {
                // Height is primary - adjust width
                let targetW = newRect.h * normalizedAspect
                switch corner {
                case .topLeft, .bottomLeft:
                    // Anchor right edge
                    let rightX = initialRect.x + initialRect.w
                    newRect.w = min(targetW, rightX)
                    newRect.x = rightX - newRect.w
                case .topRight, .bottomRight:
                    // Anchor left edge
                    newRect.w = min(targetW, 1 - initialRect.x)
                }
            }
        }

        // Clamp to valid bounds
        newRect.x = max(0, newRect.x)
        newRect.y = max(0, newRect.y)
        newRect.w = min(newRect.w, 1 - newRect.x)
        newRect.h = min(newRect.h, 1 - newRect.y)

        // Update local state only (no binding update = no pipeline trigger)
        localRect = newRect
    }

    /// Commit the local rect to the binding when drag ends
    private func commitCornerDrag() {
        guard let finalRect = localRect else { return }

        // Commit to binding - triggers single pipeline render
        crop.rect = finalRect

        // Auto-enable crop when rect is modified from default
        if !crop.isEnabled && finalRect != CropRect() {
            crop.isEnabled = true
        }

        // Clear local state
        localRect = nil
        initialRect = CropRect()
    }
    
    /// Handle center drag - Lightroom style (drag image under fixed frame)
    /// Dragging right moves the image right, which means cropping more from the left
    private func handleCenterDrag(value: DragGesture.Value, viewSize: CGSize) {
        // Initialize local state on drag start (prevents continuous binding updates)
        if localRect == nil {
            localRect = crop.rect
            dragStart = CGPoint(x: crop.rect.x, y: crop.rect.y)
        }

        guard var currentLocalRect = localRect else { return }

        // Lightroom style: invert the delta direction
        // Dragging image right = crop rect moves left (relative to image)
        let delta = CGPoint(
            x: -value.translation.width / viewSize.width,
            y: -value.translation.height / viewSize.height
        )

        currentLocalRect.x = max(0, min(1 - currentLocalRect.w, dragStart.x + delta.x))
        currentLocalRect.y = max(0, min(1 - currentLocalRect.h, dragStart.y + delta.y))

        // Update local state only (no binding update = no pipeline trigger)
        localRect = currentLocalRect
    }

    /// Commit the center drag to the binding when drag ends
    private func commitCenterDrag() {
        guard let finalRect = localRect else { return }

        // Commit to binding - triggers single pipeline render
        crop.rect = finalRect

        // Auto-enable crop when position is modified from default
        if !crop.isEnabled && finalRect != CropRect() {
            crop.isEnabled = true
        }

        // Clear local state
        localRect = nil
        dragStart = .zero
    }

    // MARK: - Background Drag (Draw New Crop Area)

    /// Handle background drag - draw a new crop area from scratch
    private func handleBackgroundDrag(value: DragGesture.Value, viewSize: CGSize) {
        if !isDrawingNewRect {
            // Start drawing new crop area
            isDrawingNewRect = true
            drawStartPoint = CGPoint(
                x: value.startLocation.x / viewSize.width,
                y: value.startLocation.y / viewSize.height
            )
            // Initialize local rect
            localRect = CropRect(
                x: drawStartPoint.x,
                y: drawStartPoint.y,
                w: 0,
                h: 0
            )
        }

        // Calculate new rect from start point to current location
        let currentPoint = CGPoint(
            x: value.location.x / viewSize.width,
            y: value.location.y / viewSize.height
        )

        var newRect = CropRect(
            x: min(drawStartPoint.x, currentPoint.x),
            y: min(drawStartPoint.y, currentPoint.y),
            w: abs(currentPoint.x - drawStartPoint.x),
            h: abs(currentPoint.y - drawStartPoint.y)
        )

        // Apply aspect ratio constraint if locked
        if let ratio = targetAspect {
            newRect = constrainNewRectToAspect(newRect, ratio: ratio, anchorPoint: drawStartPoint)
        }

        // Clamp to bounds
        newRect.x = max(0, min(1 - newRect.w, newRect.x))
        newRect.y = max(0, min(1 - newRect.h, newRect.y))
        newRect.w = min(newRect.w, 1 - newRect.x)
        newRect.h = min(newRect.h, 1 - newRect.y)

        localRect = newRect
    }

    /// Constrain a new rect to aspect ratio while keeping anchor point
    private func constrainNewRectToAspect(_ rect: CropRect, ratio: Double, anchorPoint: CGPoint) -> CropRect {
        let imageAspect = imageSize.width / imageSize.height
        let normalizedAspect = ratio / imageAspect

        var newRect = rect

        // Determine which dimension to adjust based on current rect shape
        let currentAspect = rect.w / max(rect.h, 0.001) * imageAspect

        if currentAspect > ratio {
            // Too wide - adjust width
            newRect.w = rect.h * normalizedAspect
        } else {
            // Too tall - adjust height
            newRect.h = rect.w / normalizedAspect
        }

        // Recalculate position based on anchor point
        if anchorPoint.x < rect.x + rect.w / 2 {
            // Anchor is on left side
            newRect.x = rect.x
        } else {
            // Anchor is on right side - adjust x to keep right edge
            newRect.x = rect.x + rect.w - newRect.w
        }

        if anchorPoint.y < rect.y + rect.h / 2 {
            // Anchor is on top side
            newRect.y = rect.y
        } else {
            // Anchor is on bottom side - adjust y to keep bottom edge
            newRect.y = rect.y + rect.h - newRect.h
        }

        return newRect
    }

    /// Commit background drag - finalize the new crop area
    private func commitBackgroundDrag() {
        guard let finalRect = localRect, isDrawingNewRect else { return }

        // Only commit if rect has meaningful size (avoid accidental clicks)
        // Minimum 2% of image in each dimension
        if finalRect.w > 0.02 && finalRect.h > 0.02 {
            crop.rect = finalRect
            crop.isEnabled = true
        }

        // Clear state
        isDrawingNewRect = false
        localRect = nil
        drawStartPoint = .zero
    }

    // MARK: - Aspect Ratio Application

    /// Apply aspect ratio immediately when changed
    private func applyAspectRatio(_ aspect: Crop.Aspect) {
        // Free aspect - no change needed
        guard let ratio = aspect.aspectRatio ?? (aspect == .original ? imageSize.width / imageSize.height : nil) else {
            return
        }

        // Calculate new rect centered on current crop
        let currentCenter = CGPoint(
            x: crop.rect.x + crop.rect.w / 2,
            y: crop.rect.y + crop.rect.h / 2
        )

        // Maintain similar area while applying new aspect ratio
        let currentArea = crop.rect.w * crop.rect.h

        // Calculate new dimensions
        // For normalized coordinates: w * imageAspect / h = targetAspect
        let imageAspect = imageSize.width / imageSize.height
        let normalizedRatio = ratio / imageAspect

        var newW = sqrt(currentArea * normalizedRatio)
        var newH = newW / normalizedRatio

        // Clamp to image bounds
        if newW > 1.0 {
            newW = 1.0
            newH = newW / normalizedRatio
        }
        if newH > 1.0 {
            newH = 1.0
            newW = newH * normalizedRatio
        }

        // Ensure minimum size
        newW = max(0.1, newW)
        newH = max(0.1, newH)

        // Center the new rect
        let newX = max(0, min(1 - newW, currentCenter.x - newW / 2))
        let newY = max(0, min(1 - newH, currentCenter.y - newH / 2))

        crop.rect = CropRect(x: newX, y: newY, w: newW, h: newH)

        // Auto-enable crop when aspect is changed from default
        if !crop.isEnabled && aspect != .free {
            crop.isEnabled = true
        }
    }

    // MARK: - Grid Overlay Drawing

    /// Draw the selected grid overlay type
    private func drawGridOverlay(type: GridOverlay, in rect: CGRect) -> Path {
        switch type {
        case .none:
            return Path()
        case .thirds:
            return drawThirdsGrid(in: rect)
        case .phi:
            return drawPhiGrid(in: rect)
        case .diagonal:
            return drawDiagonalGrid(in: rect)
        case .triangle:
            return drawGoldenTriangle(in: rect)
        case .spiral:
            return drawGoldenSpiral(in: rect)
        }
    }

    /// Rule of thirds grid
    private func drawThirdsGrid(in rect: CGRect) -> Path {
        var path = Path()
        // Vertical lines
        path.move(to: CGPoint(x: rect.minX + rect.width / 3, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width / 3, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX + rect.width * 2 / 3, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 2 / 3, y: rect.maxY))
        // Horizontal lines
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height / 3))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height / 3))
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 2 / 3))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 2 / 3))
        return path
    }

    /// Golden ratio grid (phi = 1.618)
    private func drawPhiGrid(in rect: CGRect) -> Path {
        var path = Path()
        let phi: CGFloat = 1.618
        let w = rect.width
        let h = rect.height

        // Vertical lines at w/phi and w - w/phi
        let vLine1 = w / phi
        let vLine2 = w - vLine1
        path.move(to: CGPoint(x: rect.minX + vLine1, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + vLine1, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX + vLine2, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + vLine2, y: rect.maxY))

        // Horizontal lines at h/phi and h - h/phi
        let hLine1 = h / phi
        let hLine2 = h - hLine1
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + hLine1))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + hLine1))
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + hLine2))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + hLine2))

        return path
    }

    /// Diagonal grid (corner to corner)
    private func drawDiagonalGrid(in rect: CGRect) -> Path {
        var path = Path()
        // Main diagonals
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }

    /// Golden triangle overlay
    private func drawGoldenTriangle(in rect: CGRect) -> Path {
        var path = Path()

        // Main diagonal
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))

        // Perpendicular from top-left corner to diagonal
        let perpX1 = rect.minX + rect.width * 0.382
        let perpY1 = rect.minY + rect.height * 0.382
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: perpX1, y: rect.maxY - perpY1))

        // Perpendicular from bottom-right corner to diagonal
        let perpX2 = rect.maxX - rect.width * 0.382
        let perpY2 = rect.maxY - rect.height * 0.382
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: perpX2, y: perpY2))

        return path
    }

    /// Golden spiral (Fibonacci approximation)
    private func drawGoldenSpiral(in rect: CGRect) -> Path {
        var path = Path()
        let phi: CGFloat = 1.618

        // Draw the phi grid lines first
        let vLine1 = rect.width / phi
        path.move(to: CGPoint(x: rect.minX + vLine1, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + vLine1, y: rect.maxY))

        let hLine1 = rect.height / phi
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + hLine1))
        path.addLine(to: CGPoint(x: rect.minX + vLine1, y: rect.minY + hLine1))

        // Approximate spiral with arcs (simplified)
        let centerX = rect.minX + vLine1
        let centerY = rect.minY + hLine1

        // First arc (largest)
        let radius1 = rect.height - hLine1
        path.move(to: CGPoint(x: centerX, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: centerX, y: centerY),
            radius: radius1,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )

        // Second arc
        let radius2 = vLine1 * 0.618
        path.addArc(
            center: CGPoint(x: rect.minX + radius2, y: centerY),
            radius: radius2,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )

        return path
    }
}

/// Corner position enum
enum CornerPosition: CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight
}

/// Corner handle visual
struct CornerHandle: View {
    let corner: CornerPosition
    
    var body: some View {
        ZStack {
            // White circle background
            Circle()
                .fill(Color.white)
                .frame(width: 16, height: 16)
            
            // Corner lines
            Path { path in
                let length: CGFloat = 12
                let offset: CGFloat = 2
                
                switch corner {
                case .topLeft:
                    path.move(to: CGPoint(x: offset, y: offset))
                    path.addLine(to: CGPoint(x: offset, y: length))
                    path.move(to: CGPoint(x: offset, y: offset))
                    path.addLine(to: CGPoint(x: length, y: offset))
                case .topRight:
                    path.move(to: CGPoint(x: -offset, y: offset))
                    path.addLine(to: CGPoint(x: -offset, y: length))
                    path.move(to: CGPoint(x: -offset, y: offset))
                    path.addLine(to: CGPoint(x: -length, y: offset))
                case .bottomLeft:
                    path.move(to: CGPoint(x: offset, y: -offset))
                    path.addLine(to: CGPoint(x: offset, y: -length))
                    path.move(to: CGPoint(x: offset, y: -offset))
                    path.addLine(to: CGPoint(x: length, y: -offset))
                case .bottomRight:
                    path.move(to: CGPoint(x: -offset, y: -offset))
                    path.addLine(to: CGPoint(x: -offset, y: -length))
                    path.move(to: CGPoint(x: -offset, y: -offset))
                    path.addLine(to: CGPoint(x: -length, y: -offset))
                }
            }
            .stroke(Color.accentColor, lineWidth: 3)
        }
        .frame(width: 24, height: 24)
    }
}

/// Reverse mask modifier
extension View {
    @ViewBuilder func reverseMask<Mask: View>(
        alignment: Alignment = .center,
        @ViewBuilder _ mask: () -> Mask
    ) -> some View {
        self.mask {
            Rectangle()
                .overlay(alignment: alignment) {
                    mask()
                        .blendMode(.destinationOut)
                }
        }
    }
}

#Preview("Rule of Thirds") {
    CropOverlayView(
        crop: .constant(Crop(isEnabled: true, rect: CropRect(x: 0.1, y: 0.1, w: 0.8, h: 0.8))),
        imageSize: CGSize(width: 800, height: 600),
        gridOverlay: .thirds
    )
    .frame(width: 400, height: 300)
    .background(Color.gray)
    .preferredColorScheme(.dark)
}

#Preview("Golden Ratio") {
    CropOverlayView(
        crop: .constant(Crop(isEnabled: true, rect: CropRect(x: 0.1, y: 0.1, w: 0.8, h: 0.8))),
        imageSize: CGSize(width: 800, height: 600),
        gridOverlay: .phi
    )
    .frame(width: 400, height: 300)
    .background(Color.gray)
    .preferredColorScheme(.dark)
}

#Preview("Golden Spiral") {
    CropOverlayView(
        crop: .constant(Crop(isEnabled: true, rect: CropRect(x: 0.1, y: 0.1, w: 0.8, h: 0.8))),
        imageSize: CGSize(width: 800, height: 600),
        gridOverlay: .spiral
    )
    .frame(width: 400, height: 300)
    .background(Color.gray)
    .preferredColorScheme(.dark)
}
