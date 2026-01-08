//
//  ControlSlider.swift
//  rawctl
//
//  Reusable slider component with label and value display
//

import SwiftUI

/// Notification for global drag state (for preview quality switching)
extension Notification.Name {
    static let sliderDragStateChanged = Notification.Name("sliderDragStateChanged")
}

/// Custom slider control with enhanced visual feedback
struct ControlSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var format: String = "%.0f"
    var showSign: Bool = true
    var defaultValue: Double = 0
    
    // Performance callbacks
    var onDragStart: (() -> Void)?
    var onDragEnd: (() -> Void)?
    
    @State private var isEditing = false
    @State private var isDragging = false
    @State private var isHovering = false
    @State private var editText = ""
    @State private var valueAtDragStart: Double = 0
    @State private var labelBounce = false
    @FocusState private var isTextFieldFocused: Bool
    
    // Thumb sizes
    private let thumbSize: CGFloat = 16
    private let thumbHoverSize: CGFloat = 20
    private let trackHeight: CGFloat = 5
    
    var body: some View {
        VStack(spacing: 4) {
            // Label row with enhanced feedback
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: value != defaultValue ? .medium : .regular))
                    .foregroundColor(value != defaultValue ? .primary : .secondary)
                
                Spacer()
                
                if isEditing {
                    TextField("", text: $editText)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .frame(width: 55)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.2))
                        .cornerRadius(4)
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            applyEditedValue()
                        }
                        .onAppear {
                            editText = String(format: format, value)
                            isTextFieldFocused = true
                        }
                } else {
                    Text(formattedValue)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(value != defaultValue ? .accentColor : .secondary)
                        .scaleEffect(labelBounce ? 1.1 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: labelBounce)
                        .onTapGesture {
                            isEditing = true
                        }
                }
            }
            
            // Enhanced slider track
            GeometryReader { geometry in
                let width = geometry.size.width
                let normalizedValue = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
                let centerNormalized = (defaultValue - range.lowerBound) / (range.upperBound - range.lowerBound)
                let currentThumbSize = isDragging ? thumbHoverSize : (isHovering ? thumbHoverSize : thumbSize)
                
                ZStack(alignment: .leading) {
                    // Track background with subtle gradient
                    RoundedRectangle(cornerRadius: trackHeight / 2)
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.18), Color(white: 0.22)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: trackHeight)
                    
                    // Active fill with gradient
                    if defaultValue == range.lowerBound {
                        // Fill from left (e.g., 0-100 range)
                        RoundedRectangle(cornerRadius: trackHeight / 2)
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentColor.opacity(0.9), Color.accentColor.opacity(0.6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, normalizedValue * width), height: trackHeight)
                    } else {
                        // Fill from center (e.g., -100 to +100 range)
                        let centerX = centerNormalized * width
                        let currentX = normalizedValue * width
                        let fillStart = min(centerX, currentX)
                        let fillWidth = abs(currentX - centerX)
                        
                        RoundedRectangle(cornerRadius: trackHeight / 2)
                            .fill(
                                value >= defaultValue
                                    ? LinearGradient(colors: [Color.accentColor.opacity(0.7), Color.accentColor], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: max(0, fillWidth), height: trackHeight)
                            .offset(x: fillStart)
                    }
                    
                    // Center marker for bipolar sliders
                    if defaultValue != range.lowerBound {
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 1, height: trackHeight + 4)
                            .offset(x: centerNormalized * width - 0.5)
                    }
                    
                    // Enhanced Thumb
                    ZStack {
                        // Outer glow when dragging
                        if isDragging {
                            Circle()
                                .fill(Color.accentColor.opacity(0.3))
                                .frame(width: currentThumbSize + 8, height: currentThumbSize + 8)
                                .blur(radius: 4)
                        }
                        
                        // Main thumb
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white, Color(white: 0.9)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: currentThumbSize, height: currentThumbSize)
                            .shadow(
                                color: .black.opacity(isDragging ? 0.4 : 0.25),
                                radius: isDragging ? 4 : 2,
                                y: isDragging ? 2 : 1
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                            )
                    }
                    .offset(x: normalizedValue * (width - currentThumbSize))
                    .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.8), value: currentThumbSize)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                if !isDragging {
                                    isDragging = true
                                    valueAtDragStart = value
                                    onDragStart?()
                                    NotificationCenter.default.post(name: .sliderDragStateChanged, object: true)
                                }
                                
                                // Check for Option key for fine adjustment
                                let sensitivity: Double = NSEvent.modifierFlags.contains(.option) ? 0.1 : 1.0
                                
                                let newNormalized = max(0, min(1, gesture.location.x / width))
                                let newValue = range.lowerBound + newNormalized * (range.upperBound - range.lowerBound)
                                
                                if sensitivity < 1.0 {
                                    // Fine adjustment: interpolate from drag start
                                    let delta = (newValue - valueAtDragStart) * sensitivity
                                    value = min(max(valueAtDragStart + delta, range.lowerBound), range.upperBound)
                                } else {
                                    value = newValue
                                }
                                
                                // Trigger label bounce
                                labelBounce = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    labelBounce = false
                                }
                            }
                            .onEnded { _ in
                                isDragging = false
                                onDragEnd?()
                                NotificationCenter.default.post(name: .sliderDragStateChanged, object: false)
                            }
                    )
                }
                .frame(height: thumbHoverSize)
                .overlay(alignment: .top) {
                    // Floating value tooltip
                    if isDragging {
                        Text(formattedValue)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor)
                                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                            )
                            .offset(y: -32)
                            .offset(x: normalizedValue * width - (width / 2))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.easeOut(duration: 0.15), value: isDragging)
            }
            .frame(height: thumbHoverSize)
            .onHover { hovering in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isHovering = hovering
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            // Double-click to reset with spring animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                value = defaultValue
            }
            // Bounce feedback
            labelBounce = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                labelBounce = false
            }
        }
        .onChange(of: isTextFieldFocused) { _, focused in
            if !focused && isEditing {
                applyEditedValue()
            }
        }
    }
    
    private var formattedValue: String {
        let formatted = String(format: format, value)
        if showSign && value > 0 {
            return "+\(formatted)"
        }
        return formatted
    }
    
    private func applyEditedValue() {
        if let newValue = Double(editText) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                value = min(max(newValue, range.lowerBound), range.upperBound)
            }
        }
        isEditing = false
    }
}

/// Temperature slider with color gradient
struct TemperatureSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(String(format: "%.0f", value))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(value > 0 ? .orange : (value < 0 ? .blue : .primary))
            }
            
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [.blue.opacity(0.6), .white, .orange.opacity(0.6)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 4)
                .cornerRadius(2)
                
                Slider(value: $value, in: range)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Tint slider with green-magenta gradient
struct TintSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(String(format: "%.0f", value))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(value > 0 ? .pink : (value < 0 ? .green : .primary))
            }
            
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [.green.opacity(0.6), .white, .pink.opacity(0.6)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 4)
                .cornerRadius(2)
                
                Slider(value: $value, in: range)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    VStack(spacing: 16) {
        ControlSlider(
            label: "Exposure",
            value: .constant(0.5),
            range: -5...5,
            format: "%.2f"
        )
        
        TemperatureSlider(
            label: "Temperature",
            value: .constant(20),
            range: -100...100
        )
        
        TintSlider(
            label: "Tint",
            value: .constant(-15),
            range: -100...100
        )
    }
    .padding()
    .frame(width: 280)
    .preferredColorScheme(.dark)
}
