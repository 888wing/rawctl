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

            Menu {
                Button {
                    addNewNode(maskType: .radial(centerX: 0.5, centerY: 0.5, radius: 0.3))
                } label: {
                    Label("Radial Mask", systemImage: "circle")
                }
                Button {
                    addNewNode(maskType: .linear(angle: 90, position: 0.5, falloff: 20))
                } label: {
                    Label("Linear Mask", systemImage: "line.diagonal")
                }
                Button {
                    addNewNode(maskType: .brush(data: Data()))
                } label: {
                    Label("Brush Mask", systemImage: "paintbrush")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.caption.bold())
                    .frame(width: 20, height: 20)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 20, height: 20)
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
                            LocalAdjustmentRow(node: node, appState: appState)
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

    /// Adds a new ColorNode with the specified mask type.
    /// Internal (not private) to allow unit testing without a test wrapper.
    func addNewNode(maskType: NodeMask.MaskType = .radial(centerX: 0.5, centerY: 0.5, radius: 0.3)) {
        var node = ColorNode(
            name: "Local \(appState.currentLocalNodes.count + 1)",
            type: .serial
        )
        node.mask = NodeMask(type: maskType)
        appState.addLocalNode(node)
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
