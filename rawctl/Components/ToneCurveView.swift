//
//  ToneCurveView.swift
//  rawctl
//
//  Interactive tone curve editor with stable drag support
//

import SwiftUI

/// Tone curve data model
struct ToneCurve: Codable, Equatable {
    var points: [CurvePoint] = ToneCurve.defaultPoints()
    
    static func defaultPoints() -> [CurvePoint] {
        [
            CurvePoint(x: 0, y: 0),
            CurvePoint(x: 0.25, y: 0.25),
            CurvePoint(x: 0.5, y: 0.5),
            CurvePoint(x: 0.75, y: 0.75),
            CurvePoint(x: 1, y: 1)
        ]
    }
    
    /// Check if curve has edits (deviates from linear identity)
    var hasEdits: Bool {
        for point in points {
            if abs(point.x - point.y) > 0.01 {
                return true
            }
        }
        return false
    }
    
    // Uses global CurvePoint from EditRecipe
    
    /// Reset to linear
    mutating func reset() {
        points = ToneCurve.defaultPoints()
    }
    
    /// Get sorted points for display/evaluation
    var sortedPoints: [CurvePoint] {
        points.sorted { $0.x < $1.x }
    }
    
    /// Evaluate curve at x using Catmull-Rom spline
    func evaluate(at x: Double) -> Double {
        guard points.count >= 2 else { return x }
        
        let sorted = sortedPoints
        
        // Find surrounding points
        var i = 0
        while i < sorted.count - 1 && sorted[i + 1].x < x {
            i += 1
        }
        
        if i >= sorted.count - 1 {
            return sorted.last?.y ?? x
        }
        
        let p1 = sorted[i]
        let p2 = sorted[i + 1]
        
        // Catmull-Rom spline interpolation
        let p0 = i > 0 ? sorted[i - 1] : CurvePoint(x: p1.x - 0.25, y: p1.y)
        let p3 = i < sorted.count - 2 ? sorted[i + 2] : CurvePoint(x: p2.x + 0.25, y: p2.y)
        
        let t = (x - p1.x) / (p2.x - p1.x + 0.0001)
        let t2 = t * t
        let t3 = t2 * t
        
        let y = 0.5 * (
            (2 * p1.y) +
            (-p0.y + p2.y) * t +
            (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 +
            (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3
        )
        
        return max(0, min(1, y))
    }
    
    /// Add a new point
    mutating func addPoint(at x: Double) {
        let y = evaluate(at: x)
        let newPoint = CurvePoint(x: x, y: y)
        points.append(newPoint)
    }
    
    /// Remove point by ID (keep first and last sorted)
    mutating func removePoint(id: UUID) {
        let sorted = sortedPoints
        guard sorted.count > 2 else { return }
        
        // Don't remove first or last point
        if sorted.first?.id == id || sorted.last?.id == id {
            return
        }
        
        points.removeAll { $0.id == id }
    }
    
    /// Update point position by ID
    mutating func updatePoint(id: UUID, x: Double, y: Double) {
        guard let index = points.firstIndex(where: { $0.id == id }) else { return }
        
        let sorted = sortedPoints
        let isFirst = sorted.first?.id == id
        let isLast = sorted.last?.id == id
        
        // First/last points: only Y movable
        if isFirst || isLast {
            points[index].y = max(0, min(1, y))
        } else {
            points[index].x = max(0.01, min(0.99, x))
            points[index].y = max(0, min(1, y))
        }
    }
}

/// Interactive tone curve editor view
struct ToneCurveView: View {
    @Binding var curve: ToneCurve
    @State private var draggedPointId: UUID?
    var curveColor: Color = .white
    var showLabel: Bool = true
    
    var body: some View {
        VStack(spacing: 4) {
            if showLabel {
                HStack {
                    Text("Tone Curve")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: { curve.reset() }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .help("Reset curve")
                }
            }
            
            GeometryReader { geometry in
                let size = geometry.size
                
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(white: 0.12))
                    
                    // Grid lines
                    gridLines(size: size)
                    
                    // Diagonal reference line
                    diagonalLine(size: size)
                    
                    // Smooth curve
                    curvePath(size: size)
                    
                    // Control points
                    ForEach(curve.points) { point in
                        controlPoint(point: point, size: size)
                    }
                }
                .padding(8)
                .contentShape(Rectangle())
                .onTapGesture { location in
                    // Tap to add point (only if not near existing point)
                    let adjustedLocation = CGPoint(
                        x: location.x - 8,
                        y: location.y - 8
                    )
                    let adjustedSize = CGSize(
                        width: size.width - 16,
                        height: size.height - 16
                    )
                    addPointIfNotNear(location: adjustedLocation, size: adjustedSize)
                }
            }
            .frame(height: 140)
        }
    }
    
    // MARK: - Subviews
    
    private func gridLines(size: CGSize) -> some View {
        Path { path in
            let insetSize = CGSize(width: size.width - 16, height: size.height - 16)
            // Vertical
            for i in 1..<4 {
                let x = 8 + insetSize.width * CGFloat(i) / 4
                path.move(to: CGPoint(x: x, y: 8))
                path.addLine(to: CGPoint(x: x, y: 8 + insetSize.height))
            }
            // Horizontal
            for i in 1..<4 {
                let y = 8 + insetSize.height * CGFloat(i) / 4
                path.move(to: CGPoint(x: 8, y: y))
                path.addLine(to: CGPoint(x: 8 + insetSize.width, y: y))
            }
        }
        .stroke(Color.white.opacity(0.1), lineWidth: 1)
    }
    
    private func diagonalLine(size: CGSize) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 8, y: size.height - 8))
            path.addLine(to: CGPoint(x: size.width - 8, y: 8))
        }
        .stroke(Color.white.opacity(0.2), lineWidth: 1)
    }
    
    private func curvePath(size: CGSize) -> some View {
        let insetSize = CGSize(width: size.width - 16, height: size.height - 16)
        
        return Path { path in
            let steps = 200
            let startY = curve.evaluate(at: 0)
            path.move(to: CGPoint(x: 8, y: 8 + (1 - startY) * insetSize.height))
            
            for i in 1...steps {
                let x = Double(i) / Double(steps)
                let y = curve.evaluate(at: x)
                path.addLine(to: CGPoint(
                    x: 8 + CGFloat(x) * insetSize.width,
                    y: 8 + CGFloat(1 - y) * insetSize.height
                ))
            }
        }
        .stroke(curveColor, lineWidth: 2)
    }
    
    private func controlPoint(point: CurvePoint, size: CGSize) -> some View {
        let insetSize = CGSize(width: size.width - 16, height: size.height - 16)
        let screenPos = CGPoint(
            x: 8 + CGFloat(point.x) * insetSize.width,
            y: 8 + CGFloat(1 - point.y) * insetSize.height
        )
        
        let isSelected = draggedPointId == point.id
        
        return Circle()
            .fill(isSelected ? Color.accentColor : curveColor)
            .frame(width: 14, height: 14)
            .position(screenPos)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        draggedPointId = point.id
                        let newX = (value.location.x - 8) / insetSize.width
                        let newY = 1 - (value.location.y - 8) / insetSize.height
                        curve.updatePoint(id: point.id, x: newX, y: newY)
                    }
                    .onEnded { _ in
                        draggedPointId = nil
                    }
            )
            .onTapGesture(count: 2) {
                curve.removePoint(id: point.id)
            }
    }
    
    // MARK: - Helpers
    
    private func addPointIfNotNear(location: CGPoint, size: CGSize) {
        let x = location.x / size.width
        
        // Check if too close to existing point
        for point in curve.points {
            let pointScreen = CGPoint(
                x: point.x * size.width,
                y: (1 - point.y) * size.height
            )
            let distance = hypot(location.x - pointScreen.x, location.y - pointScreen.y)
            if distance < 25 {
                return // Too close
            }
        }
        
        if x > 0.02 && x < 0.98 {
            curve.addPoint(at: x)
        }
    }
}

#Preview {
    ToneCurveView(curve: .constant(ToneCurve()))
        .frame(width: 280)
        .padding()
        .preferredColorScheme(.dark)
}
