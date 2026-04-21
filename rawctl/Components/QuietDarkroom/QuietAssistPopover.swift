//
//  QuietAssistPopover.swift
//  rawctl
//
//  Contextual AI workflow hub for Quiet Darkroom mode.
//

import SwiftUI

struct QuietAssistAction: Identifiable {
    let id = UUID()
    var title: String
    var subtitle: String
    var systemImage: String
    var isPro: Bool = false
    var isDisabled: Bool = false
    var action: () -> Void = {}
}

struct QuietAssistSection: Identifiable {
    let id = UUID()
    var title: String
    var footer: String?
    var actions: [QuietAssistAction]
}

struct QuietAssistPopover: View {
    var mode: QuietMode
    var sections: [QuietAssistSection]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: QDSpace.lg) {
                HStack {
                    Label("Assist", systemImage: "sparkles")
                        .font(QDFont.bodyMedium)
                        .foregroundStyle(QDColor.textPrimary)
                    Spacer()
                    Text(mode.title)
                        .font(QDFont.metadata)
                        .foregroundStyle(QDColor.textTertiary)
                }

                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: QDSpace.xs) {
                        Text(section.title)
                            .font(QDFont.sectionLabel)
                            .foregroundStyle(QDColor.textTertiary)
                            .textCase(.uppercase)

                        VStack(spacing: QDSpace.xs) {
                            ForEach(section.actions) { item in
                                QuietAssistActionRow(item: item)
                            }
                        }

                        if let footer = section.footer {
                            Text(footer)
                                .font(QDFont.metadata)
                                .foregroundStyle(QDColor.textTertiary)
                                .padding(.top, QDSpace.xs)
                        }
                    }
                }
            }
            .padding(QDSpace.lg)
        }
        .frame(width: 360, height: min(CGFloat(140 + sections.count * 120), 520))
        .background(QDColor.panelBackground, in: RoundedRectangle(cornerRadius: QDRadius.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: QDRadius.xl, style: .continuous)
                .stroke(QDColor.divider.opacity(0.74), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.34), radius: 24, x: 0, y: 16)
    }
}

private struct QuietAssistActionRow: View {
    var item: QuietAssistAction
    @State private var isHovering = false

    var body: some View {
        Button(action: item.action) {
            HStack(spacing: QDSpace.md) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(item.isDisabled ? QDColor.textDisabled : QDColor.accent)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: QDSpace.xs) {
                        Text(item.title)
                            .font(QDFont.bodyMedium)
                            .foregroundStyle(item.isDisabled ? QDColor.textDisabled : QDColor.textPrimary)

                        if item.isPro {
                            Text("Pro")
                                .font(QDFont.metadata)
                                .foregroundStyle(QDColor.textTertiary)
                                .padding(.horizontal, QDSpace.xs)
                                .frame(height: 18)
                                .background(QDColor.elevatedSurface, in: Capsule())
                        }
                    }

                    Text(item.subtitle)
                        .font(QDFont.metadata)
                        .foregroundStyle(QDColor.textTertiary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(QDSpace.sm)
            .background(
                (isHovering ? QDColor.hoverSurface : QDColor.panelBackground),
                in: RoundedRectangle(cornerRadius: QDRadius.sm, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(item.isDisabled)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
