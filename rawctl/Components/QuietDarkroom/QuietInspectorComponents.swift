//
//  QuietInspectorComponents.swift
//  rawctl
//
//  Reusable inspector primitives for the Quiet Darkroom redesign.
//

import SwiftUI

struct QuietInspectorSection<Content: View>: View {
    var title: String
    var expansion: Binding<Bool>?
    var footer: String?
    var resetAction: (() -> Void)?
    var content: Content

    @State private var isHovering = false

    init(
        title: String,
        expansion: Binding<Bool>? = nil,
        footer: String? = nil,
        resetAction: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.expansion = expansion
        self.footer = footer
        self.resetAction = resetAction
        self.content = content()
    }

    private var isExpanded: Bool {
        expansion?.wrappedValue ?? true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: QDSpace.md) {
            header

            if isExpanded {
                content
            }

            if let footer, isExpanded {
                Text(footer)
                    .font(QDFont.metadata)
                    .foregroundStyle(QDColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(QDSpace.lg)
        .background(QDColor.elevatedSurface, in: RoundedRectangle(cornerRadius: QDRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: QDRadius.lg, style: .continuous)
                .stroke(QDColor.divider.opacity(0.68), lineWidth: 1)
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var header: some View {
        HStack(spacing: QDSpace.sm) {
            if let expansion {
                Button {
                    withAnimation(QDMotion.fast) {
                        expansion.wrappedValue.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(QDColor.textTertiary)
                }
                .buttonStyle(.plain)
            }

            Text(title)
                .font(QDFont.bodyMedium)
                .foregroundStyle(QDColor.textPrimary)

            Spacer()

            if isHovering, let resetAction {
                Button(action: resetAction) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(QDColor.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct QuietEditSliderRow: View {
    var title: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    var defaultValue: Double
    var display: (Double) -> String
    var onReset: (() -> Void)?
    var onEditingChanged: ((Bool) -> Void)?

    @State private var isHovering = false
    @State private var isDragging = false

    private let thumbDiameter: CGFloat = 14
    private let trackHeight: CGFloat = 5

    private var normalizedValue: CGFloat {
        guard range.upperBound > range.lowerBound else { return 0 }
        let progress = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return CGFloat(min(max(progress, 0), 1))
    }

    private var normalizedDefault: CGFloat {
        guard range.upperBound > range.lowerBound else { return 0 }
        let progress = (defaultValue - range.lowerBound) / (range.upperBound - range.lowerBound)
        return CGFloat(min(max(progress, 0), 1))
    }

    var body: some View {
        HStack(spacing: QDSpace.sm) {
            Text(title)
                .font(QDFont.body)
                .foregroundStyle(QDColor.textSecondary)
                .frame(width: 80, alignment: .leading)

            sliderTrack

            Text(display(value))
                .font(QDFont.numeric)
                .foregroundStyle(QDColor.textSecondary)
                .frame(width: 44, alignment: .trailing)

            if isHovering, let onReset {
                Button(action: onReset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(QDColor.textTertiary)
                }
                .buttonStyle(.plain)
                .frame(width: 14)
            } else {
                Color.clear
                    .frame(width: 14, height: 1)
            }
        }
        .frame(height: 34)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var sliderTrack: some View {
        GeometryReader { geometry in
            let fullWidth = max(geometry.size.width, thumbDiameter)
            let usableWidth = max(fullWidth - thumbDiameter, 1)
            let thumbOffset = normalizedValue * usableWidth
            let defaultX = normalizedDefault * fullWidth
            let valueX = normalizedValue * fullWidth
            let fillStart = min(defaultX, valueX)
            let fillWidth = abs(valueX - defaultX)

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(QDColor.hoverSurface)
                    .frame(height: trackHeight)

                if defaultValue == range.lowerBound {
                    Capsule(style: .continuous)
                        .fill(QDColor.accentLine)
                        .frame(width: max(0, valueX), height: trackHeight)
                } else {
                    Capsule(style: .continuous)
                        .fill(QDColor.accentLine)
                        .frame(width: max(fillWidth, value == defaultValue ? 0 : 2), height: trackHeight)
                        .offset(x: fillStart)

                    Rectangle()
                        .fill(QDColor.divider)
                        .frame(width: 1, height: trackHeight + 6)
                        .offset(x: defaultX)
                }

                Circle()
                    .fill(QDColor.textPrimary)
                    .frame(width: thumbDiameter, height: thumbDiameter)
                    .shadow(color: .black.opacity(0.28), radius: isDragging ? 4 : 2, y: 1)
                    .overlay {
                        Circle()
                            .stroke(QDColor.panelBackground.opacity(0.7), lineWidth: 0.75)
                    }
                    .offset(x: thumbOffset)
            }
            .frame(height: max(trackHeight, thumbDiameter))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            onEditingChanged?(true)
                        }

                        let clampedX = min(max(gesture.location.x, thumbDiameter / 2), fullWidth - thumbDiameter / 2)
                        let progress = (clampedX - thumbDiameter / 2) / usableWidth
                        let rawValue = range.lowerBound + Double(progress) * (range.upperBound - range.lowerBound)
                        value = snapped(rawValue)
                    }
                    .onEnded { _ in
                        if isDragging {
                            isDragging = false
                            onEditingChanged?(false)
                        }
                    }
            )
        }
        .frame(height: 18)
    }

    private func snapped(_ rawValue: Double) -> Double {
        guard step > 0 else {
            return min(max(rawValue, range.lowerBound), range.upperBound)
        }

        let stepped = (rawValue / step).rounded() * step
        return min(max(stepped, range.lowerBound), range.upperBound)
    }
}
