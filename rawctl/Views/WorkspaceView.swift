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
    @State private var showExportDialog = false
    @State private var showImportDialog = false
    @State private var showKeyboardShortcuts = false
    @State private var showCullingMode = false
    @State private var copiedRecipe: EditRecipe?
    
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
            
            // View content with transition animation
            Group {
                if appState.assets.isEmpty {
                    emptyState
                } else if appState.viewMode == .grid || appState.selectedAsset == nil {
                    GridView(appState: appState)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    SingleView(appState: appState)
                        .transition(.opacity.combined(with: .scale(scale: 1.02)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: appState.viewMode)
        }
        // Lightroom-style keyboard shortcuts
        .onKeyPress("g") {
            withAnimation { appState.viewMode = .grid }
            return .handled
        }
        .onKeyPress("d") {
            if appState.selectedAsset != nil {
                withAnimation { appState.viewMode = .single }
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
                appState.viewMode = appState.viewMode == .grid ? .single : .grid
            }
            return .handled
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                // View mode picker
                Picker("Mode", selection: $appState.viewMode) {
                    Image(systemName: "square.grid.2x2")
                        .tag(AppState.ViewMode.grid)
                    Image(systemName: "rectangle")
                        .tag(AppState.ViewMode.single)
                }
                .pickerStyle(.segmented)
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
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .help("Import from Memory Card")
                
                Spacer()
                
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
                
                Spacer()
                
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
                
                // Prominent Export button
                Button {
                    showExportDialog = true
                } label: {
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
        
        appState.selectedFolder = url
        appState.isLoading = true
        appState.loadingMessage = "Scanning folder…"
        
        Task {
            do {
                let assets = try await FileSystemService.scanFolder(url)
                await MainActor.run {
                    appState.assets = assets
                    appState.isLoading = false
                }
            } catch {
                await MainActor.run {
                    appState.isLoading = false
                }
            }
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
}

#Preview {
    WorkspaceView(appState: AppState())
        .preferredColorScheme(.dark)
}

