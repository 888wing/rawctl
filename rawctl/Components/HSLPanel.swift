//
//  HSLPanel.swift
//  rawctl
//
//  HSL (Hue/Saturation/Luminance) adjustment panel for per-color control
//

import SwiftUI

/// HSL adjustment panel with 8 color channels
struct HSLPanel: View {
    @Binding var hsl: HSLAdjustment
    
    @State private var selectedChannel: ColorChannel = .red
    
    enum ColorChannel: String, CaseIterable {
        case red = "R"
        case orange = "O"
        case yellow = "Y"
        case green = "G"
        case cyan = "C"
        case blue = "B"
        case purple = "P"
        case magenta = "M"
        
        var color: Color {
            switch self {
            case .red: return .red
            case .orange: return .orange
            case .yellow: return .yellow
            case .green: return .green
            case .cyan: return .cyan
            case .blue: return .blue
            case .purple: return .purple
            case .magenta: return .pink
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Channel selector
            HStack(spacing: 2) {
                ForEach(ColorChannel.allCases, id: \.self) { channel in
                    Button(action: { selectedChannel = channel }) {
                        Circle()
                            .fill(channel.color)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(selectedChannel == channel ? Color.white : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            
            // Current channel label
            Text(selectedChannel.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // HSL sliders for selected channel
            VStack(spacing: 8) {
                HSLSliderRow(
                    label: "Hue",
                    value: binding(for: selectedChannel, keyPath: \.hue),
                    range: -100...100,
                    color: selectedChannel.color
                )
                
                HSLSliderRow(
                    label: "Sat",
                    value: binding(for: selectedChannel, keyPath: \.saturation),
                    range: -100...100,
                    color: selectedChannel.color
                )
                
                HSLSliderRow(
                    label: "Lum",
                    value: binding(for: selectedChannel, keyPath: \.luminance),
                    range: -100...100,
                    color: selectedChannel.color
                )
            }
            
            // Reset button
            if hasEditsForChannel(selectedChannel) {
                Button("Reset \(selectedChannel.rawValue)") {
                    resetChannel(selectedChannel)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - Bindings
    
    private func binding(for channel: ColorChannel, keyPath: WritableKeyPath<HSLChannel, Double>) -> Binding<Double> {
        switch channel {
        case .red: return Binding(get: { hsl.red[keyPath: keyPath] }, set: { hsl.red[keyPath: keyPath] = $0 })
        case .orange: return Binding(get: { hsl.orange[keyPath: keyPath] }, set: { hsl.orange[keyPath: keyPath] = $0 })
        case .yellow: return Binding(get: { hsl.yellow[keyPath: keyPath] }, set: { hsl.yellow[keyPath: keyPath] = $0 })
        case .green: return Binding(get: { hsl.green[keyPath: keyPath] }, set: { hsl.green[keyPath: keyPath] = $0 })
        case .cyan: return Binding(get: { hsl.cyan[keyPath: keyPath] }, set: { hsl.cyan[keyPath: keyPath] = $0 })
        case .blue: return Binding(get: { hsl.blue[keyPath: keyPath] }, set: { hsl.blue[keyPath: keyPath] = $0 })
        case .purple: return Binding(get: { hsl.purple[keyPath: keyPath] }, set: { hsl.purple[keyPath: keyPath] = $0 })
        case .magenta: return Binding(get: { hsl.magenta[keyPath: keyPath] }, set: { hsl.magenta[keyPath: keyPath] = $0 })
        }
    }
    
    private func hasEditsForChannel(_ channel: ColorChannel) -> Bool {
        switch channel {
        case .red: return hsl.red.hasEdits
        case .orange: return hsl.orange.hasEdits
        case .yellow: return hsl.yellow.hasEdits
        case .green: return hsl.green.hasEdits
        case .cyan: return hsl.cyan.hasEdits
        case .blue: return hsl.blue.hasEdits
        case .purple: return hsl.purple.hasEdits
        case .magenta: return hsl.magenta.hasEdits
        }
    }
    
    private func resetChannel(_ channel: ColorChannel) {
        switch channel {
        case .red: hsl.red = HSLChannel()
        case .orange: hsl.orange = HSLChannel()
        case .yellow: hsl.yellow = HSLChannel()
        case .green: hsl.green = HSLChannel()
        case .cyan: hsl.cyan = HSLChannel()
        case .blue: hsl.blue = HSLChannel()
        case .purple: hsl.purple = HSLChannel()
        case .magenta: hsl.magenta = HSLChannel()
        }
    }
}

/// Single HSL slider row
struct HSLSliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)
            
            Slider(value: $value, in: range)
                .tint(color)
            
            Text(String(format: "%+.0f", value))
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(width: 35, alignment: .trailing)
        }
    }
}

#Preview {
    HSLPanel(hsl: .constant(HSLAdjustment()))
        .frame(width: 280)
        .padding()
}
