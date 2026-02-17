//
//  LocalAdjustmentRow.swift
//  rawctl
//
//  Row component for a single local adjustment node in the MaskingPanel.
//

import SwiftUI

/// A single row representing a local adjustment ColorNode.
/// Provides enable/disable, name display, mask type indicator,
/// edit-mask action, and delete action.
struct LocalAdjustmentRow: View {
    let node: ColorNode
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(spacing: 8) {
            // 1. Enable / disable toggle
            Button {
                toggleEnabled()
            } label: {
                Image(systemName: node.isEnabled ? "eye" : "eye.slash")
                    .font(.caption)
                    .foregroundColor(node.isEnabled ? .primary : Color.secondary.opacity(0.4))
            }
            .buttonStyle(.plain)
            .frame(width: 20)
            .help(node.isEnabled ? "Disable adjustment" : "Enable adjustment")

            // 2. Node name
            Text(node.name)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            // 3. Mask type icon + label
            if let mask = node.mask {
                HStack(spacing: 3) {
                    Image(systemName: maskIcon(for: mask.type))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(maskLabel(for: mask.type))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // 4. Edit mask button
            Button {
                startEditingMask()
            } label: {
                Image(systemName: "pencil.tip.crop.circle")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Edit mask")

            // 5. Delete button
            Button {
                deleteNode()
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
    }

    // MARK: - Internal Actions (internal, not private, so tests can call them directly)

    /// Removes this node from AppState.
    func deleteNode() {
        appState.removeLocalNode(id: node.id)
    }

    /// Sets the active editing mask and shows the mask overlay.
    func startEditingMask() {
        appState.editingMaskId = node.id
        appState.showMaskOverlay = true
    }

    /// Toggles the node's isEnabled flag and persists via AppState.
    func toggleEnabled() {
        var updated = node
        updated.isEnabled.toggle()
        appState.updateLocalNode(updated)
    }

    // MARK: - Private Helpers

    private func maskIcon(for type: NodeMask.MaskType) -> String {
        switch type {
        case .radial:      return "circle"
        case .linear:      return "line.diagonal"
        case .luminosity:  return "sun.max"
        case .color:       return "paintpalette"
        }
    }

    private func maskLabel(for type: NodeMask.MaskType) -> String {
        switch type {
        case .radial:      return "Radial"
        case .linear:      return "Linear"
        case .luminosity:  return "Lumi"
        case .color:       return "Color"
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let state = AppState()
    let asset = PhotoAsset(url: URL(fileURLWithPath: "/tmp/preview.ARW"))
    state.assets = [asset]
    state.selectedAssetId = asset.id

    var node = ColorNode(name: "Sky", type: .serial)
    node.mask = NodeMask(type: .radial(centerX: 0.5, centerY: 0.5, radius: 0.3))
    state.addLocalNode(node)

    return VStack(spacing: 0) {
        LocalAdjustmentRow(node: state.currentLocalNodes[0], appState: state)
        Divider()
    }
    .frame(width: 260)
    .background(Color(NSColor.windowBackgroundColor))
}
#endif
