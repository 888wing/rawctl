//
//  LinearMaskEditor.swift
//  rawctl
//
//  Overlay view for editing a linear gradient mask on a photo canvas.
//  Mask parameters: angle (degrees, 0 = gradient goes left→right),
//                   position (0–1, perpendicular distance from top),
//                   falloff (0–100, transition width as % of smaller dimension).
//
//  Handles (all in parent view coordinate space — no rotationEffect on gestures):
//    • Center handle  — drag to move gradient position perpendicular to bands
//    • Rotation handle — drag to change gradient direction (angle)
//    • Falloff handle  — drag to widen/narrow the transition zone
//

import SwiftUI

/// Overlay view for editing a linear gradient mask on a photo.
/// Three interactive handles let the user control all mask parameters.
struct LinearMaskEditor: View {
    @Binding var node: ColorNode
    let imageSize: CGSize

    // MARK: - Computed Properties

    private var linearParams: (angle: Double, position: Double, falloff: Double) {
        if case .linear(let a, let p, let f) = node.mask?.type {
            return (a, p, f)
        }
        return (90.0, 0.5, 30.0)
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let params = linearParams
            let center = LinearMaskGeometry.centerPoint(
                in: size,
                angle: params.angle,
                position: params.position
            )
            let direction = LinearMaskGeometry.directionVector(angle: params.angle)
            let normal = LinearMaskGeometry.normalVector(angle: params.angle)
            let falloffHalf = LinearMaskGeometry.halfFalloffPixels(
                in: size,
                falloff: params.falloff
            )
            let rotationAnchor = UnitPoint(
                x: size.width > 0 ? center.x / size.width : 0.5,
                y: size.height > 0 ? center.y / size.height : 0.5
            )

            // ──────────────────────────────────────────────────────
            // Handle screen-space positions (pre-rotation space)
            // ──────────────────────────────────────────────────────
            let centerHandle = center

            // Rotation handle: along the center line, 40px from right edge
            let armLen = max(0, size.width / 2 - 28)
            let rotHandle = CGPoint(
                x: center.x + armLen * direction.dx,
                y: center.y + armLen * direction.dy
            )

            // Falloff handle: at the upper boundary line midpoint
            let falloffHandle = CGPoint(
                x: center.x - falloffHalf * normal.dx,
                y: center.y - falloffHalf * normal.dy
            )

            ZStack {
                // Gradient zone fill (semi-transparent band between the two lines)
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: size.width, height: max(1, falloffHalf * 2))
                    .position(x: center.x, y: center.y)
                    .rotationEffect(
                        Angle(degrees: params.angle),
                        anchor: rotationAnchor
                    )
                    .allowsHitTesting(false)

                // Leading boundary line
                Path { path in
                    let y = center.y - falloffHalf
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
                .rotationEffect(
                    Angle(degrees: params.angle),
                    anchor: rotationAnchor
                )
                .allowsHitTesting(false)

                // Trailing boundary line
                Path { path in
                    let y = center.y + falloffHalf
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
                .rotationEffect(
                    Angle(degrees: params.angle),
                    anchor: rotationAnchor
                )
                .allowsHitTesting(false)

                // Dashed center reference line
                Path { path in
                    path.move(to: CGPoint(x: 0, y: center.y))
                    path.addLine(to: CGPoint(x: size.width, y: center.y))
                }
                .stroke(
                    Color.white.opacity(0.5),
                    style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                )
                .rotationEffect(
                    Angle(degrees: params.angle),
                    anchor: rotationAnchor
                )
                .allowsHitTesting(false)

                // ── Center handle (white dot) ──────────────────────
                // Drag to move the gradient centre-line position
                Circle()
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color.black.opacity(0.4), lineWidth: 1))
                    .position(centerHandle)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                movePositionTo(value.location, in: size)
                            }
                    )

                // ── Rotation handle (blue dot) ─────────────────────
                // Drag to rotate the gradient direction
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 1.5))
                    .position(rotHandle)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                rotateAngleTo(value.location, in: size)
                            }
                    )
                    .help("Drag to rotate gradient direction")

                // ── Falloff handle (white diamond) ─────────────────
                // Drag away from / toward center line to change transition width
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .rotationEffect(.degrees(45))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.black.opacity(0.4), lineWidth: 1)
                            .rotationEffect(.degrees(45))
                    )
                    .position(falloffHandle)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                changeFalloffTo(value.location, in: size)
                            }
                    )
                    .help("Drag to adjust falloff width")
            }
        }
    }

    // MARK: - Internal Logic (internal for testability)

    /// Move the gradient center line to the dragged view-space location.
    /// Position is measured perpendicularly to the gradient bands.
    func movePositionTo(_ location: CGPoint, in size: CGSize) {
        let params = linearParams
        let newPosition = LinearMaskGeometry.projectedPosition(
            from: location,
            in: size,
            angle: params.angle
        )

        if case .linear(let a, _, let f) = node.mask?.type {
            node.mask?.type = .linear(angle: a, position: newPosition, falloff: f)
        }
    }

    /// Rotate the gradient by computing the angle of the drag point relative to the center line.
    func rotateAngleTo(_ location: CGPoint, in size: CGSize) {
        let params = linearParams
        let center = LinearMaskGeometry.centerPoint(in: size, angle: params.angle, position: params.position)
        let dx = location.x - center.x
        let dy = location.y - center.y
        var degrees = atan2(dy, dx) * 180 / .pi
        // Normalise to 0–360
        if degrees < 0 { degrees += 360 }
        if case .linear(_, let p, let f) = node.mask?.type {
            node.mask?.type = .linear(angle: Double(degrees), position: p, falloff: f)
        }
    }

    /// Change the falloff width by measuring the drag distance from the center line.
    func changeFalloffTo(_ location: CGPoint, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let params = linearParams
        let normal = LinearMaskGeometry.normalVector(angle: params.angle)
        let center = LinearMaskGeometry.centerPoint(in: size, angle: params.angle, position: params.position)

        let dx = location.x - center.x
        let dy = location.y - center.y

        // Perpendicular distance from the centre line (in view pixels)
        let perpDist = abs(Double(dx) * Double(normal.dx) + Double(dy) * Double(normal.dy))

        // Normalize to percentage of smaller dimension (0–100)
        let minDim = Double(min(size.width, size.height))
        let newFalloff = min(100.0, max(0.0, perpDist / (minDim * 0.5) * 100.0))

        if case .linear(let a, let p, _) = node.mask?.type {
            node.mask?.type = .linear(angle: a, position: p, falloff: newFalloff)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    var node = ColorNode(name: "Sky Gradient", type: .serial)
    node.mask = NodeMask(type: .linear(angle: 45, position: 0.4, falloff: 30))

    return LinearMaskEditor(
        node: .constant(node),
        imageSize: CGSize(width: 800, height: 600)
    )
    .frame(width: 400, height: 300)
    .background(Color.gray.opacity(0.3))
}
#endif
