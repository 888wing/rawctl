//
//  WhiteBalancePanel.swift
//  rawctl
//
//  White balance controls with presets and eyedropper
//

import SwiftUI

/// White balance panel with presets, Kelvin slider, and eyedropper
struct WhiteBalancePanel: View {
    @Binding var whiteBalance: WhiteBalance
    @Binding var eyedropperMode: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Preset buttons grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 4) {
                ForEach(WBPreset.allCases) { preset in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            whiteBalance.applyPreset(preset)
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: preset.icon)
                                .font(.system(size: 12))
                            Text(preset.displayName)
                                .font(.system(size: 8))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(whiteBalance.preset == preset ? Color.accentColor : Color.gray.opacity(0.2))
                        .foregroundColor(whiteBalance.preset == preset ? .white : .secondary)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Divider()
            
            // Temperature slider (Kelvin)
            VStack(spacing: 4) {
                HStack {
                    Text("Temperature")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(whiteBalance.temperature)K")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                // Gradient background for slider
                ZStack {
                    LinearGradient(
                        colors: [.blue, .white, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 6)
                    .cornerRadius(3)
                    
                    Slider(
                        value: Binding(
                            get: { Double(whiteBalance.temperature) },
                            set: { 
                                whiteBalance.temperature = Int($0)
                                whiteBalance.preset = .custom
                            }
                        ),
                        in: 2000...12000,
                        step: 100
                    )
                }
            }
            
            // Tint slider (Green-Magenta)
            VStack(spacing: 4) {
                HStack {
                    Text("Tint")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(whiteBalance.tint >= 0 ? "+\(whiteBalance.tint)" : "\(whiteBalance.tint)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                ZStack {
                    LinearGradient(
                        colors: [.green, .white, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 6)
                    .cornerRadius(3)
                    
                    Slider(
                        value: Binding(
                            get: { Double(whiteBalance.tint) },
                            set: { 
                                whiteBalance.tint = Int($0)
                                whiteBalance.preset = .custom
                            }
                        ),
                        in: -150...150,
                        step: 1
                    )
                }
            }
            
            Divider()
            
            // Eyedropper button
            Button {
                eyedropperMode.toggle()
            } label: {
                HStack {
                    Image(systemName: "eyedropper")
                    Text("Pick White Point")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(eyedropperMode ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundColor(eyedropperMode ? .white : .secondary)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            
            if eyedropperMode {
                Text("Click on a neutral gray or white area in the image")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

#Preview {
    WhiteBalancePanel(
        whiteBalance: .constant(WhiteBalance()),
        eyedropperMode: .constant(false)
    )
    .frame(width: 260)
    .padding()
    .preferredColorScheme(.dark)
}
