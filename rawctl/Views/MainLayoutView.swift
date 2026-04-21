//
//  MainLayoutView.swift
//  rawctl
//
//  Main application layout with NavigationSplitView
//

import SwiftUI
import UniformTypeIdentifiers

/// Main 3-column layout for the application
struct MainLayoutView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appState = AppState()
    @StateObject private var quietUIState = QuietUIState()
    @State private var showExportDialog = false
    @State private var showQuietExportSheet = false
    @State private var showQuietNanoBananaEditor = false
    @State private var showQuietCullingMode = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var catalogService: CatalogService?
    @AppStorage("rawctl.e2e.lastCommand") private var e2eLastCommand: String = ""
    @AppStorage("latent.ui.quietDarkroom") private var quietDarkroomEnabled = true

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

    private var quietSourceTitle: String {
        if let project = appState.selectedProject {
            return project.name
        }
        if let collection = appState.activeSmartCollection {
            return collection.name
        }
        return appState.selectedFolder?.lastPathComponent ?? "Library"
    }

    private func runStartupRestoreFlow(catalog: Catalog?) async {
        let restoreMode = AppPreferences.startupRestoreMode()

        switch restoreMode {
        case .lastProject:
            let didRestoreProject: Bool
            if catalog?.lastOpenedProjectId != nil {
                didRestoreProject = await appState.restoreLastProject()
            } else {
                didRestoreProject = false
            }

            if !didRestoreProject {
                await appState.loadStartupFolder(preference: .lastOpenedFirst)
            }

        case .lastOpenedFolder:
            await appState.loadStartupFolder(preference: .lastOpenedFirst)

        case .defaultFolder:
            await appState.loadStartupFolder(preference: .defaultFirst)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < compactThreshold
            
            ZStack(alignment: .bottom) {
                if quietDarkroomEnabled {
                    QuietAppShell(
                        uiState: quietUIState,
                        sourceTitle: quietSourceTitle,
                        sidebar: {
                            SidebarView(appState: appState, quietMode: quietUIState.mode)
                        },
                        workspace: {
                            WorkspaceView(
                                appState: appState,
                                quietMode: quietUIState.mode,
                                quietUIState: quietUIState,
                                isCompact: isCompact,
                                showsLegacyToolbar: false
                            )
                        },
                        inspector: {
                            InspectorView(
                                appState: appState,
                                quietMode: quietUIState.mode,
                                isCompact: isCompact
                            )
                        },
                        overlay: {
                            quietOverlayLayer()
                        },
                        onSearch: {
                            toggleQuietOverlay(.commandPalette)
                        },
                        onAssist: {
                            toggleQuietOverlay(.assist)
                        },
                        onExport: {
                            presentQuietExport()
                        }
                    )
                } else {
                    splitView(isCompact: isCompact)
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
        .frame(minWidth: 960, minHeight: 640)
        .withNetworkErrorBanner()
        .withErrorHandling()
        .focusedSceneValue(\.rawctlAppState, appState)
        .task {
            // Let the initial SwiftUI update cycle settle before startup loaders publish.
            await Task.yield()
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

                await runStartupRestoreFlow(catalog: catalog)
            } catch {
                print("[MainLayoutView] Failed to load catalog: \(error)")
                await runStartupRestoreFlow(catalog: nil)
            }
        }
        .sheet(isPresented: $showExportDialog) {
            ExportDialog(appState: appState)
        }
        .sheet(isPresented: $showQuietCullingMode) {
            CullingView(appState: appState)
                .frame(minWidth: 1200, minHeight: 800)
        }
        .sheet(isPresented: $showQuietNanoBananaEditor) {
            if let asset = appState.selectedAsset {
                NanoBananaEditorView(appState: appState, asset: asset)
            } else {
                EmptyView()
            }
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
                        Text("sidecarWriteQueued")
                            .accessibilityIdentifier("e2e.sidecar.write.queued")
                            .accessibilityLabel("sidecarWriteQueued")
                            .accessibilityValue("\(appState.e2eSidecarWriteQueued)")
                        Text("sidecarWriteSkippedNoOp")
                            .accessibilityIdentifier("e2e.sidecar.write.skipped.noop")
                            .accessibilityLabel("sidecarWriteSkippedNoOp")
                            .accessibilityValue("\(appState.e2eSidecarWriteSkippedNoOp)")
                        Text("sidecarWriteFlushed")
                            .accessibilityIdentifier("e2e.sidecar.write.flushed")
                            .accessibilityLabel("sidecarWriteFlushed")
                            .accessibilityValue("\(appState.e2eSidecarWriteFlushed)")
                        Text("sidecarWriteWritten")
                            .accessibilityIdentifier("e2e.sidecar.write.written")
                            .accessibilityLabel("sidecarWriteWritten")
                            .accessibilityValue("\(appState.e2eSidecarWriteWritten)")
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
                        Text("localExportMatch")
                            .accessibilityIdentifier("e2e.local.export.match")
                            .accessibilityLabel("localExportMatch")
                            .accessibilityValue(appState.e2eLocalExportMatch)
                        Text("localPreviewDiff")
                            .accessibilityIdentifier("e2e.local.preview.diff")
                            .accessibilityLabel("localPreviewDiff")
                            .accessibilityValue(appState.e2eLocalPreviewDiff)
                        Text("localPreviewHash")
                            .accessibilityIdentifier("e2e.local.preview.hash")
                            .accessibilityLabel("localPreviewHash")
                            .accessibilityValue(appState.e2eLocalPreviewHash)
                        Text("localExportHash")
                            .accessibilityIdentifier("e2e.local.export.hash")
                            .accessibilityLabel("localExportHash")
                            .accessibilityValue(appState.e2eLocalExportHash)
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
                        E2EAppKitButton(title: "localSetup", identifier: "e2e.action.local.setup") {
                            e2eLastCommand = "localSetup"
                            appState.runE2ELocalAdjustmentSetup()
                        }
                        .fixedSize()
                        E2EAppKitButton(title: "localCheck", identifier: "e2e.action.local.check") {
                            e2eLastCommand = "localCheck"
                            Task { await appState.runE2ELocalExportConsistencyCheck() }
                        }
                        .fixedSize()
                        E2EAppKitButton(title: "sidecarMetricsReset", identifier: "e2e.action.sidecar.metrics.reset") {
                            e2eLastCommand = "sidecarMetricsReset"
                            Task { await appState.resetE2ESidecarWriteMetrics() }
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
        .onKeyPress("a") {
            guard quietDarkroomEnabled else { return .ignored }
            toggleQuietOverlay(.assist)
            return .handled
        }
        .onKeyPress("f") {
            guard quietDarkroomEnabled else { return .ignored }
            toggleQuietOverlay(.filter)
            return .handled
        }
        .onKeyPress("e") {
            guard quietDarkroomEnabled else { return .ignored }
            quietUIState.mode = .edit
            return .handled
        }
        .onKeyPress(.escape) {
            guard quietDarkroomEnabled else { return .ignored }
            if quietUIState.activeOverlay != .none {
                quietUIState.closeOverlay()
                showQuietExportSheet = false
                return .handled
            }
            return .ignored
        }
        .background {
            Group {
                Button("") {
                    if quietDarkroomEnabled {
                        toggleQuietOverlay(.commandPalette)
                    }
                }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)

                Button("") {
                    if quietDarkroomEnabled {
                        presentQuietExport()
                    }
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .opacity(0)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .latentOpenFolderCommand)) { _ in
            openFolderFromMenu()
        }
        .onReceive(NotificationCenter.default.publisher(for: .latentGridViewCommand)) { _ in
            if quietDarkroomEnabled {
                appState.viewMode = .grid
            } else {
                withAnimation { appState.viewMode = .grid }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .latentSingleViewCommand)) { _ in
            if quietDarkroomEnabled {
                _ = appState.switchToSingleViewIfPossible()
            } else {
                withAnimation {
                    _ = appState.switchToSingleViewIfPossible()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .latentExportCommand)) { _ in
            if quietDarkroomEnabled {
                presentQuietExport()
            } else if appState.selectedAssetId != nil {
                showExportDialog = true
            } else {
                appState.showHUD("No photo selected")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .latentResetAdjustmentsCommand)) { _ in
            resetAdjustments()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            // Best-effort final flush on termination.
            // ScenePhase (.inactive/.background) is still the primary lifecycle hook.
            Task {
                await appState.flushPendingRecipeSaveAndWait()
            }
            // Auto-save current project state on app termination
            saveProjectStateSync()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                Task {
                    await AccountService.shared.refreshEntitlementsIfNeeded(reason: "scene_active")
                }
            case .inactive, .background:
                Task {
                    await appState.flushPendingRecipeSaveAndWait()
                }
            @unknown default:
                break
            }
        }
        .onAppear {
            syncQuietModeWithWorkspace()
        }
        .onChange(of: quietDarkroomEnabled) { _, isEnabled in
            guard isEnabled else { return }
            syncQuietModeWithWorkspace()
        }
        .onChange(of: quietUIState.mode) { oldMode, newMode in
            guard quietDarkroomEnabled else { return }
            handleQuietModeChange(from: oldMode, to: newMode)
        }
        .onChange(of: appState.viewMode) { _, _ in
            guard quietDarkroomEnabled else { return }
            syncQuietModeWithWorkspace()
        }
        .onChange(of: showQuietCullingMode) { _, isPresented in
            guard quietDarkroomEnabled, !isPresented else { return }
            syncQuietModeWithWorkspace()
        }
        .onChange(of: showQuietExportSheet) { _, isPresented in
            guard quietDarkroomEnabled, !isPresented else { return }
            quietUIState.closeOverlay()
            syncQuietModeWithWorkspace()
        }
    }

    @ViewBuilder
    private func splitView(isCompact: Bool) -> some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(appState: appState)
                .navigationSplitViewColumnWidth(min: 160, ideal: 210, max: 260)
        } content: {
            WorkspaceView(
                appState: appState,
                isCompact: isCompact,
                showsLegacyToolbar: !quietDarkroomEnabled
            )
            .navigationSplitViewColumnWidth(min: 360, ideal: 620, max: .infinity)
        } detail: {
            InspectorView(appState: appState, isCompact: isCompact)
                .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 300)
        }
    }

    @ViewBuilder
    private func quietOverlayLayer() -> some View {
        switch quietUIState.activeOverlay {
        case .none:
            EmptyView()
        case .assist:
            quietOverlayCard(alignment: .topTrailing) {
                QuietAssistPopover(
                    mode: quietUIState.mode,
                    sections: quietAssistSections
                )
            }
        case .filter:
            quietOverlayCard(alignment: .topLeading) {
                QuietFilterPopover(appState: appState)
            }
        case .commandPalette:
            quietOverlayCard(alignment: .top) {
                QuietCommandPalette(
                    appState: appState,
                    onOpenFolder: openFolderFromMenu,
                    onSetMode: { mode in
                        quietUIState.mode = mode
                    },
                    onExport: presentQuietExport,
                    onClose: {
                        quietUIState.closeOverlay()
                    }
                )
            }
        case .exportSheet:
            quietOverlayCard(alignment: .center) {
                QuietExportSheet(appState: appState) {
                    showQuietExportSheet = false
                    quietUIState.closeOverlay()
                }
            }
        }
    }

    @ViewBuilder
    private func quietOverlayCard<Content: View>(
        alignment: Alignment,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            Color.black.opacity(0.22)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    showQuietExportSheet = false
                    quietUIState.closeOverlay()
                }

            content()
                .padding(.horizontal, QDSpace.xl)
                .padding(.top, QDSpace.lg)
                .padding(.bottom, QDSpace.xl)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        }
        .transition(.opacity)
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

    private func toggleQuietOverlay(_ overlay: QuietOverlay) {
        guard quietDarkroomEnabled else { return }
        quietUIState.toggleOverlay(overlay)
        if overlay != .exportSheet {
            showQuietExportSheet = false
        }
    }

    private func presentQuietExport() {
        guard quietDarkroomEnabled else { return }
        guard !appState.assets.isEmpty else {
            appState.showHUD("No photos available to export")
            return
        }
        quietUIState.mode = .export
        quietUIState.activeOverlay = .exportSheet
        showQuietExportSheet = true
    }

    private func runQuietColorGrade(mode: GeminiColorService.Mode, referenceImage: NSImage? = nil) {
        guard AppFeatures.aiColorGradingEnabled else {
            appState.showAccountSheet = true
            appState.showHUD("AI Colour Grading is a Pro feature")
            return
        }
        guard let image = appState.currentPreviewImage else {
            appState.showHUD("Open a photo in Edit mode first")
            return
        }

        quietUIState.closeOverlay()

        Task {
            do {
                let result = try await GeminiColorService.shared.analyzeAndGrade(
                    renderedImage: image,
                    mode: mode,
                    referenceImage: referenceImage
                )
                await MainActor.run {
                    appState.applyColorGrade(result, mode: mode)
                    appState.showHUD("AI look applied")
                }
            } catch {
                await MainActor.run {
                    appState.showHUD(error.localizedDescription)
                }
            }
        }
    }

    private func runQuietReferenceMatch() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a reference image"

        guard panel.runModal() == .OK,
              let url = panel.url,
              let image = NSImage(contentsOf: url) else {
            return
        }

        runQuietColorGrade(mode: .reference, referenceImage: image)
    }

    private var quietAssistSections: [QuietAssistSection] {
        switch quietUIState.mode {
        case .library, .cull:
            return [
                QuietAssistSection(
                    title: "Selection Intelligence",
                    footer: appState.selectedAsset == nil ? "Select a photo to unlock scene matching and similarity workflows." : nil,
                    actions: [
                        QuietAssistAction(
                            title: "Find Best Shots",
                            subtitle: "Score sharpness, composition, and duplicates for the current set.",
                            systemImage: "checkmark.seal",
                            isPro: true,
                            action: {
                                quietUIState.closeOverlay()
                                Task {
                                    await appState.startAICulling(scope: appState.selectionCount > 1 ? .selected : .all)
                                }
                            }
                        ),
                        QuietAssistAction(
                            title: "Detect Similar Scenes",
                            subtitle: "Use Smart Sync analysis to find visually related frames.",
                            systemImage: "rectangle.on.rectangle",
                            isPro: true,
                            isDisabled: appState.selectedAsset == nil,
                            action: {
                                quietUIState.closeOverlay()
                                Task {
                                    await appState.startSmartSync()
                                }
                            }
                        ),
                        QuietAssistAction(
                            title: "Suggest Picks",
                            subtitle: "Run AI culling on the current selection and surface likely keepers.",
                            systemImage: "sparkles",
                            isPro: true,
                            action: {
                                quietUIState.closeOverlay()
                                Task {
                                    await appState.startAICulling(scope: appState.selectionCount > 1 ? .selected : .all)
                                }
                            }
                        )
                    ]
                )
            ]

        case .edit:
            return [
                QuietAssistSection(
                    title: "Looks",
                    footer: "These actions apply directly to the current rendered preview without changing the editing pipeline.",
                    actions: [
                        QuietAssistAction(
                            title: "Suggest Look",
                            subtitle: "Analyze the current edit and apply an AI colour grade.",
                            systemImage: "wand.and.stars",
                            isPro: true,
                            isDisabled: appState.currentPreviewImage == nil,
                            action: {
                                runQuietColorGrade(mode: .auto)
                            }
                        ),
                        QuietAssistAction(
                            title: "Match Reference",
                            subtitle: "Choose a reference image and adapt tone and color to match it.",
                            systemImage: "square.on.square",
                            isPro: true,
                            isDisabled: appState.currentPreviewImage == nil,
                            action: {
                                runQuietReferenceMatch()
                            }
                        ),
                        QuietAssistAction(
                            title: "Apply to Similar",
                            subtitle: "Find similar scenes and sync this photo’s look across the set.",
                            systemImage: "square.stack.3d.up",
                            isPro: true,
                            isDisabled: appState.selectedAsset == nil,
                            action: {
                                quietUIState.closeOverlay()
                                Task {
                                    await appState.startSmartSync()
                                }
                            }
                        )
                    ]
                ),
                QuietAssistSection(
                    title: "Local AI",
                    footer: "Mask-based generation and subject isolation stay out of the inspector and launch only from Assist.",
                    actions: [
                        QuietAssistAction(
                            title: "Create Subject Mask",
                            subtitle: "Open the AI editor for mask-guided local work.",
                            systemImage: "person.crop.rectangle",
                            isPro: true,
                            isDisabled: appState.selectedAsset == nil,
                            action: {
                                quietUIState.closeOverlay()
                                if AppFeatures.aiMaskingEnabled {
                                    showQuietNanoBananaEditor = true
                                } else {
                                    appState.showAccountSheet = true
                                    appState.showHUD("AI Masking is a Pro feature")
                                }
                            }
                        )
                    ]
                )
            ]

        case .export:
            return [
                QuietAssistSection(
                    title: "Delivery Review",
                    footer: nil,
                    actions: [
                        QuietAssistAction(
                            title: "Check Missing Edits",
                            subtitle: "Review the current export set for photos without visible recipe changes.",
                            systemImage: "checklist",
                            action: {
                                quietUIState.closeOverlay()
                                let missing = appState.assets.filter {
                                    !(appState.recipes[$0.id]?.hasEdits ?? false)
                                }.count
                                appState.showHUD(missing == 0 ? "All photos have edits" : "\(missing) photos still look unedited")
                            }
                        ),
                        QuietAssistAction(
                            title: "Recommend Export Settings",
                            subtitle: "Use the quiet export sheet presets for the current delivery set.",
                            systemImage: "slider.horizontal.3",
                            action: {
                                presentQuietExport()
                            }
                        )
                    ]
                )
            ]
        }
    }

    private func updateColumnVisibility(for width: CGFloat) {
        // Keep center workspace usable on narrow windows by collapsing the detail column earlier.
        if width < collapseDetailThreshold {
            columnVisibility = .doubleColumn
        } else {
            columnVisibility = .all
        }
    }

    private func handleQuietModeChange(from previousMode: QuietMode, to newMode: QuietMode) {
        switch newMode {
        case .library:
            showQuietExportSheet = false
            quietUIState.closeOverlay()
            appState.viewMode = .grid

        case .edit:
            showQuietExportSheet = false
            quietUIState.closeOverlay()
            _ = appState.switchToSingleViewIfPossible()

        case .cull:
            guard appState.selectedAsset != nil else {
                appState.showHUD("No photo selected")
                quietUIState.mode = previousMode == .cull ? .library : previousMode
                return
            }

            showQuietExportSheet = false
            quietUIState.closeOverlay()
            appState.viewMode = .grid
            showQuietCullingMode = true

        case .export:
            presentQuietExport()
        }
    }

    private func syncQuietModeWithWorkspace() {
        guard !showQuietCullingMode, !showQuietExportSheet else { return }

        let nextMode: QuietMode = appState.viewMode == .single ? .edit : .library
        guard quietUIState.mode != nextMode else { return }
        quietUIState.mode = nextMode
    }
}

#Preview {
    MainLayoutView()
}
