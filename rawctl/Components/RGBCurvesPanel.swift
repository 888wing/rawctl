//
//  RGBCurvesPanel.swift
//  rawctl
//
//  Per-channel RGB curve editor with stable drag support
//

import SwiftUI

/// RGB Curves panel with channel selector
struct RGBCurvesPanel: View {
    @Binding var curves: RGBCurves
    
    @State private var selectedChannel: CurveChannel = .master
    @State private var draggedPointId: UUID?
    
    enum CurveChannel: String, CaseIterable {
        case master = "RGB"
        case red = "R"
        case green = "G"
        case blue = "B"
        
        var color: Color {
            switch self {
            case .master: return .white
            case .red: return .red
            case .green: return .green
            case .blue: return .blue
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Channel selector
            HStack(spacing: 4) {
                ForEach(CurveChannel.allCases, id: \.self) { channel in
                    Button(action: { selectedChannel = channel }) {
                        Text(channel.rawValue)
                            .font(.caption.bold())
                            .foregroundColor(selectedChannel == channel ? channel.color : .gray)
                            .frame(width: 32, height: 22)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(selectedChannel == channel ? Color.black.opacity(0.3) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                // Reset button
                Button(action: { resetCurrentChannel() }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("Reset \(selectedChannel.rawValue)")
            }
            
            // Curve editor
            curveEditor
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private var curveEditor: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let insetSize = CGSize(width: size.width - 16, height: size.height - 16)
            
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(white: 0.12))
                
                // Grid
                gridLines(size: size, insetSize: insetSize)
                
                // Diagonal reference
                diagonalLine(size: size)
                
                // Smooth curve (200 samples)
                curvePath(insetSize: insetSize)
                
                // Control points
                ForEach(currentPoints) { point in
                    controlPoint(point: point, insetSize: insetSize)
                }
            }
            .padding(8)
            .contentShape(Rectangle())
            .onTapGesture { location in
                addPointIfNotNear(location: CGPoint(x: location.x - 8, y: location.y - 8), size: insetSize)
            }
        }
        .frame(height: 120)
    }
    
    // MARK: - Drawing
    
    private func gridLines(size: CGSize, insetSize: CGSize) -> some View {
        Path { path in
            for i in 1..<4 {
                let x = 8 + insetSize.width * CGFloat(i) / 4
                path.move(to: CGPoint(x: x, y: 8))
                path.addLine(to: CGPoint(x: x, y: 8 + insetSize.height))
                
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
    
    private func curvePath(insetSize: CGSize) -> some View {
        Path { path in
            let sortedPoints = currentPoints.sorted { $0.x < $1.x }
            guard sortedPoints.count >= 2 else { return }
            
            let steps = 200
            let startY = evaluateCurve(at: 0, points: sortedPoints)
            path.move(to: CGPoint(x: 8, y: 8 + (1 - startY) * insetSize.height))
            
            for i in 1...steps {
                let t = Double(i) / Double(steps)
                let y = evaluateCurve(at: t, points: sortedPoints)
                path.addLine(to: CGPoint(
                    x: 8 + CGFloat(t) * insetSize.width,
                    y: 8 + CGFloat(1 - y) * insetSize.height
                ))
            }
        }
        .stroke(selectedChannel.color, lineWidth: 2)
    }
    
    private func controlPoint(point: CurvePoint, insetSize: CGSize) -> some View {
        let screenPos = CGPoint(
            x: 8 + CGFloat(point.x) * insetSize.width,
            y: 8 + CGFloat(1 - point.y) * insetSize.height
        )
        let isSelected = draggedPointId == point.id
        
        return Circle()
            .fill(isSelected ? Color.accentColor : selectedChannel.color)
            .frame(width: 12, height: 12)
            .position(screenPos)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        draggedPointId = point.id
                        let newX = (value.location.x - 8) / insetSize.width
                        let newY = 1 - (value.location.y - 8) / insetSize.height
                        updateCurrentPoint(id: point.id, x: newX, y: newY)
                    }
                    .onEnded { _ in
                        draggedPointId = nil
                    }
            )
            .onTapGesture(count: 2) {
                removeCurrentPoint(id: point.id)
            }
    }
    
    // MARK: - Catmull-Rom Interpolation
    
    private func evaluateCurve(at x: Double, points: [CurvePoint]) -> Double {
        guard points.count >= 2 else { return x }
        
        var i = 0
        while i < points.count - 1 && points[i + 1].x < x {
            i += 1
        }
        
        if i >= points.count - 1 {
            return points.last?.y ?? x
        }
        
        let p1 = points[i]
        let p2 = points[i + 1]
        let p0 = i > 0 ? points[i - 1] : CurvePoint(x: p1.x - 0.25, y: p1.y)
        let p3 = i < points.count - 2 ? points[i + 2] : CurvePoint(x: p2.x + 0.25, y: p2.y)
        
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
    
    // MARK: - Data Binding Helpers
    
    private var currentPoints: [CurvePoint] {
        switch selectedChannel {
        case .master: return curves.master
        case .red: return curves.red
        case .green: return curves.green
        case .blue: return curves.blue
        }
    }
    
    private func updateCurrentPoint(id: UUID, x: Double, y: Double) {
        let sortedPoints = currentPoints.sorted { $0.x < $1.x }
        let isFirst = sortedPoints.first?.id == id
        let isLast = sortedPoints.last?.id == id
        
        let clampedX = isFirst || isLast ? (isFirst ? 0 : 1) : max(0.01, min(0.99, x))
        let clampedY = max(0, min(1, y))
        
        switch selectedChannel {
        case .master:
            if let idx = curves.master.firstIndex(where: { $0.id == id }) {
                curves.master[idx].x = clampedX
                curves.master[idx].y = clampedY
            }
        case .red:
            if let idx = curves.red.firstIndex(where: { $0.id == id }) {
                curves.red[idx].x = clampedX
                curves.red[idx].y = clampedY
            }
        case .green:
            if let idx = curves.green.firstIndex(where: { $0.id == id }) {
                curves.green[idx].x = clampedX
                curves.green[idx].y = clampedY
            }
        case .blue:
            if let idx = curves.blue.firstIndex(where: { $0.id == id }) {
                curves.blue[idx].x = clampedX
                curves.blue[idx].y = clampedY
            }
        }
    }
    
    private func removeCurrentPoint(id: UUID) {
        let sortedPoints = currentPoints.sorted { $0.x < $1.x }
        guard sortedPoints.count > 2 else { return }
        if sortedPoints.first?.id == id || sortedPoints.last?.id == id { return }
        
        switch selectedChannel {
        case .master: curves.master.removeAll { $0.id == id }
        case .red: curves.red.removeAll { $0.id == id }
        case .green: curves.green.removeAll { $0.id == id }
        case .blue: curves.blue.removeAll { $0.id == id }
        }
    }
    
    private func addPointIfNotNear(location: CGPoint, size: CGSize) {
        let x = location.x / size.width
        guard x > 0.02 && x < 0.98 else { return }
        
        for point in currentPoints {
            let pointScreen = CGPoint(x: point.x * size.width, y: (1 - point.y) * size.height)
            if hypot(location.x - pointScreen.x, location.y - pointScreen.y) < 20 {
                return
            }
        }
        
        let sortedPoints = currentPoints.sorted { $0.x < $1.x }
        let y = evaluateCurve(at: x, points: sortedPoints)
        let newPoint = CurvePoint(x: x, y: y)
        
        switch selectedChannel {
        case .master: curves.master.append(newPoint)
        case .red: curves.red.append(newPoint)
        case .green: curves.green.append(newPoint)
        case .blue: curves.blue.append(newPoint)
        }
    }
    
    private func resetCurrentChannel() {
        let defaultPoints = RGBCurves.defaultCurve()
        switch selectedChannel {
        case .master: curves.master = defaultPoints
        case .red: curves.red = defaultPoints
        case .green: curves.green = defaultPoints
        case .blue: curves.blue = defaultPoints
        }
    }
}

#Preview {
    RGBCurvesPanel(curves: .constant(RGBCurves()))
        .frame(width: 280)
        .padding()
        .preferredColorScheme(.dark)
}
