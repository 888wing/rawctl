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

    @State private var dragStart: CGPoint = .zero
    @State private var dragHandle: DragHandle = .none
    @State private var initialRect: CropRect = CropRect()

    enum DragHandle {
        case none
        case topLeft, topRight, bottomLeft, bottomRight
        case top, bottom, left, right
        case center
    }

    /// Current crop dimensions in pixels
    private var cropDimensions: (width: Int, height: Int) {
        let w = Int(imageSize.width * crop.rect.w)
        let h = Int(imageSize.height * crop.rect.h)
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
                // Dimmed overlay for non-cropped areas
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: viewSize))
                }
                .fill(Color.black.opacity(0.5))
                .reverseMask {
                    Rectangle()
                        .frame(width: cropRect.width, height: cropRect.height)
                        .position(x: cropRect.midX, y: cropRect.midY)
                }

                // Crop rectangle
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: cropRect.width, height: cropRect.height)
                    .position(x: cropRect.midX, y: cropRect.midY)

                // Grid lines (rule of thirds)
                Path { path in
                    // Vertical lines
                    path.move(to: CGPoint(x: cropRect.minX + cropRect.width / 3, y: cropRect.minY))
                    path.addLine(to: CGPoint(x: cropRect.minX + cropRect.width / 3, y: cropRect.maxY))
                    path.move(to: CGPoint(x: cropRect.minX + cropRect.width * 2 / 3, y: cropRect.minY))
                    path.addLine(to: CGPoint(x: cropRect.minX + cropRect.width * 2 / 3, y: cropRect.maxY))
                    // Horizontal lines
                    path.move(to: CGPoint(x: cropRect.minX, y: cropRect.minY + cropRect.height / 3))
                    path.addLine(to: CGPoint(x: cropRect.maxX, y: cropRect.minY + cropRect.height / 3))
                    path.move(to: CGPoint(x: cropRect.minX, y: cropRect.minY + cropRect.height * 2 / 3))
                    path.addLine(to: CGPoint(x: cropRect.maxX, y: cropRect.minY + cropRect.height * 2 / 3))
                }
                .stroke(Color.white.opacity(0.5), lineWidth: 1)

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
                                    initialRect = CropRect()
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
                                dragStart = .zero
                            }
                    )
            }
        }
    }
    
    private func calculateCropRect(in viewSize: CGSize) -> CGRect {
        CGRect(
            x: viewSize.width * crop.rect.x,
            y: viewSize.height * crop.rect.y,
            width: viewSize.width * crop.rect.w,
            height: viewSize.height * crop.rect.h
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
        // Store initial rect on drag start
        if initialRect.w == 0 {
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

        crop.rect = newRect
    }
    
    private func handleCenterDrag(value: DragGesture.Value, viewSize: CGSize) {
        if dragStart == .zero {
            dragStart = CGPoint(x: crop.rect.x, y: crop.rect.y)
        }
        
        let delta = CGPoint(
            x: value.translation.width / viewSize.width,
            y: value.translation.height / viewSize.height
        )
        
        let newX = max(0, min(1 - crop.rect.w, dragStart.x + delta.x))
        let newY = max(0, min(1 - crop.rect.h, dragStart.y + delta.y))
        
        crop.rect.x = newX
        crop.rect.y = newY
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

#Preview {
    CropOverlayView(
        crop: .constant(Crop(isEnabled: true, rect: CropRect(x: 0.1, y: 0.1, w: 0.8, h: 0.8))),
        imageSize: CGSize(width: 800, height: 600)
    )
    .frame(width: 400, height: 300)
    .background(Color.gray)
    .preferredColorScheme(.dark)
}
