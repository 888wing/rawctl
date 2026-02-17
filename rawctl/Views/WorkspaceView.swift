//
//  WorkspaceView.swift
//  rawctl
//
//  Main workspace with Grid and Single view modes
//

import SwiftUI

/// Main workspace area showing Grid or Single view
struct WorkspaceView: View {
    @ObservedObject var appState: AppState
    var isCompact: Bool = false
    @State private var showExportDialog = false
    @State private var showImportDialog = false
    @State private var showKeyboardShortcuts = false
    @State private var showCullingMode = false
    @State private var copiedRecipe: EditRecipe?
    
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
            
            // View content with minimal transition for snappy response
            Group {
                if appState.assets.isEmpty {
                    emptyState
                } else if appState.viewMode == .grid || appState.selectedAsset == nil {
                    GridView(appState: appState)
                        .transition(.opacity)
                } else {
                    SingleView(appState: appState)
                        .transition(.opacity)
                }
            }
            // Faster transition: 100ms instead of 200ms, no scale animation
            .animation(.easeOut(duration: 0.1), value: appState.viewMode)
        }
        // Lightroom-style keyboard shortcuts
        .onKeyPress("g") {
            withAnimation { appState.viewMode = .grid }
            return .handled
        }
        .onKeyPress("d") {
            withAnimation {
                _ = appState.switchToSingleViewIfPossible()
            }
            return .handled
        }
        .onKeyPress("r") {
            // Toggle crop mode (if implemented)
            if appState.viewMode == .single {
                if let id = appState.selectedAssetId {
                    var recipe = appState.recipes[id] ?? EditRecipe()
                    recipe.crop.isEnabled.toggle()
                    appState.recipes[id] = recipe
                }
            }
            return .handled
        }
        .onKeyPress("?") {
            showKeyboardShortcuts = true
            return .handled
        }
        .onKeyPress("c") {
            if appState.selectedAsset != nil {
                showCullingMode = true
            }
            return .handled
        }
        .onKeyPress(.space) {
            withAnimation {
                if appState.viewMode == .grid {
                    _ = appState.switchToSingleViewIfPossible()
                } else {
                    appState.viewMode = .grid
                }
            }
            return .handled
        }
        // Rating shortcuts: 0-5
        .onKeyPress("0") { applyRatingToSelection(0); return .handled }
        .onKeyPress("1") { applyRatingToSelection(1); return .handled }
        .onKeyPress("2") { applyRatingToSelection(2); return .handled }
        .onKeyPress("3") { applyRatingToSelection(3); return .handled }
        .onKeyPress("4") { applyRatingToSelection(4); return .handled }
        .onKeyPress("5") { applyRatingToSelection(5); return .handled }
        // Flag shortcuts: P=Pick, X=Reject, U=Unflag
        .onKeyPress("p") { applyFlagToSelection(.pick); return .handled }
        .onKeyPress("x") { applyFlagToSelection(.reject); return .handled }
        .onKeyPress("u") { applyFlagToSelection(.none); return .handled }
        // Color label shortcuts: 6=Red, 7=Yellow, 8=Green, 9=Blue
        .onKeyPress("6") { applyColorLabelToSelection(.red); return .handled }
        .onKeyPress("7") { applyColorLabelToSelection(.yellow); return .handled }
        .onKeyPress("8") { applyColorLabelToSelection(.green); return .handled }
        .onKeyPress("9") { applyColorLabelToSelection(.blue); return .handled }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                // View mode picker
                Picker("Mode", selection: $appState.viewMode) {
                    Label("Grid View", systemImage: "square.grid.2x2")
                        .labelStyle(.iconOnly)
                        .tag(AppState.ViewMode.grid)
                    Label("Single View", systemImage: "rectangle")
                        .labelStyle(.iconOnly)
                        .tag(AppState.ViewMode.single)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("toolbar.viewMode")
                .accessibilityLabel("View Mode")
                .help("Toggle Grid / Single View")
                
                Divider()
                
                if appState.viewMode == .single {
                    // Comparison Toggle
                    Button {
                        withAnimation {
                            appState.comparisonMode = appState.comparisonMode == .sideBySide ? .none : .sideBySide
                        }
                    } label: {
                        Image(systemName: appState.comparisonMode == .sideBySide ? "rectangle.split.2x1.fill" : "rectangle.split.2x1")
                    }
                    .help("Before/After Comparison (\\)")
                    
                    // Zoom Toggle
                    Button {
                        appState.isZoomed.toggle()
                    } label: {
                        Image(systemName: appState.isZoomed ? "plus.magnifyingglass" : "magnifyingglass")
                    }
                    .help("Toggle Zoom 100% (Z)")
                    
                    Divider()
                }
                
                // Culling Mode button
                Button {
                    showCullingMode = true
                } label: {
                    Image(systemName: "eye.square")
                }
                .help("Culling Mode (C)")
                .disabled(appState.assets.isEmpty)
                
                // Import button
                Button {
                    showImportDialog = true
                } label: {
                    if isCompact {
                        Image(systemName: "square.and.arrow.down")
                    } else {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                }
                .help("Import from Memory Card")
                
                if isCompact {
                    Menu {
                        Button("Copy Settings", action: copySettings)
                            .disabled(appState.selectedAsset == nil)
                        Button("Paste Settings", action: pasteSettings)
                            .disabled(appState.selectedAsset == nil || copiedRecipe == nil)
                        Divider()
                        Button("Quick Export", action: quickExport)
                            .disabled(appState.selectedAsset == nil || !QuickExportManager.shared.isQuickExportAvailable)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .help("More Actions")
                } else {
                    // Copy/Paste settings
                    Button {
                        copySettings()
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .help("Copy Edit Settings (⌘C)")
                    .keyboardShortcut("c", modifiers: .command)
                    .disabled(appState.selectedAsset == nil)
                    
                    Button {
                        pasteSettings()
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .help("Paste Edit Settings (⌘V)")
                    .keyboardShortcut("v", modifiers: .command)
                    .disabled(appState.selectedAsset == nil || copiedRecipe == nil)
                    
                    // Quick Export button
                    Button {
                        quickExport()
                    } label: {
                        Image(systemName: "bolt.circle")
                    }
                    .help(QuickExportManager.shared.isQuickExportAvailable
                          ? "Quick Export to \(QuickExportManager.shared.destinationDescription) (⌘⇧E)"
                          : "Quick Export (configure with Export first)")
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(appState.selectedAsset == nil || !QuickExportManager.shared.isQuickExportAvailable)
                }
                
                // Prominent Export button
                Button {
                    showExportDialog = true
                } label: {
                    if isCompact {
                        Image(systemName: "square.and.arrow.up.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up.fill")
                            Text("Export JPG")
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                }
                .buttonStyle(.plain)
                .keyboardShortcut("e", modifiers: .command)
                .disabled(appState.selectedAsset == nil)
            }
        }
        .navigationTitle(appState.selectedFolder?.lastPathComponent ?? "rawctl")
        .navigationSubtitle(appState.selectedAsset?.filename ?? "")
        .sheet(isPresented: $showExportDialog) {
            ExportDialog(appState: appState)
        }
        .sheet(isPresented: $showImportDialog) {
            ImportView(appState: appState)
        }
        .sheet(isPresented: $showKeyboardShortcuts) {
            KeyboardShortcutsView()
        }
        .sheet(isPresented: $showCullingMode) {
            CullingView(appState: appState)
                .frame(minWidth: 1200, minHeight: 800)
        }
        .toastHUD(appState: appState)
        .onChange(of: appState.viewMode) { _, newMode in
            if newMode == .single {
                _ = appState.switchToSingleViewIfPossible()
            } else if appState.transformMode {
                appState.transformMode = false
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Photos")
                .font(.title2)
                .foregroundColor(.primary)
            
            Text("Open a folder to get started")
                .font(.callout)
                .foregroundColor(.secondary)
            
            Button("Open Folder…") {
                openFolder()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func openFolder() {
        guard let url = FileSystemService.selectFolder() else { return }

        Task {
            await appState.openFolderFromPath(url.path)
        }
    }
    
    private func copySettings() {
        guard let id = appState.selectedAssetId,
              let recipe = appState.recipes[id] else { return }
        copiedRecipe = recipe
    }
    
    private func pasteSettings() {
        guard let id = appState.selectedAssetId,
              let recipe = copiedRecipe else { return }
        appState.recipes[id] = recipe
        appState.saveCurrentRecipe()
    }
    
    private func quickExport() {
        guard let settings = QuickExportManager.shared.loadSettings(),
              settings.destinationFolder != nil else {
            appState.showHUD("Configure export settings first")
            return
        }

        guard let asset = appState.selectedAsset else {
            appState.showHUD("No photo selected")
            return
        }

        // Show starting HUD
        appState.showHUD("Exporting...")

        // Create settings for current photo only
        var exportSettings = settings
        exportSettings.exportSelection = .current

        Task {
            await ExportService.shared.startExport(
                assets: [asset],
                recipes: appState.recipes,
                settings: exportSettings
            )

            await MainActor.run {
                appState.showHUD("Exported to \(settings.destinationFolder?.lastPathComponent ?? "folder")")
            }
        }
    }

    // MARK: - Keyboard Shortcut Actions

    /// Get target asset IDs (multi-selection or current selection)
    private var targetAssetIds: [UUID] {
        if !appState.selectedAssetIds.isEmpty {
            return Array(appState.selectedAssetIds)
        } else if let id = appState.selectedAssetId {
            return [id]
        }
        return []
    }

    /// Apply rating via keyboard shortcut
    private func applyRatingToSelection(_ rating: Int) {
        let ids = targetAssetIds
        guard !ids.isEmpty else { return }

        for id in ids {
            var recipe = appState.recipes[id] ?? EditRecipe()
            recipe.rating = rating
            appState.recipes[id] = recipe
            if let asset = appState.assets.first(where: { $0.id == id }) {
                Task { @MainActor in
                    await SidecarService.shared.saveRecipeOnly(recipe, for: asset.url)
                }
            }
        }
        let message = rating > 0
            ? "Rating: \(String(repeating: "★", count: rating))" + (ids.count > 1 ? " (\(ids.count) photos)" : "")
            : "Rating cleared" + (ids.count > 1 ? " (\(ids.count) photos)" : "")
        appState.showHUD(message)
    }

    /// Apply flag via keyboard shortcut
    private func applyFlagToSelection(_ flag: Flag) {
        let ids = targetAssetIds
        guard !ids.isEmpty else { return }

        for id in ids {
            var recipe = appState.recipes[id] ?? EditRecipe()
            recipe.flag = flag
            appState.recipes[id] = recipe
            if let asset = appState.assets.first(where: { $0.id == id }) {
                Task { @MainActor in
                    await SidecarService.shared.saveRecipeOnly(recipe, for: asset.url)
                }
            }
        }
        let countSuffix = ids.count > 1 ? " (\(ids.count) photos)" : ""
        let message: String
        switch flag {
        case .pick: message = "Flagged as Pick" + countSuffix
        case .reject: message = "Flagged as Reject" + countSuffix
        case .none: message = "Unflagged" + countSuffix
        }
        appState.showHUD(message)
    }

    /// Apply color label via keyboard shortcut
    private func applyColorLabelToSelection(_ label: ColorLabel) {
        let ids = targetAssetIds
        guard !ids.isEmpty else { return }

        for id in ids {
            var recipe = appState.recipes[id] ?? EditRecipe()
            recipe.colorLabel = label
            appState.recipes[id] = recipe
            if let asset = appState.assets.first(where: { $0.id == id }) {
                Task { @MainActor in
                    await SidecarService.shared.saveRecipeOnly(recipe, for: asset.url)
                }
            }
        }
        let countSuffix = ids.count > 1 ? " (\(ids.count) photos)" : ""
        let message = label != .none
            ? "Label: \(label.displayName)" + countSuffix
            : "Label cleared" + countSuffix
        appState.showHUD(message)
    }
}

#Preview {
    WorkspaceView(appState: AppState(), isCompact: false)
        .preferredColorScheme(.dark)
}
