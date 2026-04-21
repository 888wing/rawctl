//
//  QuietCommandPalette.swift
//  rawctl
//
//  Search-first command palette for Quiet Darkroom mode.
//

import SwiftUI

struct QuietCommandPalette: View {
    @ObservedObject var appState: AppState
    var onOpenFolder: () -> Void
    var onSetMode: (QuietMode) -> Void
    var onExport: () -> Void
    var onClose: () -> Void

    @State private var query = ""
    @FocusState private var isFocused: Bool

    private struct CommandItem: Identifiable {
        let id = UUID()
        var title: String
        var subtitle: String
        var systemImage: String
        var action: () -> Void
    }

    private var commands: [CommandItem] {
        let all: [CommandItem] = [
            CommandItem(title: "Open Folder", subtitle: "Import a new source folder", systemImage: "folder.badge.plus", action: onOpenFolder),
            CommandItem(title: "Switch to Library", subtitle: "Browse and organize photos", systemImage: "square.grid.2x2", action: { onSetMode(.library) }),
            CommandItem(title: "Switch to Cull", subtitle: "Open culling workspace", systemImage: "checklist", action: { onSetMode(.cull) }),
            CommandItem(title: "Switch to Edit", subtitle: "Open the selected photo in edit mode", systemImage: "slider.horizontal.3", action: { onSetMode(.edit) }),
            CommandItem(title: "Switch to Export", subtitle: "Open export settings", systemImage: "square.and.arrow.up", action: onExport)
        ]

        guard !query.isEmpty else { return all }
        return all.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.subtitle.localizedCaseInsensitiveContains(query)
        }
    }

    private var matchingAssets: [PhotoAsset] {
        guard !query.isEmpty else { return Array(appState.filteredAssets.prefix(8)) }
        return appState.filteredAssets.filter { asset in
            let tags = (appState.recipes[asset.id]?.tags ?? []).joined(separator: " ")
            return asset.filename.localizedCaseInsensitiveContains(query) ||
                tags.localizedCaseInsensitiveContains(query)
        }
        .prefix(8)
        .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: QDSpace.lg) {
            HStack(spacing: QDSpace.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(QDColor.textTertiary)

                TextField("Search photos or run a command", text: $query)
                    .textFieldStyle(.plain)
                    .font(QDFont.body)
                    .foregroundStyle(QDColor.textPrimary)
                    .focused($isFocused)

                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(QDColor.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, QDSpace.md)
            .frame(height: 38)
            .background(QDColor.elevatedSurface, in: RoundedRectangle(cornerRadius: QDRadius.md, style: .continuous))

            VStack(alignment: .leading, spacing: QDSpace.md) {
                paletteSection("Commands") {
                    ForEach(commands) { command in
                        QuietPaletteRow(
                            title: command.title,
                            subtitle: command.subtitle,
                            systemImage: command.systemImage
                        ) {
                            command.action()
                            onClose()
                        }
                    }
                }

                if !matchingAssets.isEmpty {
                    paletteSection("Photos") {
                        ForEach(matchingAssets) { asset in
                            QuietPaletteRow(
                                title: asset.filename,
                                subtitle: asset.url.deletingLastPathComponent().lastPathComponent,
                                systemImage: "photo"
                            ) {
                                appState.select(asset, switchToSingleView: false)
                                onClose()
                            }
                        }
                    }
                }
            }
        }
        .padding(QDSpace.lg)
        .frame(width: 560)
        .background(QDColor.panelBackground, in: RoundedRectangle(cornerRadius: QDRadius.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: QDRadius.xl, style: .continuous)
                .stroke(QDColor.divider.opacity(0.72), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.38), radius: 28, x: 0, y: 18)
        .onAppear {
            DispatchQueue.main.async {
                isFocused = true
            }
        }
    }

    @ViewBuilder
    private func paletteSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: QDSpace.xs) {
            Text(title)
                .font(QDFont.sectionLabel)
                .foregroundStyle(QDColor.textTertiary)
                .textCase(.uppercase)

            VStack(spacing: QDSpace.xs) {
                content()
            }
        }
    }
}

private struct QuietPaletteRow: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: QDSpace.md) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(QDColor.accent)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(QDFont.bodyMedium)
                        .foregroundStyle(QDColor.textPrimary)
                    Text(subtitle)
                        .font(QDFont.metadata)
                        .foregroundStyle(QDColor.textTertiary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(QDSpace.sm)
            .background(
                RoundedRectangle(cornerRadius: QDRadius.sm, style: .continuous)
                    .fill(isHovering ? QDColor.hoverSurface : QDColor.panelBackground)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
