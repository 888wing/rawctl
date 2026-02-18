//
//  LinearMaskGeometry.swift
//  rawctl
//
//  Shared linear-mask math used by editor interaction and CI rendering.
//

import CoreGraphics
import Foundation

enum LinearMaskGeometry {
    static func directionVector(angle: Double) -> CGVector {
        let radians = angle * .pi / 180.0
        return CGVector(dx: cos(radians), dy: sin(radians))
    }

    static func normalVector(angle: Double) -> CGVector {
        let radians = angle * .pi / 180.0
        return CGVector(dx: -sin(radians), dy: cos(radians))
    }

    static func normalizedPosition(_ position: Double) -> Double {
        min(1.0, max(0.0, position))
    }

    static func normalizedFalloffPercent(_ falloff: Double) -> Double {
        let upgraded = falloff <= 1.0 ? falloff * 100.0 : falloff
        return min(100.0, max(0.0, upgraded))
    }

    static func centerPoint(in size: CGSize, angle: Double, position: Double) -> CGPoint {
        let midpoint = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        let normal = normalVector(angle: angle)
        let offset = (normalizedPosition(position) - 0.5) * Double(size.height)
        return CGPoint(
            x: midpoint.x + CGFloat(offset * Double(normal.dx)),
            y: midpoint.y + CGFloat(offset * Double(normal.dy))
        )
    }

    static func halfFalloffPixels(in size: CGSize, falloff: Double) -> CGFloat {
        let percent = normalizedFalloffPercent(falloff)
        let pixels = min(size.width, size.height) * CGFloat(percent / 100.0)
        return max(0.5, pixels * 0.5)
    }

    static func gradientPoints(
        in size: CGSize,
        angle: Double,
        position: Double,
        falloff: Double
    ) -> (point0: CGPoint, point1: CGPoint) {
        let center = centerPoint(in: size, angle: angle, position: position)
        let normal = normalVector(angle: angle)
        let halfFalloff = halfFalloffPixels(in: size, falloff: falloff)

        return (
            point0: CGPoint(
                x: center.x + normal.dx * halfFalloff,
                y: center.y + normal.dy * halfFalloff
            ),
            point1: CGPoint(
                x: center.x - normal.dx * halfFalloff,
                y: center.y - normal.dy * halfFalloff
            )
        )
    }

    static func projectedPosition(
        from location: CGPoint,
        in size: CGSize,
        angle: Double
    ) -> Double {
        guard size.height > 0 else { return 0.5 }
        let midpoint = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        let normal = normalVector(angle: angle)
        let dx = Double(location.x - midpoint.x)
        let dy = Double(location.y - midpoint.y)
        let projection = dx * Double(normal.dx) + dy * Double(normal.dy)
        return normalizedPosition(0.5 + projection / Double(size.height))
    }

    static func toCoreImagePoint(_ point: CGPoint, extent: CGRect) -> CGPoint {
        CGPoint(
            x: extent.origin.x + point.x,
            y: extent.origin.y + (extent.height - point.y)
        )
    }
}
