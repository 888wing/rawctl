//
//  LinearMaskEditor.swift
//  rawctl
//
//  Overlay view for editing a linear gradient mask on a photo canvas.
//  Mask parameters: angle (degrees), position (0–1), falloff (0–1).
//

import SwiftUI

/// Overlay view for editing a linear gradient mask on a photo.
/// Displays two parallel lines representing the gradient zone boundaries.
/// A center handle lets the user drag to change the gradient position.
/// All position parameters are normalized (0.0–1.0).
struct LinearMaskEditor: View {
    @Binding var node: ColorNode
    let imageSize: CGSize

    // MARK: - Computed Properties

    /// Extract linear mask parameters with safe defaults.
    private var linearParams: (angle: Double, position: Double, falloff: Double) {
        if case .linear(let a, let p, let f) = node.mask?.type {
            return (a, p, f)
        }
        return (0.0, 0.5, 0.3)
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let params = linearParams

            // Convert normalized position (0–1) to y coordinate in view
            let posY = CGFloat(params.position) * size.height

            // Falloff half-height in view coordinates
            let falloffHalf = CGFloat(params.falloff) * size.height * 0.5

            // Line positions
            let line1Y = posY - falloffHalf
            let line2Y = posY + falloffHalf

            // Rotation angle for the overlay lines
            let angle = Angle(degrees: params.angle)

            ZStack {
                // Gradient zone fill (semi-transparent between the two lines)
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: size.width, height: max(1, falloffHalf * 2))
                    .position(x: size.width / 2, y: posY)
                    .rotationEffect(angle)
                    .allowsHitTesting(false)

                // Leading boundary line
                Path { path in
                    path.move(to: CGPoint(x: 0, y: line1Y))
                    path.addLine(to: CGPoint(x: size.width, y: line1Y))
                }
                .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
                .rotationEffect(angle, anchor: UnitPoint(x: 0.5, y: params.position))
                .allowsHitTesting(false)

                // Trailing boundary line
                Path { path in
                    path.move(to: CGPoint(x: 0, y: line2Y))
                    path.addLine(to: CGPoint(x: size.width, y: line2Y))
                }
                .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
                .rotationEffect(angle, anchor: UnitPoint(x: 0.5, y: params.position))
                .allowsHitTesting(false)

                // Dashed center reference line
                Path { path in
                    path.move(to: CGPoint(x: 0, y: posY))
                    path.addLine(to: CGPoint(x: size.width, y: posY))
                }
                .stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                .rotationEffect(angle, anchor: UnitPoint(x: 0.5, y: params.position))
                .allowsHitTesting(false)

                // Center drag handle
                let handlePos = CGPoint(x: size.width / 2, y: posY)
                Circle()
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color.black.opacity(0.4), lineWidth: 1))
                    .position(handlePos)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                movePositionTo(value.location, in: size)
                            }
                    )
            }
        }
    }

    // MARK: - Internal Logic (internal for testability)

    /// Move the gradient position to the given view-space location, normalized to `size`.
    /// For a horizontal gradient (angle=0), position is determined by the y coordinate.
    func movePositionTo(_ location: CGPoint, in size: CGSize) {
        guard size.height > 0 else { return }
        let newPosition = min(1.0, max(0.0, Double(location.y / size.height)))
        if case .linear(let a, _, let f) = node.mask?.type {
            node.mask?.type = .linear(angle: a, position: newPosition, falloff: f)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    var node = ColorNode(name: "Sky Gradient", type: .serial)
    node.mask = NodeMask(type: .linear(angle: 0, position: 0.4, falloff: 0.2))

    return LinearMaskEditor(
        node: .constant(node),
        imageSize: CGSize(width: 800, height: 600)
    )
    .frame(width: 400, height: 300)
    .background(Color.gray.opacity(0.3))
}
#endif
