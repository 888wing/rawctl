//
//  OnImageScrubber.swift
//  rawctl
//
//  On-image parameter adjustment via key + drag
//

import SwiftUI

/// Parameter that can be adjusted via on-image scrubbing
enum ScrubParameter: String, CaseIterable {
    case exposure = "E"
    case contrast = "C"
    case saturation = "S"
    case highlights = "H"
    case shadows = "D"  // D for darks/shadows
    case temperature = "T"
    
    var label: String {
        switch self {
        case .exposure: return "Exposure"
        case .contrast: return "Contrast"
        case .saturation: return "Saturation"
        case .highlights: return "Highlights"
        case .shadows: return "Shadows"
        case .temperature: return "Temperature"
        }
    }
    
    var icon: String {
        switch self {
        case .exposure: return "sun.max"
        case .contrast: return "circle.lefthalf.filled"
        case .saturation: return "paintpalette"
        case .highlights: return "sun.min"
        case .shadows: return "moon"
        case .temperature: return "thermometer.sun"
        }
    }
    
    var range: ClosedRange<Double> {
        switch self {
        case .exposure: return -5...5
        case .contrast, .saturation, .highlights, .shadows: return -100...100
        case .temperature: return 2000...10000
        }
    }
    
    var sensitivity: Double {
        switch self {
        case .exposure: return 0.02     // ±5 over ~500px drag
        case .temperature: return 20    // ±8000 over ~400px drag
        default: return 0.5             // ±100 over ~400px drag
        }
    }
}

/// Overlay showing active scrub parameter and value
struct ScrubOverlay: View {
    let parameter: ScrubParameter
    let value: Double
    let isActive: Bool
    
    var body: some View {
        if isActive {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: parameter.icon)
                        .font(.system(size: 16, weight: .medium))
                    
                    Text(parameter.label)
                        .font(.system(size: 14, weight: .semibold))
                }
                
                Text(formattedValue)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                
                Text("Drag left/right to adjust")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.black.opacity(0.75))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }
    
    private var formattedValue: String {
        switch parameter {
        case .exposure:
            return String(format: "%+.2f", value)
        case .temperature:
            return String(format: "%.0fK", value)
        default:
            return String(format: "%+.0f", value)
        }
    }
}

/// View modifier that adds on-image scrubbing capability
struct OnImageScrubberModifier: ViewModifier {
    @Binding var recipe: EditRecipe
    let onDragStart: () -> Void
    let onDragEnd: () -> Void
    
    @State private var activeParameter: ScrubParameter?
    @State private var startValue: Double = 0
    @State private var dragStartX: CGFloat = 0
    @State private var pressedKeys: Set<String> = []
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .center) {
                if let param = activeParameter {
                    ScrubOverlay(
                        parameter: param,
                        value: getValue(for: param),
                        isActive: true
                    )
                }
            }
            .gesture(scrubGesture)
            .onKeyPress(phases: .down) { keyPress in
                let key = keyPress.characters.uppercased()
                if ScrubParameter.allCases.contains(where: { $0.rawValue == key }) {
                    pressedKeys.insert(key)
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(phases: .up) { keyPress in
                let key = keyPress.characters.uppercased()
                pressedKeys.remove(key)
                if activeParameter?.rawValue == key {
                    withAnimation(.easeOut(duration: 0.15)) {
                        activeParameter = nil
                    }
                }
                return .ignored
            }
    }
    
    private var scrubGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { gesture in
                // Check if a parameter key is pressed
                if activeParameter == nil {
                    for key in pressedKeys {
                        if let param = ScrubParameter.allCases.first(where: { $0.rawValue == key }) {
                            // Start scrubbing
                            withAnimation(.easeIn(duration: 0.1)) {
                                activeParameter = param
                            }
                            startValue = getValue(for: param)
                            dragStartX = gesture.startLocation.x
                            onDragStart()
                            break
                        }
                    }
                }
                
                guard let param = activeParameter else { return }
                
                // Calculate delta
                let deltaX = gesture.location.x - dragStartX
                let delta = deltaX * param.sensitivity
                
                // Apply new value with clamping
                let newValue = (startValue + delta).clamped(to: param.range)
                setValue(newValue, for: param)
            }
            .onEnded { _ in
                if activeParameter != nil {
                    withAnimation(.easeOut(duration: 0.15)) {
                        activeParameter = nil
                    }
                    pressedKeys.removeAll()
                    onDragEnd()
                }
            }
    }
    
    private func getValue(for parameter: ScrubParameter) -> Double {
        switch parameter {
        case .exposure: return recipe.exposure
        case .contrast: return recipe.contrast
        case .saturation: return recipe.saturation
        case .highlights: return recipe.highlights
        case .shadows: return recipe.shadows
        case .temperature: return Double(recipe.whiteBalance.temperature)
        }
    }
    
    private func setValue(_ value: Double, for parameter: ScrubParameter) {
        switch parameter {
        case .exposure: recipe.exposure = value
        case .contrast: recipe.contrast = value
        case .saturation: recipe.saturation = value
        case .highlights: recipe.highlights = value
        case .shadows: recipe.shadows = value
        case .temperature: recipe.whiteBalance.temperature = Int(value)
        }
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

extension View {
    func onImageScrubber(
        recipe: Binding<EditRecipe>,
        onDragStart: @escaping () -> Void = {},
        onDragEnd: @escaping () -> Void = {}
    ) -> some View {
        modifier(OnImageScrubberModifier(
            recipe: recipe,
            onDragStart: onDragStart,
            onDragEnd: onDragEnd
        ))
    }
}

/// Hint overlay showing available scrub keys
struct ScrubHintOverlay: View {
    let isVisible: Bool
    
    var body: some View {
        if isVisible {
            VStack(alignment: .leading, spacing: 6) {
                Text("On-Image Adjustment")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                
                ForEach(ScrubParameter.allCases, id: \.self) { param in
                    HStack(spacing: 8) {
                        Text(param.rawValue)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .frame(width: 16, height: 16)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(3)
                        
                        Text("+ drag → \(param.label)")
                            .font(.caption2)
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.black.opacity(0.7))
            )
            .transition(.opacity)
        }
    }
}

#Preview {
    VStack {
        ScrubOverlay(parameter: .exposure, value: 0.75, isActive: true)
        ScrubOverlay(parameter: .temperature, value: 5500, isActive: true)
        ScrubHintOverlay(isVisible: true)
    }
    .padding()
    .preferredColorScheme(.dark)
}
