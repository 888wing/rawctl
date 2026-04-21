//
//  QuietModeToolbar.swift
//  rawctl
//
//  Top-level mode toolbar for the Quiet Darkroom shell.
//

import SwiftUI

struct QuietModeToolbar: View {
    @ObservedObject var uiState: QuietUIState
    var sourceTitle: String
    var onSearch: () -> Void = {}
    var onAssist: () -> Void = {}
    var onExport: () -> Void = {}

    var body: some View {
        HStack(spacing: QDSpace.lg) {
            Text(sourceTitle)
                .font(QDFont.toolbarTitle)
                .foregroundStyle(QDColor.textPrimary)
                .lineLimit(1)
                .frame(minWidth: 180, alignment: .leading)

            Spacer(minLength: QDSpace.lg)

            QuietModeSwitcher(selection: $uiState.mode)

            Spacer(minLength: QDSpace.lg)

            HStack(spacing: QDSpace.sm) {
                QuietToolbarButton(title: "Search", systemImage: "magnifyingglass", action: onSearch)
                    .accessibilityIdentifier("quiet.toolbar.search")
                QuietToolbarButton(title: "Assist", systemImage: "sparkles", action: onAssist)
                    .accessibilityIdentifier("quiet.toolbar.assist")
                QuietToolbarButton(title: "Export", systemImage: "square.and.arrow.up", isPrimary: true, action: onExport)
                    .accessibilityIdentifier("quiet.toolbar.export")
            }
        }
        .frame(height: 56)
        .padding(.horizontal, QDSpace.xl)
        .background(QDColor.appBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(QDColor.divider.opacity(0.55))
                .frame(height: 1)
        }
    }
}

private struct QuietModeSwitcher: View {
    @Binding var selection: QuietMode

    var body: some View {
        HStack(spacing: QDSpace.xs) {
            ForEach(QuietMode.allCases) { mode in
                Button {
                    withAnimation(QDMotion.standard) {
                        selection = mode
                    }
                } label: {
                    Text(mode.title)
                        .font(QDFont.toolbarItem)
                        .foregroundStyle(selection == mode ? QDColor.textPrimary : QDColor.textSecondary)
                        .padding(.horizontal, QDSpace.md)
                        .frame(height: 30)
                        .background {
                            if selection == mode {
                                RoundedRectangle(cornerRadius: QDRadius.sm, style: .continuous)
                                    .fill(QDColor.selectedSurface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: QDRadius.sm, style: .continuous)
                                            .stroke(QDColor.accentLine.opacity(0.5), lineWidth: 1)
                                    )
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("quiet.mode.\(mode.rawValue)")
            }
        }
        .padding(3)
        .background(
            QDColor.elevatedSurface.opacity(0.64),
            in: RoundedRectangle(cornerRadius: QDRadius.md, style: .continuous)
        )
    }
}

private struct QuietToolbarButton: View {
    var title: String
    var systemImage: String?
    var isPrimary: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: QDSpace.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .medium))
                }

                Text(title)
                    .font(QDFont.toolbarItem)
            }
            .foregroundStyle(isPrimary ? QDColor.appBackground : QDColor.textSecondary)
            .padding(.horizontal, QDSpace.md)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: QDRadius.sm, style: .continuous)
                    .fill(isPrimary ? QDColor.accent : QDColor.elevatedSurface)
            )
        }
        .buttonStyle(.plain)
    }
}
