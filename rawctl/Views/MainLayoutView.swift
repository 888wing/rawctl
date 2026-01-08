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
        .task {
            // Initialize catalog on startup
            do {
                let service = CatalogService(catalogPath: CatalogService.defaultCatalogPath)
                let catalog = try await service.loadOrCreate(libraryPath: CatalogService.defaultLibraryPath)
                appState.catalog = catalog
            } catch {
                print("[MainLayoutView] Failed to load catalog: \(error)")
            }

            // Load last opened or default folder on startup
            await appState.loadStartupFolder()
        }
        .sheet(isPresented: $showExportDialog) {
            ExportDialog(appState: appState)
        }
    }
}

#Preview {
    MainLayoutView()
}
