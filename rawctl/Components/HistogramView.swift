//
//  HistogramView.swift
//  rawctl
//
//  Real histogram computed from image pixels
//

import SwiftUI
import AppKit

/// Real histogram view computed from preview image
struct HistogramView: View {
    let image: NSImage?
    let appState: AppState
    
    @State private var histogramData: HistogramData?
    @State private var showRGB = true
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: NSColor(calibratedWhite: 0.1, alpha: 1.0)))
            
            if let data = histogramData {
                GeometryReader { geometry in
                    ZStack {
                        if showRGB {
                            // RGB channels
                            HistogramChannel(values: data.red, color: .red.opacity(0.5), size: geometry.size)
                            HistogramChannel(values: data.green, color: .green.opacity(0.5), size: geometry.size)
                            HistogramChannel(values: data.blue, color: .blue.opacity(0.5), size: geometry.size)
                        } else {
                            // Luminance only
                            HistogramChannel(values: data.luminance, color: .white.opacity(0.6), size: geometry.size)
                        }
                    }
                }
                .padding(8)
            } else if image == nil {
                // No image selected
                VStack(spacing: 4) {
                    Image(systemName: "photo")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Select a photo")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                // Loading state (image exists but computing)
                ProgressView()
                    .scaleEffect(0.6)
            }
            
            // Labels and controls
            VStack {
                HStack {
                    Text("Histogram")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: { showRGB.toggle() }) {
                        Image(systemName: showRGB ? "circle.grid.3x3" : "circle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(showRGB ? "Show Luminance" : "Show RGB")
                }
                
                Spacer()
                
                // Clipping Buttons
                HStack(spacing: 8) {
                    // Shadow clipping toggle
                    Button(action: { appState.showShadowClipping.toggle() }) {
                        Image(systemName: appState.showShadowClipping ? "shadow.fill" : "shadow")
                            .font(.system(size: 10))
                            .foregroundColor(appState.showShadowClipping ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Show Shadow Clipping")
                    
                    Spacer()
                    
                    // Highlight clipping toggle
                    Button(action: { appState.showHighlightClipping.toggle() }) {
                        Image(systemName: appState.showHighlightClipping ? "sun.max.fill" : "sun.max")
                            .font(.system(size: 10))
                            .foregroundColor(appState.showHighlightClipping ? .red : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Show Highlight Clipping")
                }
            }
            .padding(8)
        }
        .frame(height: 80)
        .onChange(of: image) { _, newImage in
            computeHistogram(from: newImage)
        }
        .task(id: image) {
            computeHistogram(from: image)
        }
    }
    
    private func computeHistogram(from image: NSImage?) {
        guard let image = image else {
            histogramData = nil
            return
        }
        
        Task.detached(priority: .userInitiated) {
            let data = await HistogramData.compute(from: image)
            await MainActor.run {
                self.histogramData = data
            }
        }
    }
}

/// Single histogram channel path
struct HistogramChannel: View {
    let values: [Double]
    let color: Color
    let size: CGSize
    
    var body: some View {
        Path { path in
            guard !values.isEmpty else { return }
            
            let width = size.width
            let height = size.height
            let binCount = values.count
            let binWidth = width / CGFloat(binCount)
            
            // Find max for normalization
            let maxValue = values.max() ?? 1
            
            path.move(to: CGPoint(x: 0, y: height))
            
            for (i, value) in values.enumerated() {
                let x = CGFloat(i) * binWidth + binWidth / 2
                let normalized = maxValue > 0 ? value / maxValue : 0
                let y = height - normalized * height * 0.95
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            path.addLine(to: CGPoint(x: width, y: height))
            path.closeSubpath()
        }
        .fill(color)
    }
}

/// Histogram data container
struct HistogramData {
    let red: [Double]
    let green: [Double]
    let blue: [Double]
    let luminance: [Double]
    
    static let binCount = 64
    
    static func compute(from image: NSImage) async -> HistogramData {
        // Get bitmap representation
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return empty()
        }
        
        var redBins = [Double](repeating: 0, count: binCount)
        var greenBins = [Double](repeating: 0, count: binCount)
        var blueBins = [Double](repeating: 0, count: binCount)
        var lumBins = [Double](repeating: 0, count: binCount)
        
        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh
        
        // Sample every Nth pixel for performance
        let step = max(1, (width * height) / 50000)
        var sampleCount = 0
        
        for y in stride(from: 0, to: height, by: Int(sqrt(Double(step)))) {
            for x in stride(from: 0, to: width, by: Int(sqrt(Double(step)))) {
                guard let color = bitmap.colorAt(x: x, y: y) else { continue }
                
                let r = color.redComponent
                let g = color.greenComponent
                let b = color.blueComponent
                
                // Bin indices (0-63)
                let rBin = min(binCount - 1, Int(r * Double(binCount - 1)))
                let gBin = min(binCount - 1, Int(g * Double(binCount - 1)))
                let bBin = min(binCount - 1, Int(b * Double(binCount - 1)))
                
                // Luminance (standard weights)
                let lum = 0.299 * r + 0.587 * g + 0.114 * b
                let lumBin = min(binCount - 1, Int(lum * Double(binCount - 1)))
                
                redBins[rBin] += 1
                greenBins[gBin] += 1
                blueBins[bBin] += 1
                lumBins[lumBin] += 1
                sampleCount += 1
            }
        }
        
        return HistogramData(
            red: redBins,
            green: greenBins,
            blue: blueBins,
            luminance: lumBins
        )
    }
    
    static func empty() -> HistogramData {
        HistogramData(
            red: [Double](repeating: 0, count: binCount),
            green: [Double](repeating: 0, count: binCount),
            blue: [Double](repeating: 0, count: binCount),
            luminance: [Double](repeating: 0, count: binCount)
        )
    }
}

#Preview {
    HistogramView(image: nil, appState: AppState())
        .frame(width: 280)
        .padding()
        .preferredColorScheme(.dark)
}
