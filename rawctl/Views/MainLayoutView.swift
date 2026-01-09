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

    // Responsive breakpoints
    private let compactThreshold: CGFloat = 1200
    
    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < compactThreshold
            
            ZStack(alignment: .bottom) {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    SidebarView(appState: appState)
                        .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
                } content: {
                    WorkspaceView(appState: appState)
                        .navigationSplitViewColumnWidth(min: 400, ideal: 600, max: .infinity)
                } detail: {
                    InspectorView(appState: appState, isCompact: isCompact)
                        .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 340)
                }
                
                // Floating selection HUD (visible in single view with multi-selection)
                SelectionHUD(appState: appState, showExportDialog: $showExportDialog)
                    .padding(.bottom, 120) // Above filmstrip
            }
            .onChange(of: geometry.size.width) { _, newWidth in
                // Auto-adjust column visibility for narrow windows
                if newWidth < 900 {
                    columnVisibility = .doubleColumn
                } else {
                    columnVisibility = .all
                }
            }
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 900, minHeight: 600)
        .withNetworkErrorBanner()
        .withErrorHandling()
        .task {
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
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            // Auto-save current project state on app termination
            saveProjectStateSync()
        }
    }

    /// Synchronously save project state (for termination handler)
    private func saveProjectStateSync() {
        guard let service = catalogService,
              var catalog = appState.catalog,
              let currentProject = appState.currentProject else {
            return
        }

        // Save current state to project
        appState.saveCurrentStateToProject()

        // Update catalog with modified project
        if let updatedProject = appState.currentProject {
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
}

#Preview {
    MainLayoutView()
}
