//
//  PhotoGridToolbar.swift
//  rawctl
//
//  Toolbar for photo grid with view modes and actions
//

import SwiftUI

/// View mode for photo grid
enum PhotoGridViewMode: String, CaseIterable {
    case grid = "Grid"
    case filmstrip = "Filmstrip"
    case loupe = "Loupe"

    var icon: String {
        switch self {
        case .grid: return "square.grid.3x3"
        case .filmstrip: return "film"
        case .loupe: return "photo"
        }
    }
}

/// Toolbar for photo grid operations
struct PhotoGridToolbar: View {
    @ObservedObject var appState: AppState

    @Binding var viewMode: PhotoGridViewMode
    @Binding var thumbnailSize: Double
    @Binding var showFilenames: Bool

    var onSurveyMode: () -> Void
    var onCompareMode: () -> Void
    var onBatchEdit: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // View mode picker
            Picker("View", selection: $viewMode) {
                ForEach(PhotoGridViewMode.allCases, id: \.self) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            Divider()
                .frame(height: 20)

            // Thumbnail size slider
            HStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(value: $thumbnailSize, in: 80...300, step: 20)
                    .frame(width: 100)

                Image(systemName: "photo.fill")
                    .foregroundColor(.secondary)
            }

            Toggle(isOn: $showFilenames) {
                Image(systemName: "textformat")
            }
            .toggleStyle(.button)
            .help("Show filenames")

            Spacer()

            // Quick actions
            HStack(spacing: 8) {
                Button {
                    onSurveyMode()
                } label: {
                    Label("Survey", systemImage: "rectangle.on.rectangle")
                }
                .keyboardShortcut("n", modifiers: .command)
                .help("Survey Mode (Cmd+N)")

                Button {
                    onCompareMode()
                } label: {
                    Label("Compare", systemImage: "square.split.2x1")
                }
                .keyboardShortcut("c", modifiers: [.command, .option])
                .help("Compare Mode (Cmd+Option+C)")

                if !appState.selectedAssetIds.isEmpty {
                    Button {
                        onBatchEdit()
                    } label: {
                        Label("Batch Edit", systemImage: "slider.horizontal.3")
                    }
                    .help("Edit \(appState.selectedAssetIds.count) selected photos")
                }
            }

            Divider()
                .frame(height: 20)

            // Filter summary
            HStack(spacing: 6) {
                if appState.filterRating > 0 {
                    FilterBadge(
                        icon: "star.fill",
                        text: "≥\(appState.filterRating)",
                        color: .yellow
                    ) {
                        appState.filterRating = 0
                    }
                }

                if appState.filterFlag != nil {
                    FilterBadge(
                        icon: appState.filterFlag == .pick ? "flag.fill" : "xmark.circle.fill",
                        text: appState.filterFlag == .pick ? "Picks" : "Rejects",
                        color: appState.filterFlag == .pick ? .green : .red
                    ) {
                        appState.filterFlag = nil
                    }
                }

                if appState.activeSmartCollection != nil {
                    FilterBadge(
                        icon: "gearshape.fill",
                        text: appState.activeSmartCollection!.name,
                        color: .blue
                    ) {
                        appState.applySmartCollection(nil)
                    }
                }
            }

            // Count
            Text("\(appState.filteredAssets.count) photos")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

/// Small dismissible filter badge
struct FilterBadge: View {
    let icon: String
    let text: String
    let color: Color
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(color)

            Text(text)
                .font(.system(size: 10))

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(white: 0.2))
        .cornerRadius(10)
    }
}

#Preview {
    PhotoGridToolbar(
        appState: AppState(),
        viewMode: .constant(.grid),
        thumbnailSize: .constant(150),
        showFilenames: .constant(true),
        onSurveyMode: {},
        onCompareMode: {},
        onBatchEdit: {}
    )
    .preferredColorScheme(.dark)
}
