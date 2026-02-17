//
//  RadialMaskEditor.swift
//  rawctl
//
//  Overlay view for editing a radial (circular) mask on a photo canvas.
//  Mask parameters (centerX, centerY, radius) are normalized (0.0–1.0).
//

import SwiftUI

/// Overlay view for editing a radial (circular) mask on a photo.
/// Displays an interactive circle handle that the user can drag to reposition
/// the center and resize the radius. All parameters are normalized (0.0–1.0).
struct RadialMaskEditor: View {
    @Binding var node: ColorNode
    let imageSize: CGSize

    // MARK: - Computed Properties

    /// Extract radial parameters from the node's mask, with safe defaults.
    private var radialParams: (centerX: Double, centerY: Double, radius: Double) {
        if case .radial(let cx, let cy, let r) = node.mask?.type {
            return (cx, cy, r)
        }
        return (0.5, 0.5, 0.3)
    }

    /// Center point in view coordinates.
    private func centerPoint(in size: CGSize) -> CGPoint {
        let p = radialParams
        return CGPoint(x: p.centerX * size.width, y: p.centerY * size.height)
    }

    /// Radius in view coordinates (based on the smaller dimension for a true circle).
    private func radiusInView(in size: CGSize) -> CGFloat {
        let p = radialParams
        return CGFloat(p.radius) * min(size.width, size.height)
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let center = centerPoint(in: size)
            let radius = radiusInView(in: size)

            ZStack {
                // Circle outline — drag to move center
                Circle()
                    .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                moveCenterTo(value.location, in: size)
                            }
                    )

                // Dashed outline for visibility on bright backgrounds
                Circle()
                    .stroke(Color.black.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)
                    .allowsHitTesting(false)

                // Center dot handle
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.black.opacity(0.4), lineWidth: 1))
                    .position(center)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                moveCenterTo(value.location, in: size)
                            }
                    )

                // Radius handle — dot on the right edge of the circle
                let radiusHandlePos = CGPoint(x: center.x + radius, y: center.y)
                Circle()
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color.black.opacity(0.4), lineWidth: 1))
                    .position(radiusHandlePos)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                resizeRadiusTo(value.location, in: size)
                            }
                    )
            }
        }
    }

    // MARK: - Internal Logic (internal for testability)

    /// Move the mask center to the given view-space location, normalized to `size`.
    func moveCenterTo(_ location: CGPoint, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let newCX = min(1.0, max(0.0, Double(location.x / size.width)))
        let newCY = min(1.0, max(0.0, Double(location.y / size.height)))
        if case .radial(_, _, let r) = node.mask?.type {
            node.mask?.type = .radial(centerX: newCX, centerY: newCY, radius: r)
        }
    }

    /// Resize the mask radius based on the drag handle location, normalized to `size`.
    func resizeRadiusTo(_ location: CGPoint, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let p = radialParams
        let centerPt = CGPoint(x: p.centerX * size.width, y: p.centerY * size.height)
        let distance = sqrt(pow(location.x - centerPt.x, 2) + pow(location.y - centerPt.y, 2))
        let minDim = min(size.width, size.height)
        let newRadius = min(1.0, max(0.01, Double(distance / minDim)))
        node.mask?.type = .radial(centerX: p.centerX, centerY: p.centerY, radius: newRadius)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    var node = ColorNode(name: "Sky", type: .serial)
    node.mask = NodeMask(type: .radial(centerX: 0.5, centerY: 0.5, radius: 0.3))

    return RadialMaskEditor(
        node: .constant(node),
        imageSize: CGSize(width: 800, height: 600)
    )
    .frame(width: 400, height: 300)
    .background(Color.gray.opacity(0.3))
}
#endif
