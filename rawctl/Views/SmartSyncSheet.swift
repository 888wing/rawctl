//
//  SmartSyncSheet.swift
//  rawctl
//
//  Confirmation sheet for Smart Sync.
//  Shows matched photos sorted by visual similarity.
//  User can deselect individual photos before applying.
//

import SwiftUI

/// Confirmation sheet presented after SmartSyncService finds similar scenes.
///
/// The user reviews the candidate list, optionally deselects some photos,
/// then taps "Apply" to write adapted recipes via SidecarService.
struct SmartSyncSheet: View {
    @ObservedObject var appState: AppState
    @AppStorage("latent.ui.quietDarkroom") private var quietDarkroomEnabled = true

    /// IDs the user has chosen to exclude from the sync.
    @State private var excluded: Set<UUID> = []
    @Environment(\.dismiss) private var dismiss

    private var matches: [SmartSyncMatch] { appState.smartSyncMatches }

    /// Matches currently selected for sync (not excluded).
    private var selected: [SmartSyncMatch] {
        matches.filter { !excluded.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            explanationView
            matchList
            Divider()
            footerView
        }
        .frame(minWidth: 460, minHeight: 320)
        .background(quietDarkroomEnabled ? QDColor.panelBackground : Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Helpers

    private var headerView: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.title2)
                .foregroundColor(quietDarkroomEnabled ? QDColor.accent : .accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Smart Sync")
                    .font(.headline)
                Text("\(matches.count) similar scene\(matches.count == 1 ? "" : "s") found")
                    .font(.caption)
                    .foregroundColor(quietDarkroomEnabled ? QDColor.textSecondary : .secondary)
            }
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(16)
    }

    private var explanationView: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundColor(quietDarkroomEnabled ? QDColor.textSecondary : .secondary)
                .font(.caption)
            Text("Edit settings will be adapted to each photo's exposure. Deselect any photos to exclude them.")
                .font(.caption)
                .foregroundColor(quietDarkroomEnabled ? QDColor.textSecondary : .secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(quietDarkroomEnabled ? QDColor.elevatedSurface : Color.secondary.opacity(0.08))
    }

    private var matchList: some View {
        List(matches) { match in
            smartSyncRow(for: match)
        }
        .listStyle(.plain)
    }

    private var footerView: some View {
        HStack {
            Text("\(selected.count) of \(matches.count) photo\(matches.count == 1 ? "" : "s") selected")
                .font(.caption)
                .foregroundColor(quietDarkroomEnabled ? QDColor.textSecondary : .secondary)
            Spacer()
            Button("Select All")  { excluded.removeAll() }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .disabled(excluded.isEmpty)
            Button("None")        { excluded = Set(matches.map(\.id)) }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .disabled(excluded.count == matches.count)
            Divider().frame(height: 16)
            if quietDarkroomEnabled {
                Button("Apply Smart Sync") {
                    Task { await appState.applySmartSync(selections: selected) }
                }
                .buttonStyle(.plain)
                .controlSize(.regular)
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background {
                    RoundedRectangle(cornerRadius: QDRadius.sm, style: .continuous)
                        .fill(selected.isEmpty ? QDColor.textDisabled : QDColor.accent)
                }
                .foregroundColor(QDColor.appBackground)
                .disabled(selected.isEmpty)
                .keyboardShortcut(.defaultAction)
            } else {
                Button("Apply Smart Sync") {
                    Task { await appState.applySmartSync(selections: selected) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(selected.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
    }

    private func toggleExclusion(_ id: UUID) {
        if excluded.contains(id) {
            excluded.remove(id)
        } else {
            excluded.insert(id)
        }
    }

    private func smartSyncRow(for match: SmartSyncMatch) -> some View {
        let isSelected = !excluded.contains(match.id)
        let pct = Int((1.0 - Double(match.distance) / 0.40) * 100)

        return HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? (quietDarkroomEnabled ? QDColor.accent : .accentColor) : (quietDarkroomEnabled ? QDColor.textSecondary : .secondary))
                .font(.title3)
                .onTapGesture { toggleExclusion(match.id) }

            VStack(alignment: .leading, spacing: 2) {
                Text(match.asset.filename)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(quietDarkroomEnabled ? QDColor.textPrimary : .primary)
                HStack(spacing: 8) {
                    Text("~\(max(0, pct))% match")
                        .font(.caption2)
                        .foregroundColor(quietDarkroomEnabled ? QDColor.textSecondary : .secondary)
                    exposureDeltaLabel(for: match)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture { toggleExclusion(match.id) }
        .opacity(isSelected ? 1.0 : 0.45)
        .animation(.easeInOut(duration: 0.12), value: isSelected)
    }

    @ViewBuilder
    private func exposureDeltaLabel(for match: SmartSyncMatch) -> some View {
        // Show the exposure change relative to the source recipe.
        if let sourceRecipe = appState.recipes[appState.selectedAssetId ?? UUID()] {
            let delta = match.adaptedRecipe.exposure - sourceRecipe.exposure
            if abs(delta) > 0.05 {
                let sign  = delta > 0 ? "+" : ""
                let label = "\(sign)\(String(format: "%.1f", delta)) EV"
                Text(label)
                    .font(.caption2)
                    .foregroundColor(delta > 0 ? .blue : .orange)
                    .padding(.horizontal, 4)
                    .background(
                        (delta > 0 ? Color.blue : Color.orange).opacity(0.12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
    }
}
