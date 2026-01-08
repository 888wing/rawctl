//
//  AILayersPanel.swift
//  rawctl
//
//  AI Layers panel for managing generated AI layers
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// AI Layers panel for the Inspector sidebar
struct AILayersPanel: View {
    @ObservedObject var appState: AppState
    @ObservedObject var layerStack: AILayerStack

    @State private var draggedLayer: AILayer?

    var body: some View {
        VStack(spacing: 8) {
            if layerStack.layers.isEmpty {
                emptyState
            } else {
                layerList
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.3.layers.3d")
                .font(.system(size: 24))
                .foregroundColor(.secondary)

            Text("No AI Layers")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Text("Generate layers using the AI Generation panel above")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Layer List

    private var layerList: some View {
        VStack(spacing: 6) {
            ForEach(layerStack.layers) { layer in
                AILayerRow(
                    layer: layer,
                    isSelected: layerStack.selectedLayerId == layer.id,
                    assetFingerprint: appState.selectedAsset?.fingerprint ?? "",
                    onSelect: {
                        layerStack.selectedLayerId = layer.id
                    },
                    onToggleVisibility: {
                        toggleVisibility(layer)
                    },
                    onDelete: {
                        deleteLayer(layer)
                    },
                    onDownload: {
                        downloadLayer(layer)
                    },
                    onDoubleClick: {
                        reEditLayer(layer)
                    },
                    onOpacityChange: { newOpacity in
                        setOpacity(layer: layer, opacity: newOpacity)
                    },
                    onBlendModeChange: { newBlendMode in
                        setBlendMode(layer: layer, blendMode: newBlendMode)
                    }
                )
                .draggable(layer.id.uuidString) {
                    // Drag preview
                    HStack(spacing: 4) {
                        Image(systemName: layer.type.icon)
                        Text(layer.type.displayName)
                    }
                    .padding(6)
                    .background(Color.accentColor.opacity(0.3))
                    .cornerRadius(4)
                }
                .dropDestination(for: String.self) { items, _ in
                    guard let draggedId = items.first,
                          let draggedUUID = UUID(uuidString: draggedId),
                          draggedUUID != layer.id else { return false }
                    layerStack.moveLayer(from: draggedUUID, to: layer.id)
                    return true
                }
            }

            // Total credits display and action buttons
            if !layerStack.layers.isEmpty {
                VStack(spacing: 8) {
                    HStack {
                        Spacer()
                        Text("Total: \(layerStack.totalCreditsUsed) credits")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }

                    // Action buttons
                    HStack(spacing: 8) {
                        // Flatten All button
                        Button {
                            flattenAllLayers()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "square.on.square.squareshape.controlhandles")
                                    .font(.system(size: 10))
                                Text("Flatten All")
                            }
                            .font(.system(size: 10, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                        .disabled(layerStack.layers.count < 2)
                        .help("Merge all layers into one")

                        // Export button
                        Button {
                            exportSelectedLayer()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 10))
                                Text("Export")
                            }
                            .font(.system(size: 10, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                        .disabled(layerStack.selectedLayerId == nil)
                        .help("Export selected layer")
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Actions

    private func flattenAllLayers() {
        guard let asset = appState.selectedAsset else { return }

        // Get all visible layer images and composite them
        let visibleLayers = layerStack.layers.filter { $0.isVisible }
        guard !visibleLayers.isEmpty else { return }

        Task {
            // Composite all layers
            var compositeImage: NSImage?

            for layer in visibleLayers {
                if let layerImage = AIGenerationService.shared.loadLayerImage(
                    layer: layer,
                    assetFingerprint: asset.fingerprint
                ) {
                    if compositeImage == nil {
                        compositeImage = layerImage
                    } else {
                        // Composite with blend mode and opacity
                        compositeImage = compositeImages(
                            base: compositeImage!,
                            overlay: layerImage,
                            opacity: layer.opacity,
                            blendMode: layer.blendMode
                        )
                    }
                }
            }

            guard let final = compositeImage else { return }

            // Create a new flattened layer
            let flattenedLayer = AILayer(
                id: UUID(),
                type: .transform,
                prompt: "Flattened from \(visibleLayers.count) layers",
                originalPrompt: "Flattened",
                maskData: nil,
                generatedImagePath: "flattened_\(UUID().uuidString).png",
                preserveStrength: 100,
                resolution: .standard,
                creditsUsed: 0
            )

            // Save flattened image
            let resultURL = CacheManager.shared.aiCacheDirectory(for: asset.fingerprint)
                .appendingPathComponent(flattenedLayer.generatedImagePath)

            if let tiffData = final.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try? pngData.write(to: resultURL)

                await MainActor.run {
                    // Record deletion history for old layers
                    for layer in visibleLayers {
                        AILayerHistoryManager.shared.recordLayerDeleted(
                            assetFingerprint: asset.fingerprint,
                            layer: layer
                        )
                        AIGenerationService.shared.deleteLayerCache(
                            layer: layer,
                            assetFingerprint: asset.fingerprint
                        )
                        layerStack.removeLayer(id: layer.id)
                    }

                    // Add flattened layer and record creation
                    layerStack.addLayer(flattenedLayer)
                    AILayerHistoryManager.shared.recordLayerCreated(
                        assetFingerprint: asset.fingerprint,
                        layer: flattenedLayer
                    )
                    appState.showHUD("Flattened \(visibleLayers.count) layers")
                }
            }
        }
    }

    private func exportSelectedLayer() {
        guard let asset = appState.selectedAsset,
              let selectedId = layerStack.selectedLayerId,
              let layer = layerStack.layers.first(where: { $0.id == selectedId }),
              let image = AIGenerationService.shared.loadLayerImage(
                  layer: layer,
                  assetFingerprint: asset.fingerprint
              ) else { return }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "\(asset.filename)_ai_layer.png"

        if savePanel.runModal() == .OK, let url = savePanel.url {
            if let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try? pngData.write(to: url)
                appState.showHUD("Layer exported")
            }
        }
    }

    private func compositeImages(
        base: NSImage,
        overlay: NSImage,
        opacity: CGFloat,
        blendMode: AIBlendMode
    ) -> NSImage {
        let size = base.size
        let result = NSImage(size: size)

        result.lockFocus()

        // Draw base
        base.draw(in: NSRect(origin: .zero, size: size))

        // Draw overlay with blend mode and opacity
        let cgBlendMode: CGBlendMode
        switch blendMode {
        case .normal: cgBlendMode = .normal
        case .multiply: cgBlendMode = .multiply
        case .screen: cgBlendMode = .screen
        case .overlay: cgBlendMode = .overlay
        case .softLight: cgBlendMode = .softLight
        case .hardLight: cgBlendMode = .hardLight
        }

        if let context = NSGraphicsContext.current?.cgContext {
            context.setBlendMode(cgBlendMode)
            context.setAlpha(opacity)
        }

        overlay.draw(
            in: NSRect(origin: .zero, size: size),
            from: .zero,
            operation: .sourceOver,
            fraction: opacity
        )

        result.unlockFocus()

        return result
    }

    private func deleteLayer(_ layer: AILayer) {
        guard let fingerprint = appState.selectedAsset?.fingerprint else { return }

        // Record history before deletion
        AILayerHistoryManager.shared.recordLayerDeleted(
            assetFingerprint: fingerprint,
            layer: layer
        )

        // Delete cached files
        AIGenerationService.shared.deleteLayerCache(
            layer: layer,
            assetFingerprint: fingerprint
        )
        layerStack.removeLayer(id: layer.id)
    }

    private func toggleVisibility(_ layer: AILayer) {
        guard let fingerprint = appState.selectedAsset?.fingerprint else { return }

        // Toggle visibility
        layerStack.toggleVisibility(id: layer.id)

        // Record history after change
        if let updatedLayer = layerStack.layers.first(where: { $0.id == layer.id }) {
            AILayerHistoryManager.shared.recordLayerModified(
                assetFingerprint: fingerprint,
                layer: updatedLayer,
                action: .visibilityChanged
            )
        }
    }

    private func setOpacity(layer: AILayer, opacity: Double) {
        guard let fingerprint = appState.selectedAsset?.fingerprint else { return }

        // Set opacity
        layerStack.setOpacity(id: layer.id, opacity: opacity)

        // Record history after change (debounced in practice by slider interaction)
        if let updatedLayer = layerStack.layers.first(where: { $0.id == layer.id }) {
            AILayerHistoryManager.shared.recordLayerModified(
                assetFingerprint: fingerprint,
                layer: updatedLayer,
                action: .opacityChanged
            )
        }
    }

    private func setBlendMode(layer: AILayer, blendMode: AIBlendMode) {
        guard let fingerprint = appState.selectedAsset?.fingerprint else { return }

        // Set blend mode
        layerStack.setBlendMode(id: layer.id, blendMode: blendMode)

        // Record history after change
        if let updatedLayer = layerStack.layers.first(where: { $0.id == layer.id }) {
            AILayerHistoryManager.shared.recordLayerModified(
                assetFingerprint: fingerprint,
                layer: updatedLayer,
                action: .blendModeChanged
            )
        }
    }

    private func downloadLayer(_ layer: AILayer) {
        guard let asset = appState.selectedAsset,
              let image = AIGenerationService.shared.loadLayerImage(
                  layer: layer,
                  assetFingerprint: asset.fingerprint
              ) else { return }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "\(asset.filename)_\(layer.type.displayName.lowercased()).png"

        if savePanel.runModal() == .OK, let url = savePanel.url {
            if let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try? pngData.write(to: url)
                appState.showHUD("Layer downloaded")
            }
        }
    }

    private func reEditLayer(_ layer: AILayer) {
        // Post notification to load prompt in AIGenerationPanel
        NotificationCenter.default.post(
            name: .aiLayerReEdit,
            object: nil,
            userInfo: [
                "prompt": layer.originalPrompt,
                "type": layer.type
            ]
        )
        appState.showHUD("Prompt loaded for re-editing")
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let aiLayerReEdit = Notification.Name("aiLayerReEdit")
}

// MARK: - Layer Row

private struct AILayerRow: View {
    let layer: AILayer
    let isSelected: Bool
    let assetFingerprint: String
    let onSelect: () -> Void
    let onToggleVisibility: () -> Void
    let onDelete: () -> Void
    let onDownload: () -> Void
    let onDoubleClick: () -> Void
    let onOpacityChange: (Double) -> Void
    let onBlendModeChange: (AIBlendMode) -> Void

    @State private var isExpanded = false
    @State private var thumbnailImage: NSImage?

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 8) {
                // Visibility toggle
                Button(action: onToggleVisibility) {
                    Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                        .font(.system(size: 11))
                        .foregroundColor(layer.isVisible ? .primary : .secondary)
                }
                .buttonStyle(.plain)
                .help(layer.isVisible ? "Hide layer" : "Show layer")

                // Thumbnail
                thumbnailView
                    .frame(width: 32, height: 32)
                    .cornerRadius(4)

                // Layer info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: layer.type.icon)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text(layer.type.displayName)
                            .font(.system(size: 10, weight: .medium))
                    }

                    Text(layer.summary)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Expand button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                // Download button
                Button(action: onDownload) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Download layer")

                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete layer")
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture(count: 2, perform: onDoubleClick)
            .onTapGesture(perform: onSelect)

            // Expanded details
            if isExpanded {
                expandedDetails
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private var thumbnailView: some View {
        if let image = thumbnailImage {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .overlay {
                    ProgressView()
                        .scaleEffect(0.5)
                }
        }
    }

    private func loadThumbnail() {
        guard thumbnailImage == nil, !assetFingerprint.isEmpty else { return }

        Task {
            if let image = AIGenerationService.shared.loadLayerImage(
                layer: layer,
                assetFingerprint: assetFingerprint
            ) {
                await MainActor.run {
                    thumbnailImage = image
                }
            }
        }
    }

    // MARK: - Expanded Details

    private var expandedDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Opacity slider
            HStack {
                Text("Opacity")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Slider(value: Binding(
                    get: { layer.opacity },
                    set: { onOpacityChange($0) }
                ), in: 0...1)
                .controlSize(.small)

                Text("\(Int(layer.opacity * 100))%")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .frame(width: 30, alignment: .trailing)
            }

            // Blend mode picker
            HStack {
                Text("Blend")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Spacer()

                Picker("", selection: Binding(
                    get: { layer.blendMode },
                    set: { onBlendModeChange($0) }
                )) {
                    ForEach(AIBlendMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(width: 100)
            }

            // Metadata
            HStack {
                Text(layer.metadata)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.7))

                Spacer()
            }

            // Original prompt (if different from enhanced)
            if layer.originalPrompt != layer.prompt {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Original prompt:")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)

                    Text(layer.originalPrompt)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.7))
                        .lineLimit(2)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .background(Color.black.opacity(0.1))
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack {
        AILayersPanel(
            appState: AppState(),
            layerStack: AILayerStack.sample
        )
    }
    .padding()
    .frame(width: 280)
    .preferredColorScheme(.dark)
}
#endif
