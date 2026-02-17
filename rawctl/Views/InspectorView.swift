//
//  InspectorView.swift
//  rawctl
//
//  Right sidebar with editing controls
//

import SwiftUI
import UniformTypeIdentifiers

/// Right sidebar showing editing controls
struct InspectorView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var panelConfig = InspectorConfig.shared
    var isCompact: Bool = false  // Compact mode for narrow windows
    
    @State private var lightExpanded = true
    @State private var toneCurveExpanded = false
    @State private var colorExpanded = true
    @State private var compositionExpanded = true
    
    // Local recipe state that syncs with AppState
    @State private var localRecipe = EditRecipe()
    
    @State private var whiteBalanceExpanded = true
    @State private var showEXIFViewer = false
    @State private var showImportPreset = false
    @State private var showCustomizeSheet = false
    @State private var importError: String?
    @State private var copiedRecipe: EditRecipe?
    
    // Nano Banana state
    @StateObject private var nanoBananaService = NanoBananaService.shared
    @State private var showNanoBananaProgress = false
    
    // Spacing based on compact mode
    private var sectionSpacing: CGFloat { isCompact ? 12 : 16 }
    private var controlSpacing: CGFloat { isCompact ? 6 : 8 }
    
    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                // Invisible anchor so we can scroll back to global controls after exiting mask mode
                Color.clear.frame(height: 0).id("inspectorTop")
                // Customize panels header
                HStack {
                    Spacer()
                    Button {
                        showCustomizeSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                            Text("Customize")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Customize visible panels")
                }
                
                // Real Histogram using AppState's preview image
                HistogramView(image: appState.currentPreviewImage, appState: appState)
                
                Divider()
                
                // Quick Actions Bar
                QuickActionsBar(
                    localRecipe: $localRecipe,
                    copiedRecipe: $copiedRecipe,
                    appState: appState,
                    onUndo: { appState.undo() },
                    onRedo: { appState.redo() },
                    onAuto: {
                        pushHistory()
                        autoAdjust()
                    },
                    onReset: {
                        pushHistory()
                        localRecipe.reset()
                    },
                    onCopy: {
                        copiedRecipe = localRecipe
                        appState.showHUD("Settings copied")
                    },
                    onPaste: {
                        if let recipe = copiedRecipe {
                            pushHistory()
                            // Paste only edit values, not metadata
                            localRecipe.exposure = recipe.exposure
                            localRecipe.contrast = recipe.contrast
                            localRecipe.highlights = recipe.highlights
                            localRecipe.shadows = recipe.shadows
                            localRecipe.whites = recipe.whites
                            localRecipe.blacks = recipe.blacks
                            localRecipe.vibrance = recipe.vibrance
                            localRecipe.saturation = recipe.saturation
                            localRecipe.whiteBalance = recipe.whiteBalance
                            localRecipe.clarity = recipe.clarity
                            localRecipe.dehaze = recipe.dehaze
                            localRecipe.texture = recipe.texture
                            localRecipe.profileId = recipe.profileId
                            appState.showHUD("Settings applied")
                        }
                    },
                    onToggleComparison: {
                        withAnimation {
                            appState.comparisonMode = appState.comparisonMode == .sideBySide ? .none : .sideBySide
                        }
                    },
                    onNanoBanana: { resolution in
                        startNanoBanana(resolution: resolution)
                    },
                    onBuyCredits: {
                        appState.showAccountSheet = true
                    },
                    canUndo: appState.history[appState.selectedAssetId ?? UUID()]?.undoStack.isEmpty == false,
                    canRedo: appState.history[appState.selectedAssetId ?? UUID()]?.redoStack.isEmpty == false,
                    hasCopied: copiedRecipe != nil,
                    isComparing: appState.comparisonMode == .sideBySide
                )
                
                // Import Preset button
                HStack {
                    Button {
                        showImportPreset = true
                    } label: {
                        Label("Import Lightroom Preset", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Spacer()
                }
                
                Divider()
                
                // Metadata: Rating, Color, Flag, Tags + EXIF button
                if panelConfig.isVisible(.organization) {
                DisclosureGroup("Organization") {
                    MetadataBar(recipe: $localRecipe)
                    
                    // EXIF Info button
                    if appState.selectedAsset != nil {
                        Button {
                            showEXIFViewer = true
                        } label: {
                            HStack {
                                Image(systemName: "info.circle")
                                Text("View Full EXIF Info")
                            }
                            .font(.caption)
                            .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                }
                .contextMenu { panelContextMenu(.organization) }
                }
                
                Divider()
                
                // Light section
                if panelConfig.isVisible(.light) {
                DisclosureGroup("Light", isExpanded: $lightExpanded) {
                    VStack(spacing: controlSpacing) {
                        // Camera Profile (v1.2)
                        ProfilePicker(selectedProfileId: $localRecipe.profileId)
                            .padding(.bottom, 4)

                        Divider()
                            .padding(.bottom, 4)

                        ControlSlider(
                            label: "Exposure",
                            value: $localRecipe.exposure,
                            range: -5...5,
                            format: "%.2f",
                            onDragStart: { pushHistory() }
                        )
                        ControlSlider(
                            label: "Contrast",
                            value: $localRecipe.contrast,
                            range: -100...100,
                            onDragStart: { pushHistory() }
                        )
                        ControlSlider(
                            label: "Highlights",
                            value: $localRecipe.highlights,
                            range: -100...100,
                            onDragStart: { pushHistory() }
                        )
                        ControlSlider(
                            label: "Shadows",
                            value: $localRecipe.shadows,
                            range: -100...100,
                            onDragStart: { pushHistory() }
                        )
                        ControlSlider(
                            label: "Whites",
                            value: $localRecipe.whites,
                            range: -100...100,
                            onDragStart: { pushHistory() }
                        )
                        ControlSlider(
                            label: "Blacks",
                            value: $localRecipe.blacks,
                            range: -100...100,
                            onDragStart: { pushHistory() }
                        )
                    }
                    .padding(.top, 6)
                }
                .contextMenu { panelContextMenu(.light) }
                }
                
                Divider()
                
                // Tone Curve section
                if panelConfig.isVisible(.toneCurve) {
                DisclosureGroup("Tone Curve", isExpanded: $toneCurveExpanded) {
                    ToneCurveView(curve: $localRecipe.toneCurve)
                        .padding(.top, 6)
                }
                .contextMenu { panelContextMenu(.toneCurve) }
                }
                
                // RGB Curves section
                if panelConfig.isVisible(.rgbCurves) {
                DisclosureGroup("RGB Curves") {
                    RGBCurvesPanel(curves: $localRecipe.rgbCurves)
                        .padding(.top, 6)
                }
                .contextMenu { panelContextMenu(.rgbCurves) }
                }
                
                Divider()
                
                // White Balance section
                if panelConfig.isVisible(.whiteBalance) {
                DisclosureGroup("White Balance", isExpanded: $whiteBalanceExpanded) {
                    WhiteBalancePanel(
                        whiteBalance: $localRecipe.whiteBalance,
                        eyedropperMode: $appState.eyedropperMode
                    )
                    .padding(.top, 6)
                }
                .contextMenu { panelContextMenu(.whiteBalance) }
                }
                
                Divider()
                
                // Color section - Enhanced with professional grading
                if panelConfig.isVisible(.color) {
                DisclosureGroup("Color", isExpanded: $colorExpanded) {
                    VStack(spacing: controlSpacing) {
                        ControlSlider(
                            label: "Vibrance",
                            value: $localRecipe.vibrance,
                            range: -100...100,
                            onDragStart: { pushHistory() }
                        )
                        ControlSlider(
                            label: "Saturation",
                            value: $localRecipe.saturation,
                            range: -100...100,
                            onDragStart: { pushHistory() }
                        )
                        
                        Divider()
                        
                        // Professional Color Grading
                        ControlSlider(
                            label: "Clarity",
                            value: $localRecipe.clarity,
                            range: -100...100,
                            onDragStart: { pushHistory() }
                        )
                        ControlSlider(
                            label: "Dehaze",
                            value: $localRecipe.dehaze,
                            range: -100...100,
                            onDragStart: { pushHistory() }
                        )
                        ControlSlider(
                            label: "Texture",
                            value: $localRecipe.texture,
                            range: -100...100,
                            onDragStart: { pushHistory() }
                        )
                    }
                    .padding(.top, 6)
                }
                .contextMenu { panelContextMenu(.color) }
                }
                
                // HSL section - Per-color adjustment
                if panelConfig.isVisible(.hsl) {
                DisclosureGroup("HSL") {
                    HSLPanel(hsl: $localRecipe.hsl)
                        .padding(.top, 6)
                }
                .contextMenu { panelContextMenu(.hsl) }
                }
                
                Divider()
                
                // Composition section - Crop, Rotate, Flip
                if panelConfig.isVisible(.composition) {
                DisclosureGroup("Composition", isExpanded: $compositionExpanded) {
                    VStack(spacing: 12) {
                        // Crop preview thumbnail
                        CropPreviewThumbnail(
                            crop: $localRecipe.crop,
                            previewImage: appState.currentPreviewImage,
                            onTap: {
                                // Save history before entering transform mode
                                pushHistory()
                                if appState.switchToSingleViewIfPossible() {
                                    appState.transformMode = true
                                }
                            }
                        )

                        // Edit Crop button
                        Button {
                            pushHistory()
                            if appState.switchToSingleViewIfPossible() {
                                appState.transformMode = true
                            }
                        } label: {
                            Label("Edit Crop", systemImage: "crop")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityIdentifier("inspector.edit.crop")

                        Divider()

                        // Crop toggle and aspect ratio
                        HStack {
                            Toggle("Crop", isOn: $localRecipe.crop.isEnabled)
                                .toggleStyle(.switch)
                                .controlSize(.small)

                            Spacer()

                            if localRecipe.crop.isEnabled {
                                Picker("Aspect", selection: $localRecipe.crop.aspect) {
                                    ForEach(Crop.Aspect.allCases) { aspect in
                                        Text(aspect.displayName).tag(aspect)
                                    }
                                }
                                .pickerStyle(.menu)
                                .controlSize(.small)
                            }
                        }

                        // Straighten slider (-45° to +45°)
                        ControlSlider(
                            label: "Straighten",
                            value: $localRecipe.crop.straightenAngle,
                            range: -45...45,
                            format: "%.1f°",
                            onDragStart: { pushHistory() }
                        )

                        // Rotation and Flip buttons
                        HStack(spacing: 8) {
                            // 90° rotation buttons
                            HStack(spacing: 4) {
                                Button {
                                    pushHistory()
                                    localRecipe.crop.rotationDegrees = (localRecipe.crop.rotationDegrees - 90 + 360) % 360
                                } label: {
                                    Image(systemName: "rotate.left")
                                }
                                .help("Rotate 90° left")

                                Button {
                                    pushHistory()
                                    localRecipe.crop.rotationDegrees = (localRecipe.crop.rotationDegrees + 90) % 360
                                } label: {
                                    Image(systemName: "rotate.right")
                                }
                                .help("Rotate 90° right")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Spacer()

                            // Flip buttons
                            HStack(spacing: 4) {
                                Button {
                                    pushHistory()
                                    localRecipe.crop.flipHorizontal.toggle()
                                } label: {
                                    Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                                }
                                .help("Flip horizontal")
                                .background(localRecipe.crop.flipHorizontal ? Color.accentColor.opacity(0.3) : Color.clear)
                                .cornerRadius(4)

                                Button {
                                    pushHistory()
                                    localRecipe.crop.flipVertical.toggle()
                                } label: {
                                    Image(systemName: "arrow.up.and.down.righttriangle.up.righttriangle.down")
                                }
                                .help("Flip vertical")
                                .background(localRecipe.crop.flipVertical ? Color.accentColor.opacity(0.3) : Color.clear)
                                .cornerRadius(4)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.top, 6)
                }
                .contextMenu { panelContextMenu(.composition) }
                }

                // Resize section
                if panelConfig.isVisible(.resize) {
                DisclosureGroup("Resize") {
                    ResizePanel(
                        resize: $localRecipe.resize,
                        originalSize: appState.selectedAsset?.imageSize,
                        onDragStart: { pushHistory() }
                    )
                    .padding(.top, 6)
                }
                .contextMenu { panelContextMenu(.resize) }
                }

                // Effects section (P0)
                if panelConfig.isVisible(.effects) {
                DisclosureGroup("Effects") {
                    VStack(spacing: controlSpacing) {
                        // Vignette
                        ControlSlider(
                            label: "Vignette",
                            value: $localRecipe.vignette.amount,
                            range: -100...100,
                            onDragStart: { pushHistory() }
                        )
                        
                        ControlSlider(
                            label: "V. Midpoint",
                            value: $localRecipe.vignette.midpoint,
                            range: 0...100,
                            onDragStart: { pushHistory() }
                        )
                        
                        ControlSlider(
                            label: "V. Feather",
                            value: $localRecipe.vignette.feather,
                            range: 0...100,
                            onDragStart: { pushHistory() }
                        )
                        
                        Divider()
                        
                        // Sharpness
                        ControlSlider(
                            label: "Sharpen",
                            value: $localRecipe.sharpness,
                            range: 0...100,
                            onDragStart: { pushHistory() }
                        )
                        
                        // Noise Reduction
                        ControlSlider(
                            label: "Noise",
                            value: $localRecipe.noiseReduction,
                            range: 0...100,
                            onDragStart: { pushHistory() }
                        )
                    }
                    .padding(.top, 6)
                }
                .contextMenu { panelContextMenu(.effects) }
                }
                
                // Split Toning section
                if panelConfig.isVisible(.splitToning) {
                DisclosureGroup("Split Toning") {
                    VStack(spacing: controlSpacing) {
                        // Highlights
                        Text("Highlights")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ControlSlider(
                            label: "Hue",
                            value: $localRecipe.splitToning.highlightHue,
                            range: 0...360,
                            onDragStart: { pushHistory() }
                        )
                        
                        ControlSlider(
                            label: "Saturation",
                            value: $localRecipe.splitToning.highlightSaturation,
                            range: 0...100,
                            onDragStart: { pushHistory() }
                        )
                        
                        Divider()
                        
                        // Shadows
                        Text("Shadows")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ControlSlider(
                            label: "Hue",
                            value: $localRecipe.splitToning.shadowHue,
                            range: 0...360,
                            onDragStart: { pushHistory() }
                        )
                        
                        ControlSlider(
                            label: "Saturation",
                            value: $localRecipe.splitToning.shadowSaturation,
                            range: 0...100,
                            onDragStart: { pushHistory() }
                        )
                        
                        Divider()
                        
                        // Balance
                        ControlSlider(
                            label: "Balance",
                            value: $localRecipe.splitToning.balance,
                            range: -100...100,
                            onDragStart: { pushHistory() }
                        )
                    }
                    .padding(.top, 6)
                }
                .contextMenu { panelContextMenu(.splitToning) }
                }
                
                // Grain section
                if panelConfig.isVisible(.grain) {
                DisclosureGroup("Grain") {
                    VStack(spacing: controlSpacing) {
                        ControlSlider(
                            label: "Amount",
                            value: $localRecipe.grain.amount,
                            range: 0...100,
                            onDragStart: { pushHistory() }
                        )
                        ControlSlider(
                            label: "Size",
                            value: $localRecipe.grain.size,
                            range: 0...100,
                            onDragStart: { pushHistory() }
                        )
                        ControlSlider(
                            label: "Roughness",
                            value: $localRecipe.grain.roughness,
                            range: 0...100,
                            onDragStart: { pushHistory() }
                        )
                    }
                    .padding(.top, 6)
                }
                .contextMenu { panelContextMenu(.grain) }
                }
                
                Divider()
                
                // Transform / Perspective section
                if panelConfig.isVisible(.transform) {
                DisclosureGroup("Transform") {
                    VStack(spacing: controlSpacing) {
                        ControlSlider(
                            label: "Vertical",
                            value: $localRecipe.perspective.vertical,
                            range: -100...100,
                            onDragStart: { pushHistory() }
                        )
                        ControlSlider(
                            label: "Horizontal",
                            value: $localRecipe.perspective.horizontal,
                            range: -100...100,
                            onDragStart: { pushHistory() }
                        )
                        ControlSlider(
                            label: "Rotate",
                            value: $localRecipe.perspective.rotate,
                            range: -45...45,
                            format: "%.1f°",
                            onDragStart: { pushHistory() }
                        )
                        ControlSlider(
                            label: "Scale",
                            value: $localRecipe.perspective.scale,
                            range: 50...150,
                            format: "%.0f%%",
                            onDragStart: { pushHistory() }
                        )
                    }
                    .padding(.top, 6)
                }
                .contextMenu { panelContextMenu(.transform) }
                }
                
                // Lens Corrections section
                if panelConfig.isVisible(.lensCorrections) {
                DisclosureGroup("Lens Corrections") {
                    VStack(spacing: controlSpacing) {
                        ControlSlider(
                            label: "Remove CA",
                            value: $localRecipe.chromaticAberration.amount,
                            range: 0...100,
                            onDragStart: { pushHistory() }
                        )
                    }
                    .padding(.top, 6)
                }
                .contextMenu { panelContextMenu(.lensCorrections) }
                }
                
                Divider()
                
                // Camera Calibration section
                if panelConfig.isVisible(.calibration) {
                DisclosureGroup("Calibration") {
                    VStack(spacing: controlSpacing) {
                        ControlSlider(
                            label: "Shadow Tint",
                            value: $localRecipe.calibration.shadowTint,
                            range: -100...100,
                            onDragStart: { pushHistory() }
                        )
                        
                        Divider()
                        
                        Text("Red Primary")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ControlSlider(
                            label: "Hue",
                            value: $localRecipe.calibration.redHue,
                            range: -100...100,
                            onDragStart: { pushHistory() }
                        )
                        ControlSlider(
                            label: "Saturation",
                            value: $localRecipe.calibration.redSaturation,
                            range: -100...100,
                            onDragStart: { pushHistory() }
                        )
                        
                        Text("Green Primary")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ControlSlider(
                            label: "Hue",
                            value: $localRecipe.calibration.greenHue,
                            range: -100...100,
                            onDragStart: { pushHistory() }
                        )
                        ControlSlider(
                            label: "Saturation",
                            value: $localRecipe.calibration.greenSaturation,
                            range: -100...100,
                            onDragStart: { pushHistory() }
                        )
                        
                        Text("Blue Primary")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ControlSlider(
                            label: "Hue",
                            value: $localRecipe.calibration.blueHue,
                            range: -100...100,
                            onDragStart: { pushHistory() }
                        )
                        ControlSlider(
                            label: "Saturation",
                            value: $localRecipe.calibration.blueSaturation,
                            range: -100...100,
                            onDragStart: { pushHistory() }
                        )
                    }
                    .padding(.top, 6)
                }
                .contextMenu { panelContextMenu(.calibration) }
                }
                
                Divider()

                // AI Generation section
                if panelConfig.isVisible(.aiGeneration) {
                DisclosureGroup("AI Generation") {
                    AIGenerationPanel(appState: appState)
                        .padding(.top, 6)
                }
                .contextMenu { panelContextMenu(.aiGeneration) }
                }

                // AI Layers section
                if panelConfig.isVisible(.aiLayers), let layerStack = appState.currentAILayerStack {
                DisclosureGroup("AI Layers") {
                    AILayersPanel(appState: appState, layerStack: layerStack)
                        .padding(.top, 6)
                }
                .contextMenu { panelContextMenu(.aiLayers) }

                // AI History section (nested under AI Layers visibility)
                AIHistoryPanel(appState: appState, layerStack: layerStack)
                    .padding(.top, 4)
                }

                if panelConfig.isVisible(.localAdjustments) {
                    Divider()

                    MaskingPanel(appState: appState)
                }

                // Snapshots section
                DisclosureGroup("Versions") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button {
                                let currentCount = appState.snapshots[appState.selectedAssetId ?? UUID()]?.count ?? 0
                                appState.createSnapshot(name: "Version \(currentCount + 1)")
                            } label: {
                                Label("Save New Version", systemImage: "plus.circle")
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundColor(.accentColor)
                            
                            Spacer()
                        }
                        
                        let snaps = appState.snapshots[appState.selectedAssetId ?? UUID()] ?? []
                        if snaps.isEmpty {
                            Text("No saved versions")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(snaps.reversed()) { snap in
                                HStack {
                                    Button(snap.name) {
                                        appState.applySnapshot(snap)
                                        localRecipe = appState.recipes[appState.selectedAssetId ?? UUID()] ?? EditRecipe()
                                    }
                                    .buttonStyle(.plain)
                                    .font(.caption)
                                    .padding(4)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(4)
                                    
                                    Spacer()
                                    
                                    Button {
                                        appState.deleteSnapshot(snap)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.top, 6)
                }
                
                Spacer(minLength: 20)
                
                // Reset button
                if localRecipe.hasEdits {
                    Button(role: .destructive) {
                        withAnimation {
                            localRecipe.reset()
                        }
                    } label: {
                        Label("Reset All", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding()
        }
        .frame(minWidth: isCompact ? 260 : 280, maxWidth: isCompact ? 300 : 340)
        .background(.ultraThinMaterial)
        .disabled(appState.selectedAsset == nil)
        .opacity(appState.selectedAsset == nil ? 0.5 : 1.0)
        // Sync local recipe with AppState
        .onChange(of: appState.selectedAssetId) { _, newId in
            if let id = newId {
                localRecipe = appState.recipes[id] ?? EditRecipe()
            }
        }
        .onChange(of: localRecipe) { oldRecipe, newRecipe in
            if let id = appState.selectedAssetId {
                // Skip if the recipe hasn't actually changed (prevents feedback loops)
                if appState.recipes[id] == newRecipe {
                    return
                }

                // Debug: Track profile changes
                if oldRecipe.profileId != newRecipe.profileId {
                    print("[Inspector] Profile changed: \(oldRecipe.profileId) → \(newRecipe.profileId)")
                }
                appState.recipes[id] = newRecipe

                // Debounce save - only save after user stops adjusting
                saveTask?.cancel()
                saveTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        appState.saveCurrentRecipe()
                    }
                }
            }
        }
        .onAppear {
            if let id = appState.selectedAssetId {
                localRecipe = appState.recipes[id] ?? EditRecipe()
            }
        }
        .sheet(isPresented: $showEXIFViewer) {
            if let asset = appState.selectedAsset {
                EXIFViewerWindow(appState: appState, asset: asset)
            }
        }
        .fileImporter(
            isPresented: $showImportPreset,
            allowedContentTypes: [.xml, .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importPreset(from: url)
                }
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
        .alert("Import Error", isPresented: .constant(importError != nil)) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "Unknown error")
        }
        .sheet(isPresented: $showCustomizeSheet) {
            InspectorCustomizeSheet()
        }
        .sheet(isPresented: $appState.showAccountSheet) {
            AccountSheet()
        }
        .overlay {
            if showNanoBananaProgress {
                NanoBananaProgressView(
                    service: nanoBananaService,
                    onCancel: {
                        nanoBananaService.cancel()
                        showNanoBananaProgress = false
                    },
                    onDismiss: {
                        showNanoBananaProgress = false
                        nanoBananaService.state = .idle
                    }
                )
            }
        }
        // When the user exits mask editing mode, scroll back to the global
        // color grading controls (Light, Color, etc.) at the top of the inspector.
        .onChange(of: appState.editingMaskId) { _, newValue in
            if newValue == nil {
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo("inspectorTop", anchor: .top)
                }
            }
        }
    } // end ScrollViewReader
    }
    
    @State private var saveTask: Task<Void, Never>?
    
    /// Context menu for hiding panels
    @ViewBuilder
    private func panelContextMenu(_ panel: InspectorPanel) -> some View {
        Button(role: .destructive) {
            withAnimation {
                panelConfig.setVisible(panel, visible: false)
            }
        } label: {
            Label("Hide \(panel.rawValue)", systemImage: "eye.slash")
        }
        
        Divider()
        
        Button {
            showCustomizeSheet = true
        } label: {
            Label("Customize Panels...", systemImage: "slider.horizontal.3")
        }
    }
    
    /// Import Lightroom XMP preset
    private func importPreset(from url: URL) {
        do {
            // Need to start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                importError = "Cannot access file"
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            pushHistory()
            let importedRecipe = try LightroomPresetParser.parse(from: url)
            
            // Merge imported values with current recipe (preserve metadata)
            localRecipe.exposure = importedRecipe.exposure
            localRecipe.contrast = importedRecipe.contrast
            localRecipe.highlights = importedRecipe.highlights
            localRecipe.shadows = importedRecipe.shadows
            localRecipe.whites = importedRecipe.whites
            localRecipe.blacks = importedRecipe.blacks
            localRecipe.vibrance = importedRecipe.vibrance
            localRecipe.saturation = importedRecipe.saturation
            localRecipe.whiteBalance = importedRecipe.whiteBalance
            localRecipe.clarity = importedRecipe.clarity
            localRecipe.dehaze = importedRecipe.dehaze
            localRecipe.texture = importedRecipe.texture
            localRecipe.sharpness = importedRecipe.sharpness
            localRecipe.noiseReduction = importedRecipe.noiseReduction
            localRecipe.grain = importedRecipe.grain
            localRecipe.vignette = importedRecipe.vignette
            localRecipe.splitToning = importedRecipe.splitToning
            localRecipe.hsl = importedRecipe.hsl
            localRecipe.calibration = importedRecipe.calibration
            localRecipe.perspective = importedRecipe.perspective
            localRecipe.chromaticAberration = importedRecipe.chromaticAberration
            
            print("[InspectorView] Successfully imported preset: \(url.lastPathComponent)")
        } catch {
            importError = error.localizedDescription
        }
    }
    
    /// Apply auto adjustments for quick enhancement
    private func autoAdjust() {
        withAnimation(.easeInOut(duration: 0.2)) {
            // Sensible auto adjustments
            localRecipe.exposure = 0.3      // Slight brightness boost
            localRecipe.contrast = 10       // Add punch
            localRecipe.highlights = -20    // Recover highlights
            localRecipe.shadows = 25        // Open shadows
            localRecipe.saturation = 8      // Slight saturation boost
            localRecipe.vibrance = 15       // Vibrance for natural look
        }
    }
    
    private func pushHistory() {
        appState.pushHistory(localRecipe)
    }
    
    // MARK: - Nano Banana
    
    /// Start Nano Banana AI processing
    private func startNanoBanana(resolution: NanoBananaResolution) {
        guard let asset = appState.selectedAsset else {
            appState.showHUD("No photo selected")
            return
        }
        
        showNanoBananaProgress = true
        
        Task {
            do {
                let resultURL = try await nanoBananaService.processImage(
                    asset: asset,
                    resolution: resolution
                )
                
                await MainActor.run {
                    appState.showHUD("Enhanced image saved")
                    print("[InspectorView] Nano Banana complete: \(resultURL.path)")
                    
                    // Optionally refresh folder to show new file
                    Task {
                        await appState.refreshCurrentFolder()
                    }
                }
            } catch {
                await MainActor.run {
                    if case NanoBananaError.cancelled = error {
                        // User cancelled, already handled
                    } else {
                        print("[InspectorView] Nano Banana error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

#Preview {
    InspectorView(appState: AppState())
        .frame(width: 300)
        .preferredColorScheme(.dark)
}
