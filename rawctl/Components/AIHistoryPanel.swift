//
//  AIHistoryPanel.swift
//  rawctl
//
//  History browser for AI layer edits with undo/redo support
//

import SwiftUI

/// AI History panel for browsing and navigating edit history
struct AIHistoryPanel: View {
    @ObservedObject var appState: AppState
    @ObservedObject var layerStack: AILayerStack

    @State private var history: AILayerHistory?
    @State private var isExpanded = false

    private var assetFingerprint: String {
        appState.selectedAsset?.fingerprint ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with expand/collapse
            headerView

            if isExpanded {
                if let history = history, !history.snapshots.isEmpty {
                    historyContent(history)
                } else {
                    emptyState
                }
            }
        }
        .background(Color(white: 0.1))
        .cornerRadius(8)
        .onAppear {
            loadHistory()
        }
        .onChange(of: assetFingerprint) { _, _ in
            loadHistory()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Text("History")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)

                if let history = history, history.count > 0 {
                    Text("(\(history.count))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Undo/Redo buttons (always visible when collapsed)
                if !isExpanded {
                    undoRedoButtons
                }

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Undo/Redo Buttons

    private var undoRedoButtons: some View {
        HStack(spacing: 4) {
            Button {
                performUndo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 10))
                    .foregroundColor(history?.canUndo == true ? .primary : .secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
            .disabled(history?.canUndo != true)
            .help("Undo")

            Button {
                performRedo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 10))
                    .foregroundColor(history?.canRedo == true ? .primary : .secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
            .disabled(history?.canRedo != true)
            .help("Redo")
        }
        .padding(.trailing, 8)
    }

    // MARK: - History Content

    private func historyContent(_ history: AILayerHistory) -> some View {
        VStack(spacing: 0) {
            // Undo/Redo toolbar
            HStack(spacing: 8) {
                Button {
                    performUndo()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 10))
                        Text("Undo")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(history.canUndo ? .primary : .secondary.opacity(0.5))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!history.canUndo)

                Button {
                    performRedo()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.system(size: 10))
                        Text("Redo")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(history.canRedo ? .primary : .secondary.opacity(0.5))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!history.canRedo)

                Spacer()

                Button {
                    clearHistory()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear history")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(white: 0.08))

            Divider()
                .background(Color.white.opacity(0.1))

            // History list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(history.snapshots.enumerated().reversed()), id: \.element.id) { index, snapshot in
                        HistorySnapshotRow(
                            snapshot: snapshot,
                            isCurrentIndex: index == history.currentIndex,
                            onSelect: {
                                goToSnapshot(index: index)
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 200)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.system(size: 16))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No history")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Actions

    private func loadHistory() {
        guard !assetFingerprint.isEmpty else {
            history = nil
            return
        }
        history = AILayerHistoryManager.shared.loadHistory(for: assetFingerprint)
    }

    private func performUndo() {
        guard var h = history, h.canUndo else { return }
        if let snapshot = h.undo() {
            history = h
            AILayerHistoryManager.shared.saveHistory(h)
            restoreSnapshot(snapshot)
            appState.showHUD("Undo: \(snapshot.description)")
        }
    }

    private func performRedo() {
        guard var h = history, h.canRedo else { return }
        if let snapshot = h.redo() {
            history = h
            AILayerHistoryManager.shared.saveHistory(h)
            restoreSnapshot(snapshot)
            appState.showHUD("Redo: \(snapshot.description)")
        }
    }

    private func goToSnapshot(index: Int) {
        guard var h = history else { return }
        if let snapshot = h.goTo(index: index) {
            history = h
            AILayerHistoryManager.shared.saveHistory(h)
            restoreSnapshot(snapshot)
        }
    }

    private func restoreSnapshot(_ snapshot: AILayerHistorySnapshot) {
        switch snapshot.action {
        case .created:
            // Re-add the layer if it was created
            if !layerStack.layers.contains(where: { $0.id == snapshot.layerId }) {
                layerStack.addLayer(snapshot.layerData)
            }

        case .deleted:
            // Remove the layer if we're going back to when it was deleted
            layerStack.removeLayer(id: snapshot.layerId)

        case .visibilityChanged, .opacityChanged, .blendModeChanged:
            // Restore layer properties
            if let index = layerStack.layers.firstIndex(where: { $0.id == snapshot.layerId }) {
                layerStack.layers[index] = snapshot.layerData
            }

        case .modified, .reordered:
            // For more complex modifications, restore the layer state
            if let index = layerStack.layers.firstIndex(where: { $0.id == snapshot.layerId }) {
                layerStack.layers[index] = snapshot.layerData
            }
        }
    }

    private func clearHistory() {
        guard !assetFingerprint.isEmpty else { return }
        AILayerHistoryManager.shared.deleteHistory(for: assetFingerprint)
        history = AILayerHistory(assetFingerprint: assetFingerprint)
        appState.showHUD("History cleared")
    }
}

// MARK: - History Snapshot Row

private struct HistorySnapshotRow: View {
    let snapshot: AILayerHistorySnapshot
    let isCurrentIndex: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                // Action icon
                Image(systemName: snapshot.icon)
                    .font(.system(size: 10))
                    .foregroundColor(iconColor)
                    .frame(width: 16)

                // Description
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.description)
                        .font(.system(size: 10, weight: isCurrentIndex ? .semibold : .regular))
                        .foregroundColor(isCurrentIndex ? .primary : .secondary)
                        .lineLimit(1)

                    Text(formattedTime)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.7))
                }

                Spacer()

                // Current indicator
                if isCurrentIndex {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isCurrentIndex ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var iconColor: Color {
        switch snapshot.action {
        case .created: return .green
        case .deleted: return .red
        case .modified: return .orange
        case .visibilityChanged: return .blue
        case .opacityChanged: return .purple
        case .blendModeChanged: return .cyan
        case .reordered: return .yellow
        }
    }

    private var formattedTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: snapshot.timestamp, relativeTo: Date())
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack {
        AIHistoryPanel(
            appState: AppState(),
            layerStack: AILayerStack.sample
        )
    }
    .padding()
    .frame(width: 280)
    .preferredColorScheme(.dark)
}
#endif
