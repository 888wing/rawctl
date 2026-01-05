//
//  SidebarView.swift
//  rawctl
//
//  Left sidebar with folder selection and file list with thumbnails
//

import SwiftUI

/// Left sidebar showing folder and file list
struct SidebarView: View {
    @ObservedObject var appState: AppState
    @StateObject private var folderManager = FolderManager.shared
    @State private var pathInput: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // New Catalog-based sidebar sections
            ScrollView {
                VStack(spacing: 0) {
                    // Library section (All Photos, Recent, Quick Collection)
                    LibrarySection(appState: appState)

                    Divider().padding(.horizontal, 12)

                    // Projects section with month grouping
                    ProjectsSection(appState: appState)

                    Divider().padding(.horizontal, 12)

                    // Smart Collections (5 Stars, Picks, Rejects, etc.)
                    SmartCollectionsSection(appState: appState)

                    Divider().padding(.horizontal, 12)

                    // Connected devices/memory cards
                    DevicesSection(appState: appState)

                    Divider().padding(.horizontal, 12)

                    // Legacy folder browsing section (for backward compatibility)
                    legacyFolderSection
                }
            }

            Spacer(minLength: 0)

            Divider()

            // Account section at bottom
            accountSection
        }
        .background(.ultraThinMaterial)
        .overlay {
            if appState.isLoading {
                loadingOverlay
            }
        }
        .onAppear {
            loadDefaultFolderIfNeeded()
        }
    }

    // MARK: - Legacy Folder Section

    @State private var legacyFoldersExpanded = false

    private var legacyFolderSection: some View {
        DisclosureGroup("Browse Folders", isExpanded: $legacyFoldersExpanded) {
            VStack(spacing: 4) {
                // Saved Folders
                if !folderManager.sources.isEmpty {
                    ForEach(folderManager.sources) { source in
                        SavedFolderRow(
                            source: source,
                            isCurrentFolder: appState.selectedFolder == source.url,
                            onSelect: {
                                loadFolder(source)
                            },
                            onSetDefault: {
                                folderManager.setAsDefault(source.id)
                            },
                            onRemove: {
                                folderManager.removeFolder(source.id)
                            }
                        )
                    }
                }

                // Open folder button
                Button {
                    openFolder()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 11))
                        Text("Open Folder…")
                            .font(.system(size: 11))
                        Spacer()
                    }
                    .foregroundColor(.accentColor)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                }
                .buttonStyle(.plain)

                // Path input
                HStack(spacing: 6) {
                    TextField("Path...", text: $pathInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10))
                        .padding(4)
                        .background(Color(white: 0.15))
                        .cornerRadius(4)
                        .onSubmit {
                            Task {
                                await appState.openFolderFromPath(pathInput)
                            }
                        }

                    Button {
                        Task {
                            await appState.openFolderFromPath(pathInput)
                        }
                    } label: {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(pathInput.isEmpty)
                }
                .padding(.horizontal, 8)
            }
            .padding(.vertical, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - Folder Actions

    private func loadFolder(_ source: FolderSource) {
        guard folderManager.startAccessingFolder(source) else {
            print("[SidebarView] Cannot access folder: \(source.url.path)")
            return
        }
        
        appState.selectedFolder = source.url
        appState.isLoading = true
        appState.loadingMessage = "Scanning folder…"
        
        Task {
            do {
                let assets = try await FileSystemService.scanFolder(source.url)
                await MainActor.run {
                    appState.assets = assets
                    appState.isLoading = false
                    appState.recipes = [:]
                    folderManager.updateFolderState(source.id, isLoaded: true, assetCount: assets.count)
                }
                await appState.loadAllRecipes()
                await MainActor.run {
                    if let first = appState.assets.first {
                        appState.selectedAssetId = first.id
                    }
                }
            } catch {
                await MainActor.run {
                    appState.isLoading = false
                }
            }
        }
    }
    
    private func loadDefaultFolderIfNeeded() {
        // Only load if no folder is currently selected and there's a default
        guard appState.selectedFolder == nil else { return }
        
        if let defaultSource = folderManager.getDefaultFolder() {
            loadFolder(defaultSource)
        }
    }
    
    // MARK: - Account Section
    
    @ObservedObject private var accountService = AccountService.shared
    @State private var showAccountSheet = false
    
    private var accountSection: some View {
        Button {
            showAccountSheet = true
        } label: {
            HStack(spacing: 10) {
                // Avatar or icon
                if accountService.isAuthenticated {
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 28, height: 28)
                        .overlay {
                            Text(accountService.currentUser?.email.prefix(1).uppercased() ?? "?")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.accentColor)
                        }
                } else {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    if accountService.isAuthenticated {
                        Text(accountService.currentUser?.email ?? "")
                            .font(.system(size: 11))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        // Credits badge
                        HStack(spacing: 4) {
                            Image(systemName: "sparkle")
                                .font(.system(size: 8))
                            Text("\(accountService.creditsBalance?.totalRemaining ?? 0) credits")
                                .font(.system(size: 9))
                        }
                        .foregroundColor(.secondary)
                    } else {
                        Text("Sign In")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)
                        Text("Get 10 free AI credits")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        .sheet(isPresented: $showAccountSheet) {
            AccountSheet()
        }
    }
    
    // MARK: - Loading Overlay
    
    private var loadingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(appState.loadingMessage)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Actions
    
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
                    appState.recipes = [:]
                }
                await appState.loadAllRecipes()
                await MainActor.run {
                    if let first = appState.assets.first {
                        appState.selectedAssetId = first.id
                    }
                }
            } catch {
                await MainActor.run {
                    appState.isLoading = false
                }
            }
        }
    }
}

// MARK: - File Row with Thumbnail

struct FileRowWithThumbnail: View {
    let asset: PhotoAsset
    let isSelected: Bool
    let hasEdits: Bool
    
    @State private var thumbnail: NSImage?
    
    var body: some View {
        HStack(spacing: 10) {
            // Mini thumbnail
            ZStack {
                if let thumbnail = thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 36, height: 36)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 36, height: 36)
                }
                
                // Edited dot
                if hasEdits {
                    VStack {
                        HStack {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 6, height: 6)
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(2)
                }
            }
            .frame(width: 36, height: 36)
            .cornerRadius(4)
            
            // Filename (without extension)
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.filename.replacingOccurrences(of: ".\(asset.url.pathExtension)", with: ""))
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .foregroundColor(isSelected ? .primary : .primary.opacity(0.9))
                
                // Subtle extension
                Text(asset.fileExtension)
                    .font(.system(size: 9))
                    .foregroundColor(asset.isRAW ? .orange.opacity(0.8) : .secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .task {
            thumbnail = await ThumbnailService.shared.thumbnail(for: asset, size: 72)
        }
    }
}

// MARK: - Sidebar Thumbnail

struct SidebarThumbnail: View {
    let asset: PhotoAsset
    let isSelected: Bool
    let hasEdits: Bool
    
    @State private var thumbnail: NSImage?
    
    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 70, height: 70)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 70, height: 70)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundColor(.gray.opacity(0.4))
                    }
            }
            
            // Edited indicator
            if hasEdits {
                VStack {
                    HStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 8, height: 8)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(4)
            }
            
            // RAW badge (subtle)
            if asset.isRAW {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("R")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.orange)
                            .padding(2)
                            .background(.black.opacity(0.6))
                            .cornerRadius(2)
                    }
                }
                .padding(3)
            }
        }
        .frame(width: 70, height: 70)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .shadow(color: isSelected ? Color.accentColor.opacity(0.4) : .clear, radius: 3)
        .opacity(isSelected ? 1.0 : 0.7)
        .task {
            thumbnail = await ThumbnailService.shared.thumbnail(for: asset, size: 140)
        }
    }
}

// MARK: - Saved Folder Row

struct SavedFolderRow: View {
    let source: FolderSource
    let isCurrentFolder: Bool
    let onSelect: () -> Void
    let onSetDefault: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 8) {
                // Default indicator
                if source.isDefault {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                } else {
                    Image(systemName: "folder")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.name)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundColor(isCurrentFolder ? .accentColor : .primary)
                    
                    Text("\(source.assetCount)  photos")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Current folder indicator
                if isCurrentFolder {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(isCurrentFolder ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onSetDefault()
            } label: {
                Label(source.isDefault ? "Default" : "Set as Default", systemImage: "star")
            }
            .disabled(source.isDefault)
            
            Divider()
            
            Button(role: .destructive) {
                onRemove()
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }
}

#Preview {
    SidebarView(appState: AppState())
        .frame(width: 250, height: 600)
        .preferredColorScheme(.dark)
}
