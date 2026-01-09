//
//  ResizePanel.swift
//  rawctl
//
//  Resize controls for setting output dimensions
//

import SwiftUI

/// Resize panel with mode selection, dimensions input, and presets
struct ResizePanel: View {
    @Binding var resize: Resize
    let originalSize: CGSize?
    var onDragStart: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Enable toggle with info text
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Enable Resize", isOn: $resize.isEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)

                if resize.isEnabled {
                    Text("Resize changes final output size. Original file is not affected. Applied when exporting.")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if resize.isEnabled {
                Divider()

                // Mode picker
                Picker("Mode", selection: $resize.mode) {
                    Text("Pixels").tag(Resize.ResizeMode.pixels)
                    Text("Percentage").tag(Resize.ResizeMode.percentage)
                    Text("Long Edge").tag(Resize.ResizeMode.longEdge)
                    Text("Short Edge").tag(Resize.ResizeMode.shortEdge)
                    Text("Preset").tag(Resize.ResizeMode.preset)
                }
                .pickerStyle(.segmented)
                .controlSize(.small)

                // Mode-specific controls
                switch resize.mode {
                case .pixels:
                    pixelControls
                case .percentage:
                    percentageControls
                case .longEdge:
                    longEdgeControls
                case .shortEdge:
                    shortEdgeControls
                case .preset:
                    presetControls
                }

                // Output dimensions preview
                if let calculated = calculateOutputSize() {
                    Divider()
                    HStack {
                        Text("Output:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(calculated.width) × \(calculated.height)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }

    // MARK: - Mode Controls

    private var pixelControls: some View {
        VStack(spacing: 8) {
            // Aspect ratio lock
            Toggle("Maintain Aspect Ratio", isOn: $resize.maintainAspectRatio)
                .toggleStyle(.switch)
                .controlSize(.small)

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Width")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField("Width", value: $resize.width, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onChange(of: resize.width) { _, newWidth in
                            if resize.maintainAspectRatio, let original = originalSize, original.height > 0 {
                                let ratio = original.width / original.height
                                resize.height = Int(Double(newWidth) / ratio)
                            }
                        }
                }

                Image(systemName: resize.maintainAspectRatio ? "link" : "link.badge.plus")
                    .foregroundColor(.secondary)
                    .font(.caption)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Height")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField("Height", value: $resize.height, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onChange(of: resize.height) { _, newHeight in
                            if resize.maintainAspectRatio, let original = originalSize, original.width > 0 {
                                let ratio = original.width / original.height
                                resize.width = Int(Double(newHeight) * ratio)
                            }
                        }
                }
            }

            // Original size reference
            if let original = originalSize {
                Text("Original: \(Int(original.width)) × \(Int(original.height))")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var percentageControls: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Scale")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(resize.percentage))%")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Slider(value: $resize.percentage, in: 10...200, step: 5)
                .onChange(of: resize.percentage) { _, _ in
                    onDragStart?()
                }

            // Quick percentage buttons
            HStack(spacing: 4) {
                ForEach([25, 50, 75, 100, 150, 200], id: \.self) { pct in
                    Button("\(pct)%") {
                        onDragStart?()
                        resize.percentage = Double(pct)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .foregroundColor(resize.percentage == Double(pct) ? .accentColor : .secondary)
                }
            }
        }
    }

    private var longEdgeControls: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Long Edge (px)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                TextField("", value: $resize.longEdge, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
            }

            // Quick presets for long edge
            HStack(spacing: 4) {
                ForEach([1080, 1920, 2560, 3840], id: \.self) { px in
                    Button("\(px)") {
                        onDragStart?()
                        resize.longEdge = px
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .foregroundColor(resize.longEdge == px ? .accentColor : .secondary)
                }
            }
        }
    }

    private var shortEdgeControls: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Short Edge (px)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                TextField("", value: $resize.shortEdge, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
            }

            // Quick presets for short edge
            HStack(spacing: 4) {
                ForEach([720, 1080, 1440, 2160], id: \.self) { px in
                    Button("\(px)") {
                        onDragStart?()
                        resize.shortEdge = px
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .foregroundColor(resize.shortEdge == px ? .accentColor : .secondary)
                }
            }
        }
    }

    private var presetControls: some View {
        VStack(spacing: 8) {
            ForEach(Resize.ResizePreset.allCases.filter { $0 != .none }, id: \.self) { preset in
                Button {
                    onDragStart?()
                    resize.preset = preset
                    if let dims = preset.dimensions {
                        resize.width = dims.width
                        resize.height = dims.height
                    }
                } label: {
                    HStack {
                        Text(preset.displayName)
                            .font(.caption)
                        Spacer()
                        if let dims = preset.dimensions {
                            Text("\(dims.width)×\(dims.height)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(resize.preset == preset ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private func calculateOutputSize() -> (width: Int, height: Int)? {
        guard resize.isEnabled else { return nil }

        switch resize.mode {
        case .pixels:
            guard resize.width > 0 || resize.height > 0 else { return nil }
            if resize.width > 0 && resize.height > 0 {
                return (resize.width, resize.height)
            }
            // Auto-calculate from aspect ratio
            if let original = originalSize {
                let ratio = original.width / original.height
                if resize.width > 0 {
                    return (resize.width, Int(Double(resize.width) / ratio))
                } else if resize.height > 0 {
                    return (Int(Double(resize.height) * ratio), resize.height)
                }
            }
            return nil

        case .percentage:
            guard let original = originalSize else { return nil }
            let scale = resize.percentage / 100.0
            return (Int(original.width * scale), Int(original.height * scale))

        case .longEdge:
            guard resize.longEdge > 0, let original = originalSize else { return nil }
            let longSide = max(original.width, original.height)
            let scale = Double(resize.longEdge) / longSide
            return (Int(original.width * scale), Int(original.height * scale))

        case .shortEdge:
            guard resize.shortEdge > 0, let original = originalSize else { return nil }
            let shortSide = min(original.width, original.height)
            let scale = Double(resize.shortEdge) / shortSide
            return (Int(original.width * scale), Int(original.height * scale))

        case .preset:
            return resize.preset.dimensions
        }
    }
}

#Preview {
    ResizePanel(
        resize: .constant(Resize()),
        originalSize: CGSize(width: 6000, height: 4000)
    )
    .frame(width: 260)
    .padding()
    .preferredColorScheme(.dark)
}
