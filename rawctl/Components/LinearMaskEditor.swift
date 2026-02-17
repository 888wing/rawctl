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
            let angleRad = params.angle * .pi / 180.0

            // Position of the center line in view space (along the perpendicular axis)
            let posY = CGFloat(params.position) * size.height

            // Falloff half-height in the perpendicular direction (view pixels)
            let falloffHalf = CGFloat(params.falloff / 100.0) * min(size.width, size.height) * 0.5

            let cosθ = CGFloat(cos(angleRad))
            let sinθ = CGFloat(sin(angleRad))

            // ──────────────────────────────────────────────────────
            // Handle screen-space positions (pre-rotation space)
            // ──────────────────────────────────────────────────────
            let centerHandle = CGPoint(x: size.width / 2, y: posY)

            // Rotation handle: along the center line, 40px from right edge
            let armLen = max(0, size.width / 2 - 28)
            let rotHandle = CGPoint(
                x: size.width / 2 + armLen * cosθ,
                y: posY + armLen * sinθ
            )

            // Falloff handle: at the upper boundary line midpoint
            let falloffHandle = CGPoint(
                x: size.width / 2 + falloffHalf * sinθ,
                y: posY - falloffHalf * cosθ
            )

            ZStack {
                // Gradient zone fill (semi-transparent band between the two lines)
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: size.width, height: max(1, falloffHalf * 2))
                    .position(x: size.width / 2, y: posY)
                    .rotationEffect(
                        Angle(degrees: params.angle),
                        anchor: UnitPoint(x: 0.5, y: params.position)
                    )
                    .allowsHitTesting(false)

                // Leading boundary line
                Path { path in
                    let y = posY - falloffHalf
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
                .rotationEffect(
                    Angle(degrees: params.angle),
                    anchor: UnitPoint(x: 0.5, y: params.position)
                )
                .allowsHitTesting(false)

                // Trailing boundary line
                Path { path in
                    let y = posY + falloffHalf
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
                .rotationEffect(
                    Angle(degrees: params.angle),
                    anchor: UnitPoint(x: 0.5, y: params.position)
                )
                .allowsHitTesting(false)

                // Dashed center reference line
                Path { path in
                    path.move(to: CGPoint(x: 0, y: posY))
                    path.addLine(to: CGPoint(x: size.width, y: posY))
                }
                .stroke(
                    Color.white.opacity(0.5),
                    style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                )
                .rotationEffect(
                    Angle(degrees: params.angle),
                    anchor: UnitPoint(x: 0.5, y: params.position)
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
        guard size.height > 0 else { return }
        let params = linearParams
        let θ = params.angle * .pi / 180.0
        let posY = params.position * Double(size.height)

        // Decompose the drag vector into parallel (along bands) and perpendicular components.
        let dx = Double(location.x) - Double(size.width) / 2
        let dy = Double(location.y) - posY

        // Perpendicular direction to the bands: (-sin θ, cos θ)
        // New perpendicular position offset from centre of view
        let perpComponent = -dx * sin(θ) + dy * cos(θ)
        let newPosY = Double(size.height) / 2 + perpComponent
        let newPosition = min(1.0, max(0.0, newPosY / Double(size.height)))

        if case .linear(let a, _, let f) = node.mask?.type {
            node.mask?.type = .linear(angle: a, position: newPosition, falloff: f)
        }
    }

    /// Rotate the gradient by computing the angle of the drag point relative to the center line.
    func rotateAngleTo(_ location: CGPoint, in size: CGSize) {
        let params = linearParams
        let posY = CGFloat(params.position) * size.height
        let dx = location.x - size.width / 2
        let dy = location.y - posY
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
        let θ = params.angle * .pi / 180.0
        let posY = CGFloat(params.position) * size.height

        let dx = location.x - size.width / 2
        let dy = location.y - posY

        // Perpendicular distance from the centre line (in view pixels)
        let perpDist = abs(-Double(dx) * sin(θ) + Double(dy) * cos(θ))

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
