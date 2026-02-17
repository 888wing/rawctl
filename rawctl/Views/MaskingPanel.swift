//
//  MaskingPanel.swift
//  rawctl
//
//  Local adjustments panel — manages per-photo ColorNode adjustments
//

import SwiftUI

/// Panel for managing local adjustment nodes (per-photo selective editing).
/// Displayed in the inspector sidebar when a photo is selected.
struct MaskingPanel: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            nodeList
            Divider()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 4) {
            Text("Local Adjustments")
                .font(.caption.bold())
                .foregroundColor(.primary)

            Spacer()

            Button {
                addNewNode()
            } label: {
                Image(systemName: "plus")
                    .font(.caption.bold())
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("Add local adjustment")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Node List

    private var nodeList: some View {
        Group {
            if appState.currentLocalNodes.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(appState.currentLocalNodes) { node in
                            LocalAdjustmentRowPlaceholder(node: node, appState: appState)
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            Text("No adjustments")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.vertical, 16)
            Spacer()
        }
    }

    // MARK: - Actions

    /// Adds a new ColorNode with a default centered radial mask.
    /// Internal (not private) to allow unit testing without a test wrapper.
    func addNewNode() {
        let mask = NodeMask(type: .radial(centerX: 0.5, centerY: 0.5, radius: 0.3))
        var node = ColorNode(
            name: "Local \(appState.currentLocalNodes.count + 1)",
            type: .serial
        )
        node.mask = mask
        appState.addLocalNode(node)
    }
}

// MARK: - Placeholder Row (Task 9 will replace this)

/// Temporary placeholder for LocalAdjustmentRow (implemented in Task 9).
private struct LocalAdjustmentRowPlaceholder: View {
    let node: ColorNode
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(spacing: 8) {
            // Enabled toggle
            Button {
                var updated = node
                updated.isEnabled.toggle()
                appState.updateLocalNode(updated)
            } label: {
                Image(systemName: node.isEnabled ? "eye" : "eye.slash")
                    .font(.caption)
                    .foregroundColor(node.isEnabled ? Color.primary : Color.secondary.opacity(0.4))
            }
            .buttonStyle(.plain)
            .frame(width: 20)

            // Node name
            Text(node.name)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            // Mask type indicator
            if let mask = node.mask {
                Text(mask.type.displayName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Delete button
            Button {
                appState.removeLocalNode(id: node.id)
            } label: {
                Image(systemName: "trash")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove adjustment")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            appState.editingMaskId = node.id
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let state = AppState()
    return MaskingPanel(appState: state)
        .frame(width: 260)
        .background(Color(NSColor.windowBackgroundColor))
}
#endif
