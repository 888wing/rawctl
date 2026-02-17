//
//  MainLayoutView.swift
//  rawctl
//
//  Main application layout with NavigationSplitView
//

import SwiftUI

/// Main 3-column layout for the application
struct MainLayoutView: View {
    @StateObject private var appState = AppState()
    @State private var showExportDialog = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var catalogService: CatalogService?
    @AppStorage("rawctl.e2e.lastCommand") private var e2eLastCommand: String = ""

    // Responsive breakpoints
    private let compactThreshold: CGFloat = 1550
    private let collapseDetailThreshold: CGFloat = 1500

    // Minimal, opt-in accessibility hooks for UI tests (kept out of the visible UI).
    private var e2eStatusEnabled: Bool {
        ProcessInfo.processInfo.environment["RAWCTL_E2E_STATUS"] == "1"
    }

    private var runningUnderXCTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private var e2eOverlayEnabled: Bool {
        guard e2eStatusEnabled else { return false }
        let env = ProcessInfo.processInfo.environment
        if env["RAWCTL_E2E_PANEL"] == "1" {
            return true
        }
        return runningUnderXCTest
    }

    private var e2eSelectedFilename: String {
        guard let id = appState.selectedAssetId,
              let asset = appState.assets.first(where: { $0.id == id }) else {
            return ""
        }
        return asset.filename
    }

    private var e2ePreviewSize: String {
        guard let preview = appState.currentPreviewImage else { return "0x0" }
        return "\(Int(preview.size.width.rounded()))x\(Int(preview.size.height.rounded()))"
    }
    
    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < compactThreshold
            
            ZStack(alignment: .bottom) {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    SidebarView(appState: appState)
                        .navigationSplitViewColumnWidth(min: 160, ideal: 210, max: 260)
                } content: {
                    WorkspaceView(appState: appState, isCompact: isCompact)
                        .navigationSplitViewColumnWidth(min: 360, ideal: 620, max: .infinity)
                } detail: {
                    InspectorView(appState: appState, isCompact: isCompact)
                        .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 300)
                }
                
                // Floating selection HUD (visible in single view with multi-selection)
                SelectionHUD(appState: appState, showExportDialog: $showExportDialog)
                    .padding(.bottom, 120) // Above filmstrip
            }
            .onChange(of: geometry.size.width) { _, newWidth in
                updateColumnVisibility(for: newWidth)
            }
            .onAppear {
                updateColumnVisibility(for: geometry.size.width)
            }
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 900, minHeight: 600)
        .withNetworkErrorBanner()
        .withErrorHandling()
        .focusedSceneValue(\.rawctlAppState, appState)
        .task {
            let env = ProcessInfo.processInfo.environment

            // E2E / UI test harness (sandbox-safe): ask the app to generate fixtures inside its own container.
            if let generate = env["RAWCTL_E2E_GENERATE_FIXTURES"], !generate.isEmpty {
                let count = Int(env["RAWCTL_E2E_FIXTURE_COUNT"] ?? "") ?? 6
                do {
                    let dir = try E2EFixtureGenerator.generatePNGFolder(count: count)
                    await appState.openFolderFromPath(dir.path)
                } catch {
                    print("[MainLayoutView] Failed to generate E2E fixtures: \(error)")
                }
                return
            }

            // E2E / UI test harness: allow deterministic launch into a folder without touching user catalog.
            if let e2eFolder = env["RAWCTL_E2E_FOLDER"],
               !e2eFolder.isEmpty {
                await appState.openFolderFromPath(e2eFolder)
                return
            }

            // Initialize catalog on startup
            do {
                let service = CatalogService(catalogPath: CatalogService.defaultCatalogPath)
                self.catalogService = service  // Store for auto-save on termination

                var catalog = try await service.loadOrCreate(libraryPath: CatalogService.defaultLibraryPath)

                // Migrate catalog to v2 if needed
                if catalog.version < 2 {
                    catalog.migrateToV2()
                    try? await service.save(catalog)
                }

                // Normalize built-in Smart Collections to canonical stable IDs.
                if catalog.normalizeBuiltInSmartCollections() {
                    try? await service.save(catalog)
                }

                appState.catalog = catalog

                // Try to restore last project first (v2 feature)
                if catalog.lastOpenedProjectId != nil {
                    await appState.restoreLastProject()
                } else {
                    // Fall back to legacy folder-based startup
                    await appState.loadStartupFolder()
                }
            } catch {
                print("[MainLayoutView] Failed to load catalog: \(error)")
                // Fall back to legacy folder-based startup
                await appState.loadStartupFolder()
            }
        }
        .sheet(isPresented: $showExportDialog) {
            ExportDialog(appState: appState)
        }
        .overlay(alignment: .topLeading) {
            if e2eOverlayEnabled {
                ZStack(alignment: .topLeading) {
                    // 0x0 view that can grab a handle to the NSWindow and bring it frontmost (E2E only).
                    E2EWindowTuner()
                        .frame(width: 0, height: 0)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("assets")
                            .accessibilityIdentifier("e2e.assets.count")
                            .accessibilityLabel("assets")
                            .accessibilityValue("\(appState.assets.count)")
                        Text("view")
                            .accessibilityIdentifier("e2e.view.mode")
                            .accessibilityLabel("view")
                            .accessibilityValue(appState.viewMode.rawValue)
                        Text("selected")
                            .accessibilityIdentifier("e2e.selected.exists")
                            .accessibilityLabel("selected")
                            .accessibilityValue(appState.selectedAssetId == nil ? "0" : "1")
                        Text("selectedFilename")
                            .accessibilityIdentifier("e2e.selected.filename")
                            .accessibilityLabel("selectedFilename")
                            .accessibilityValue(e2eSelectedFilename)
                        Text("transformMode")
                            .accessibilityIdentifier("e2e.transform.mode")
                            .accessibilityLabel("transformMode")
                            .accessibilityValue(appState.transformMode ? "1" : "0")
                        Text("previewSize")
                            .accessibilityIdentifier("e2e.preview.size")
                            .accessibilityLabel("previewSize")
                            .accessibilityValue(e2ePreviewSize)
                        Text("firstSelectionMs")
                            .accessibilityIdentifier("e2e.first.selection.ms")
                            .accessibilityLabel("firstSelectionMs")
                            .accessibilityValue("\(appState.e2eFirstSelectionLatencyMs)")
                        Text("scanPhaseMs")
                            .accessibilityIdentifier("e2e.scan.phase.ms")
                            .accessibilityLabel("scanPhaseMs")
                            .accessibilityValue("\(appState.e2eScanPhaseMs)")
                        Text("sidecarLoadState")
                            .accessibilityIdentifier("e2e.sidecar.load.state")
                            .accessibilityLabel("sidecarLoadState")
                            .accessibilityValue(appState.e2eSidecarLoadState)
                        Text("sidecarLoadedCount")
                            .accessibilityIdentifier("e2e.sidecar.loaded.count")
                            .accessibilityLabel("sidecarLoadedCount")
                            .accessibilityValue("\(appState.e2eSidecarLoadedCount)")
                        Text("sidecarLoadMs")
                            .accessibilityIdentifier("e2e.sidecar.load.ms")
                            .accessibilityLabel("sidecarLoadMs")
                            .accessibilityValue("\(appState.e2eSidecarLoadMs)")
                        Text("sidecarLoadUs")
                            .accessibilityIdentifier("e2e.sidecar.load.us")
                            .accessibilityLabel("sidecarLoadUs")
                            .accessibilityValue("\(appState.e2eSidecarLoadUs)")
                        Text("thumbnailPreloadState")
                            .accessibilityIdentifier("e2e.thumbnail.preload.state")
                            .accessibilityLabel("thumbnailPreloadState")
                            .accessibilityValue(appState.e2eThumbnailPreloadState)
                        Text("thumbnailPreloadMs")
                            .accessibilityIdentifier("e2e.thumbnail.preload.ms")
                            .accessibilityLabel("thumbnailPreloadMs")
                            .accessibilityValue("\(appState.e2eThumbnailPreloadMs)")
                        Text("sliderStress")
                            .accessibilityIdentifier("e2e.slider.stress.state")
                            .accessibilityLabel("sliderStress")
                            .accessibilityValue(appState.e2eSliderStressState)
                        Text("lastCommand")
                            .accessibilityIdentifier("e2e.last.command")
                            .accessibilityLabel("lastCommand")
                            .accessibilityValue(e2eLastCommand)
                        E2EAppKitButton(title: "toSingle", identifier: "e2e.action.single") {
                            e2eLastCommand = "single"
                            if appState.selectedAssetId != nil {
                                appState.viewMode = .single
                            }
                        }
                        .fixedSize()
                        E2EAppKitButton(title: "toGrid", identifier: "e2e.action.grid") {
                            e2eLastCommand = "grid"
                            appState.viewMode = .grid
                        }
                        .fixedSize()
                        E2EAppKitButton(title: "sliderStress", identifier: "e2e.action.slider.stress") {
                            e2eLastCommand = "sliderStress"
                            Task { await appState.runE2ESliderStress() }
                        }
                        .fixedSize()
                    }
                }
                .font(.system(size: 8, design: .monospaced))
                .fixedSize(horizontal: true, vertical: true)
                // Keep this panel visibly hittable in UI test mode to avoid XCUITest "click succeeded but did nothing"
                // flakiness when interacting with nearly-invisible elements.
                .foregroundStyle(.white)
                .padding(6)
                .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.25), lineWidth: 1))
                .shadow(radius: 2)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .rawctlOpenFolderCommand)) { _ in
            openFolderFromMenu()
        }
        .onReceive(NotificationCenter.default.publisher(for: .rawctlGridViewCommand)) { _ in
            withAnimation { appState.viewMode = .grid }
        }
        .onReceive(NotificationCenter.default.publisher(for: .rawctlSingleViewCommand)) { _ in
            withAnimation {
                _ = appState.switchToSingleViewIfPossible()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .rawctlExportCommand)) { _ in
            if appState.selectedAssetId != nil {
                showExportDialog = true
            } else {
                appState.showHUD("No photo selected")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .rawctlResetAdjustmentsCommand)) { _ in
            resetAdjustments()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            // Auto-save current project state on app termination
            saveProjectStateSync()
        }
    }

    /// Synchronously save project state (for termination handler)
    private func saveProjectStateSync() {
        guard let service = catalogService,
              var catalog = appState.catalog,
              appState.selectedProject != nil else {
            return
        }

        // Save current state to project
        appState.saveCurrentStateToProject()

        // Update catalog with modified project
        if let updatedProject = appState.selectedProject {
            catalog.updateProject(updatedProject)
            catalog.lastOpenedProjectId = updatedProject.id

            // Synchronous save for termination
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601

            if let data = try? encoder.encode(catalog) {
                try? data.write(to: service.catalogPath)
                print("[MainLayoutView] Saved project state on termination")
            }
        }
    }

    private func openFolderFromMenu() {
        guard let url = FileSystemService.selectFolder() else { return }
        Task {
            await appState.openFolderFromPath(url.path)
        }
    }

    private func resetAdjustments() {
        guard let id = appState.selectedAssetId else {
            appState.showHUD("No photo selected")
            return
        }
        var recipe = appState.recipes[id] ?? EditRecipe()
        recipe.reset()
        appState.recipes[id] = recipe
        appState.saveCurrentRecipe()
        appState.showHUD("Adjustments reset")
    }

    private func updateColumnVisibility(for width: CGFloat) {
        // Keep center workspace usable on narrow windows by collapsing the detail column earlier.
        if width < collapseDetailThreshold {
            columnVisibility = .doubleColumn
        } else {
            columnVisibility = .all
        }
    }
}

#Preview {
    MainLayoutView()
}
