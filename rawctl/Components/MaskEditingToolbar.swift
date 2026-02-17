//
//  MaskEditingToolbar.swift
//  rawctl
//
//  Toolbar shown at the bottom of SingleView when editing a mask.
//

import SwiftUI

/// Toolbar shown at the bottom of SingleView when editing a mask.
/// Provides Done, Show Overlay toggle, and node name display.
struct MaskEditingToolbar: View {
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(spacing: 16) {
            // Node name label
            if let nodeId = appState.editingMaskId,
               let node = appState.currentLocalNodes.first(where: { $0.id == nodeId }) {
                HStack(spacing: 6) {
                    Image(systemName: maskIconName(for: node))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                    Text(node.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                }
            }

            Spacer()

            // Show Overlay toggle
            Button {
                toggleOverlay()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: appState.showMaskOverlay ? "eye" : "eye.slash")
                        .font(.system(size: 11))
                    Text(appState.showMaskOverlay ? "Hide Overlay" : "Show Overlay")
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(appState.showMaskOverlay
                    ? Color.accentColor.opacity(0.3)
                    : Color.black.opacity(0.3))
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .foregroundColor(appState.showMaskOverlay ? .accentColor : .white)
            .help("Toggle mask overlay visibility")

            Divider()
                .frame(height: 20)

            // Done button
            Button {
                doneEditing()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11))
                    Text("Done")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.3))
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .foregroundColor(.green)
            .help("Finish editing mask (Done)")
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Internal Actions (accessible for tests)

    /// Finish editing: clears editingMaskId and hides the mask overlay.
    func doneEditing() {
        withAnimation(.easeInOut(duration: 0.2)) {
            appState.editingMaskId = nil
            appState.showMaskOverlay = false
        }
    }

    /// Toggle the mask overlay visibility.
    func toggleOverlay() {
        withAnimation(.easeInOut(duration: 0.15)) {
            appState.showMaskOverlay.toggle()
        }
    }

    // MARK: - Helpers

    private func maskIconName(for node: ColorNode) -> String {
        guard let mask = node.mask else { return "circle.dashed" }
        switch mask.type {
        case .radial:  return "circle"
        case .linear:  return "line.diagonal"
        case .luminosity: return "sun.max"
        case .color:   return "paintpalette"
        }
    }
}

// MARK: - Preview

#Preview {
    let state = AppState()
    state.showMaskOverlay = true

    return MaskEditingToolbar(appState: state)
        .frame(width: 600)
        .background(Color.gray)
        .preferredColorScheme(.dark)
}
