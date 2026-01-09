//
//  GridView.swift
//  rawctl
//
//  Thumbnail grid view for browsing photos
//

import SwiftUI

/// Grid view showing photo thumbnails
struct GridView: View {
    @ObservedObject var appState: AppState
    @State private var thumbnailSize: CGFloat = 160
    
    // Thumbnail size constraints
    private let minThumbnailSize: CGFloat = 80
    private let maxThumbnailSize: CGFloat = 280
    
    // Responsive grid columns
    private var columns: [GridItem] {
        let effectiveSize = max(minThumbnailSize, min(thumbnailSize, maxThumbnailSize))
        let spacing: CGFloat = effectiveSize < 120 ? 8 : 12
        return [GridItem(.adaptive(minimum: effectiveSize, maximum: effectiveSize + 40), spacing: spacing)]
    }
    
    // Calculate optimal thumbnail size based on width
    private func optimalThumbnailSize(for width: CGFloat) -> CGFloat {
        // Aim for 3-6 columns depending on width
        let targetColumns = width < 500 ? 3 : (width < 800 ? 4 : 5)
        let spacing: CGFloat = 12
        let padding: CGFloat = 32
        let optimalSize = (width - padding - (spacing * CGFloat(targetColumns - 1))) / CGFloat(targetColumns)
        return max(minThumbnailSize, min(optimalSize, maxThumbnailSize))
    }
    
    /// Group assets by current sort criteria
    private var groupedAssets: [(key: String, assets: [PhotoAsset])] {
        let assets = appState.filteredAssets
        
        var groups: [String: [PhotoAsset]] = [:]
        
        for asset in assets {
            let key = groupKey(for: asset)
            groups[key, default: []].append(asset)
        }
        
        // Sort groups by key
        let sorted = groups.sorted { a, b in
            if appState.sortOrder == .ascending {
                return a.key < b.key
            } else {
                return a.key > b.key
            }
        }
        
        return sorted.map { (key: $0.key, assets: $0.value) }
    }
    
    /// Generate group key based on sort criteria
    private func groupKey(for asset: PhotoAsset) -> String {
        switch appState.sortCriteria {
        case .filename:
            // Group by camera prefix pattern (more meaningful than first letter)
            let filename = asset.filename.uppercased()

            // Common camera filename patterns
            let patterns = [
                "DSC_", "DSCN", "DSC-",           // Nikon
                "IMG_", "IMG-",                   // Canon, iPhone
                "_DSC",                           // Sony
                "P10", "P11", "P12",              // Panasonic
                "DSCF", "DSCN",                   // Fujifilm
                "R0", "RICOH",                    // Ricoh
                "GH0", "G0",                      // Panasonic GH series
                "L10", "L1P",                     // Leica
                "DJI_", "DJI-",                   // DJI drone
                "GOPR", "GH0", "GX0",             // GoPro
                "SAM_",                           // Samsung
                "DC_", "DC-",                     // Generic
            ]

            for pattern in patterns {
                if filename.hasPrefix(pattern) {
                    return pattern.trimmingCharacters(in: CharacterSet(charactersIn: "_-"))
                }
            }

            // Check for Sony _DSC pattern (appears after number)
            if filename.contains("_DSC") {
                return "_DSC"
            }

            // Fallback: group by file extension
            return asset.fileExtension.uppercased()
            
        case .captureDate:
            // Group by date (YYYY-MM-DD)
            let date = asset.metadata?.dateTime ?? asset.creationDate ?? asset.modificationDate
            if let d = date {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.string(from: d)
            }
            return "Unknown Date"
            
        case .modificationDate:
            // Group by date (YYYY-MM-DD)
            if let d = asset.modificationDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.string(from: d)
            }
            return "Unknown Date"
            
        case .fileSize:
            // Group by size range
            let mb = Double(asset.fileSize) / 1_000_000
            if mb < 1 { return "< 1 MB" }
            else if mb < 5 { return "1-5 MB" }
            else if mb < 10 { return "5-10 MB" }
            else if mb < 25 { return "10-25 MB" }
            else if mb < 50 { return "25-50 MB" }
            else { return "> 50 MB" }
            
        case .fileType:
            // Group by extension
            return asset.fileExtension
            
        case .rating:
            // Group by rating
            let rating = appState.recipes[asset.id]?.rating ?? 0
            if rating == 0 { return "Unrated" }
            return String(repeating: "★", count: rating)
        }
    }
    
    /// Display label for group
    private func groupLabel(for key: String) -> String {
        switch appState.sortCriteria {
        case .captureDate, .modificationDate:
            // Format date nicely
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: key) {
                let displayFormatter = DateFormatter()
                displayFormatter.dateStyle = .medium
                displayFormatter.locale = Locale(identifier: "zh-Hant")
                return displayFormatter.string(from: date)
            }
            return key
        case .filename:
            // Camera prefix display names
            let cameraNames: [String: String] = [
                "DSC": "Nikon",
                "DSCN": "Nikon",
                "IMG": "Canon / iPhone",
                "_DSC": "Sony",
                "DSCF": "Fujifilm",
                "DJI": "DJI Drone",
                "GOPR": "GoPro",
                "GH0": "Panasonic GH",
                "G0": "Panasonic G",
                "GX0": "GoPro",
                "SAM": "Samsung",
                "DC": "Digital Camera",
                "R0": "Ricoh",
                "RICOH": "Ricoh",
                "L10": "Leica",
                "L1P": "Leica",
                "P10": "Panasonic",
                "P11": "Panasonic",
                "P12": "Panasonic",
            ]
            return cameraNames[key] ?? key
        default:
            return key
        }
    }
    
    @State private var showExportDialog = false
    
    // Explicit dependency on recipes to trigger view updates
    private var recipesVersion: Int { appState.recipes.count }
    
    var body: some View {
        // Add implicit dependency on recipes for filter refresh
        let _ = recipesVersion
        let _ = appState.recipes
        
        VStack(spacing: 0) {
            // Selection mode bar
            SelectionBar(appState: appState, showExportDialog: $showExportDialog)
            
            // Global thumbnail loading progress bar
            if case .loading(let loaded, let total) = appState.thumbnailLoadingProgress {
                VStack(spacing: 4) {
                    ProgressView(value: Double(loaded), total: Double(total))
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                    HStack {
                        Text("Loading thumbnails...")
                        Spacer()
                        Text("\(loaded)/\(total)")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            }
            
            // Filter bar
            FilterBar(appState: appState)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            
            // Grid content with section headers
            gridContent
            
            // Bottom toolbar with size slider
            Divider()
            HStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Slider(value: $thumbnailSize, in: minThumbnailSize...maxThumbnailSize)
                    .frame(minWidth: 80, maxWidth: 140)
                
                Image(systemName: "photo.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(Int(thumbnailSize))px")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 40)
                
                Spacer()
                
                Text("\(appState.assets.count) photos")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .background(
            GeometryReader { geometry in
                Color.clear.onAppear {
                    // Set initial optimal thumbnail size based on available width
                    thumbnailSize = optimalThumbnailSize(for: geometry.size.width)
                }
            }
        )
        .background(Color(nsColor: NSColor(calibratedWhite: 0.08, alpha: 1.0)))
        // Keyboard shortcuts
        .onKeyPress(.escape) {
            appState.clearMultiSelection()
            appState.isSelectionMode = false
            return .handled
        }
        .onKeyPress("s") {
            withAnimation {
                appState.isSelectionMode.toggle()
            }
            return .handled
        }
        .sheet(isPresented: $showExportDialog) {
            ExportDialog(appState: appState)
        }
    }
    
    /// Handle tap with modifier keys
    private func handleTap(asset: PhotoAsset, modifiers: EventModifiers) {
        if modifiers.contains(.command) {
            // Cmd+click: toggle in multi-selection
            appState.toggleSelection(asset.id)
        } else if modifiers.contains(.shift) {
            // Shift+click: extend selection
            appState.extendSelection(to: asset.id)
        } else if appState.isSelectionMode {
            // Selection mode: normal click toggles selection
            appState.toggleSelection(asset.id)
        } else {
            // Normal click: single selection
            appState.clearMultiSelection()
            appState.selectedAssetId = asset.id
        }
    }
    
    /// Grid content view (extracted for compiler performance)
    @ViewBuilder
    private var gridContent: some View {
        if appState.assets.isEmpty {
            // Empty state - no photos loaded
            VStack {
                Spacer()
                EmptyStateView.noPhotos {
                    openFolder()
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if appState.filteredAssets.isEmpty {
            // Empty state - filter has no results
            VStack {
                Spacer()
                EmptyStateView(
                    icon: "line.3.horizontal.decrease.circle",
                    title: "No Matching Photos",
                    subtitle: "Try adjusting your filter criteria"
                )
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16, pinnedViews: [.sectionHeaders]) {
                    ForEach(groupedAssets, id: \.key) { group in
                        Section {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(group.assets) { asset in
                                    thumbnailForAsset(asset)
                                }
                            }
                        } header: {
                            SectionHeader(
                                title: groupLabel(for: group.key),
                                count: group.assets.count,
                                sortCriteria: appState.sortCriteria
                            )
                            .animation(nil, value: group.key)
                        }
                    }
                }
                .padding(16)
                .transaction { transaction in
                    // Disable animations on section header re-positioning
                    transaction.animation = nil
                }
            }
        }
    }
    
    /// Single thumbnail view (extracted for compiler performance)
    private func thumbnailForAsset(_ asset: PhotoAsset) -> some View {
        GridThumbnail(
            asset: asset,
            size: thumbnailSize,
            isSelected: appState.selectedAssetId == asset.id || appState.isSelected(asset.id),
            isMultiSelected: appState.isSelected(asset.id),
            hasEdits: appState.recipes[asset.id]?.hasEdits ?? false,
            recipe: appState.recipes[asset.id] ?? EditRecipe(),
            onTap: { modifiers in
                handleTap(asset: asset, modifiers: modifiers)
            },
            onDoubleTap: {
                appState.select(asset)
            },
            onRatingChange: { rating in
                var recipe = appState.recipes[asset.id] ?? EditRecipe()
                recipe.rating = rating
                appState.recipes[asset.id] = recipe
                Task { @MainActor in
                    await SidecarService.shared.saveRecipe(recipe, snapshots: [], for: asset.url)
                }
                appState.showHUD(rating > 0 ? "Rating: \(String(repeating: "★", count: rating))" : "Rating cleared")
            },
            onFlagChange: { flag in
                var recipe = appState.recipes[asset.id] ?? EditRecipe()
                recipe.flag = flag
                appState.recipes[asset.id] = recipe
                Task { @MainActor in
                    await SidecarService.shared.saveRecipe(recipe, snapshots: [], for: asset.url)
                }
                let message: String
                switch flag {
                case .pick: message = "Flagged as Pick"
                case .reject: message = "Flagged as Reject"
                case .none: message = "Flag cleared"
                }
                appState.showHUD(message)
            }
        )
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

/// Selection mode bar for multi-selection
struct SelectionBar: View {
    @ObservedObject var appState: AppState
    @Binding var showExportDialog: Bool
    
    var body: some View {
        if appState.isSelectionMode || appState.selectionCount > 0 {
            HStack(spacing: 12) {
                // Selection mode toggle
                selectionModeToggle
                
                // Selection count
                if appState.selectionCount > 0 {
                    Text("\(appState.selectionCount) selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Quick actions when items selected
                if appState.selectionCount > 0 {
                    actionButtons
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(appState.isSelectionMode ? Color.accentColor.opacity(0.15) : Color.accentColor.opacity(0.1))
        }
    }
    
    private var selectionModeToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                appState.isSelectionMode.toggle()
                if !appState.isSelectionMode {
                    appState.clearMultiSelection()
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: appState.isSelectionMode ? "checkmark.circle.fill" : "checkmark.circle")
                Text(appState.isSelectionMode ? "Select Mode" : "Multi-select")
            }
            .font(.caption.bold())
            .foregroundColor(appState.isSelectionMode ? .white : .accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(appState.isSelectionMode ? Color.accentColor : Color.clear)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button { appState.selectAll() } label: {
                Text("Select All").font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
            
            Button { appState.clearMultiSelection() } label: {
                Text("Deselect").font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            
            Divider().frame(height: 16)
            
            Button { showExportDialog = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export")
                }
                .font(.caption.bold())
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }
}

/// Section header for photo groups - Enhanced with stronger styling
struct SectionHeader: View {
    let title: String
    let count: Int
    let sortCriteria: AppState.SortCriteria

    var body: some View {
        HStack(spacing: 10) {
            // Sort icon with background
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 24, height: 24)
                Image(systemName: sortCriteria.icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.accentColor)
            }
            
            // Title
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
            
            // Count badge
            Text("\(count)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color(white: 0.2))
                .cornerRadius(10)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.12))
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
        )
    }
}

/// Single thumbnail in the grid - Enhanced with better hover effects
struct GridThumbnail: View {
    let asset: PhotoAsset
    let size: CGFloat
    let isSelected: Bool
    var isMultiSelected: Bool = false
    let hasEdits: Bool
    let recipe: EditRecipe
    let onTap: (EventModifiers) -> Void
    let onDoubleTap: () -> Void
    var onRatingChange: ((Int) -> Void)? = nil
    var onFlagChange: ((Flag) -> Void)? = nil
    
    @State private var thumbnail: NSImage?
    @State private var isHovering = false
    
    var body: some View {
        ZStack {
            // Fixed square container
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.15))
                .frame(width: size, height: size)
            
            // Thumbnail image - centered crop
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()
                    .cornerRadius(8)
            } else {
                // Loading placeholder with shimmer effect
                ShimmerLoadingView()
            }
            
            // Multi-selection checkbox overlay
            if isMultiSelected {
                VStack {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 22, height: 22)
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(6)
            }
            
            // Overlay badges
            VStack {
                HStack {
                    // Only show these if not multi-selected (checkbox takes priority)
                    if !isMultiSelected {
                        // Edited indicator with subtle glow
                        if hasEdits {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 8, height: 8)
                                .shadow(color: Color.accentColor.opacity(0.5), radius: 2)
                        }
                        
                        // Color label indicator
                        if recipe.colorLabel != .none {
                            Circle()
                                .fill(colorLabelColor)
                                .frame(width: 8, height: 8)
                                .shadow(color: colorLabelColor.opacity(0.5), radius: 2)
                        }
                    }
                    
                    Spacer()
                    
                    // RAW badge only (no extension cluttering)
                    if asset.isRAW {
                        Text("R")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.7))
                            .cornerRadius(3)
                    }
                }
                
                Spacer()
                
                // Bottom: Rating and Flag + Hover info
                HStack {
                    // Rating stars
                    if recipe.rating > 0 {
                        HStack(spacing: 1) {
                            ForEach(1...recipe.rating, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 6))
                                    .foregroundColor(.yellow)
                            }
                        }
                        .padding(2)
                        .background(.black.opacity(0.6))
                        .cornerRadius(2)
                    }
                    
                    Spacer()
                    
                    // Flag indicator
                    if recipe.flag == .pick {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.green)
                            .padding(2)
                            .background(.black.opacity(0.6))
                            .cornerRadius(2)
                    } else if recipe.flag == .reject {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.red)
                            .padding(2)
                            .background(.black.opacity(0.6))
                            .cornerRadius(2)
                    }
                }
                
                // Hover bar with quick rating/flag actions
                if isHovering && onRatingChange != nil && onFlagChange != nil {
                    ThumbnailHoverBar(
                        rating: recipe.rating,
                        flag: recipe.flag,
                        onRatingChange: { onRatingChange?($0) },
                        onFlagChange: { onFlagChange?($0) }
                    )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else if isHovering && !isSelected {
                    // Fallback: Hover info overlay - filename
                    HStack {
                        Text(asset.filename.replacingOccurrences(of: ".\(asset.url.pathExtension)", with: ""))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(.black.opacity(0.75))
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .padding(6)
            
            // Selection glow border
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
            }
            
            // Hover border glow (subtle)
            if isHovering && !isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
            }
        }
        .frame(width: size, height: size)
        // Shadow lift effect on hover (instead of scale)
        .shadow(
            color: isHovering ? .black.opacity(0.4) : .black.opacity(0.15),
            radius: isHovering ? 12 : 4,
            y: isHovering ? 6 : 2
        )
        .shadow(
            color: isSelected ? Color.accentColor.opacity(0.4) : .clear,
            radius: 8
        )
        .opacity(isSelected ? 1.0 : (isHovering ? 1.0 : 0.9))
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovering)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isSelected)
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                onDoubleTap()
            }
        )
        .simultaneousGesture(
            TapGesture(count: 1).modifiers(.command).onEnded {
                onTap(.command)
            }
        )
        .simultaneousGesture(
            TapGesture(count: 1).modifiers(.shift).onEnded {
                onTap(.shift)
            }
        )
        .onTapGesture {
            onTap([])
        }
        .onHover { hovering in
            withAnimation(.spring(response: 0.2)) {
                isHovering = hovering
            }
        }
        .task {
            thumbnail = await ThumbnailService.shared.thumbnail(for: asset, size: size * 2)
        }
    }
    
    private var colorLabelColor: Color {
        let c = recipe.colorLabel.color
        return Color(red: c.r, green: c.g, blue: c.b)
    }
}

/// Shimmer loading animation for thumbnails
struct ShimmerLoadingView: View {
    @State private var animationOffset: CGFloat = -1.0
    
    var body: some View {
        ZStack {
            // Base placeholder
            Rectangle()
                .fill(Color.gray.opacity(0.2))
            
            // Shimmer effect
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.2),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .offset(x: animationOffset * 200)
            
            // Photo icon
            Image(systemName: "photo")
                .font(.title3)
                .foregroundColor(.gray.opacity(0.5))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                animationOffset = 1.0
            }
        }
    }
}

#Preview {
    GridView(appState: AppState())
        .preferredColorScheme(.dark)
}

