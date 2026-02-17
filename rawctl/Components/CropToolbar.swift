//
//  CropToolbar.swift
//  rawctl
//
//  Toolbar for crop mode with aspect ratio, grid overlay, and straighten controls
//

import SwiftUI

/// Grid overlay types for composition guides
enum GridOverlay: String, CaseIterable, Identifiable {
    case none = "None"
    case thirds = "Rule of Thirds"
    case phi = "Golden Ratio"
    case diagonal = "Diagonal"
    case triangle = "Golden Triangle"
    case spiral = "Golden Spiral"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .none: return "square"
        case .thirds: return "grid"
        case .phi: return "rectangle.split.3x3"
        case .diagonal: return "line.diagonal"
        case .triangle: return "triangle"
        case .spiral: return "spiral"
        }
    }
}

/// Crop toolbar with aspect ratio, grid, straighten, and transform controls
struct CropToolbar: View {
    @Binding var crop: Crop
    @Binding var gridOverlay: GridOverlay
    let imageSize: CGSize
    let onConfirm: () -> Void
    let onCancel: () -> Void
    let onReset: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Aspect ratio picker
            AspectPicker(selection: $crop.aspect)

            Divider()
                .frame(height: 20)

            // Grid overlay picker
            GridOverlayPicker(selection: $gridOverlay)

            Divider()
                .frame(height: 20)

            // Straighten slider
            StraightenSlider(angle: $crop.straightenAngle)

            Spacer()

            // Flip buttons
            HStack(spacing: 8) {
                Button {
                    crop.flipHorizontal.toggle()
                } label: {
                    Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(crop.flipHorizontal ? .accentColor : .white)
                .help("Flip Horizontal")

                Button {
                    crop.flipVertical.toggle()
                } label: {
                    Image(systemName: "arrow.up.and.down.righttriangle.up.righttriangle.down")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(crop.flipVertical ? .accentColor : .white)
                .help("Flip Vertical")
            }

            Divider()
                .frame(height: 20)

            // Rotate 90 degree buttons
            HStack(spacing: 8) {
                Button {
                    rotate90(clockwise: false)
                } label: {
                    Image(systemName: "rotate.left")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(.white)
                .help("Rotate Left 90°")

                Button {
                    rotate90(clockwise: true)
                } label: {
                    Image(systemName: "rotate.right")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(.white)
                .help("Rotate Right 90°")
            }

            Divider()
                .frame(height: 20)

            // Action buttons
            HStack(spacing: 8) {
                Button {
                    onReset()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.7))
                .help("Reset Crop (R)")

                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(.white)
                .help("Cancel (Esc)")

                Button {
                    onConfirm()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(.green)
                .help("Confirm (Enter)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private func rotate90(clockwise: Bool) {
        let current = crop.rotationDegrees
        if clockwise {
            crop.rotationDegrees = (current + 90) % 360
        } else {
            crop.rotationDegrees = (current - 90 + 360) % 360
        }
    }
}

// MARK: - Aspect Ratio Picker

struct AspectPicker: View {
    @Binding var selection: Crop.Aspect

    var body: some View {
        Menu {
            ForEach(Crop.Aspect.allCases, id: \.self) { aspect in
                Button {
                    selection = aspect
                } label: {
                    HStack {
                        Text(aspect.displayName)
                        if selection == aspect {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "aspectratio")
                    .font(.system(size: 10))
                Text(selection.displayName)
                    .font(.system(size: 11, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.3))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .foregroundColor(.white)
    }
}

// MARK: - Grid Overlay Picker

struct GridOverlayPicker: View {
    @Binding var selection: GridOverlay

    var body: some View {
        Menu {
            ForEach(GridOverlay.allCases) { overlay in
                Button {
                    selection = overlay
                } label: {
                    HStack {
                        Image(systemName: overlay.iconName)
                        Text(overlay.rawValue)
                        if selection == overlay {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: selection.iconName)
                    .font(.system(size: 10))
                Text("Grid")
                    .font(.system(size: 11, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.3))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .foregroundColor(.white)
    }
}

// MARK: - Straighten Slider

struct StraightenSlider: View {
    @Binding var angle: Double  // -45 to +45

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "level")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.7))

            Slider(value: $angle, in: -45...45)
                .frame(width: 100)

            Text(String(format: "%.1f°", angle))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        CropToolbar(
            crop: .constant(Crop()),
            gridOverlay: .constant(.thirds),
            imageSize: CGSize(width: 4000, height: 3000),
            onConfirm: {},
            onCancel: {},
            onReset: {}
        )
    }
    .frame(width: 800)
    .background(Color.gray)
    .preferredColorScheme(.dark)
}
