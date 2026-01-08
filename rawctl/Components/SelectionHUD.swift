//
//  SelectionHUD.swift
//  rawctl
//
//  Floating HUD showing multi-selection state with quick actions
//

import SwiftUI

/// Global floating HUD for multi-selection state
struct SelectionHUD: View {
    @ObservedObject var appState: AppState
    @State private var isExpanded = false
    @State private var isHovering = false
    @Binding var showExportDialog: Bool
    
    // Only show when there are selections outside of grid view
    var shouldShow: Bool {
        appState.selectionCount > 0 && appState.viewMode == .single
    }
    
    var body: some View {
        if shouldShow {
            VStack(spacing: 0) {
                // Collapsed pill
                HStack(spacing: 10) {
                    // Selection indicator
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.accentColor)
                        
                        Text("\(appState.selectionCount)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text(appState.selectionCount == 1 ? "selected" : "selected")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    // Expand button
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    
                    Divider()
                        .frame(height: 20)
                    
                    // Quick actions
                    HStack(spacing: 8) {
                        // Sync Edit (paste to all)
                        Button {
                            syncEditToSelection()
                        } label: {
                            Image(systemName: "paintbrush")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                        .help("Apply current edit to all selected")
                        
                        // Export
                        Button {
                            showExportDialog = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                        .help("Export selected photos")
                        
                        // Clear selection
                        Button {
                            withAnimation {
                                appState.clearMultiSelection()
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        .help("Clear selection")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
                )
                
                // Expanded thumbnail strip
                if isExpanded {
                    VStack(spacing: 8) {
                        // Thumbnail row
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(appState.selectedAssets.prefix(10)) { asset in
                                    SelectionThumbnail(
                                        asset: asset,
                                        isCurrentPhoto: appState.selectedAssetId == asset.id
                                    ) {
                                        appState.selectedAssetId = asset.id
                                    } onRemove: {
                                        appState.toggleSelection(asset.id)
                                    }
                                }
                                
                                if appState.selectionCount > 10 {
                                    Text("+\(appState.selectionCount - 10)")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .frame(width: 50, height: 50)
                                        .background(Color(white: 0.2))
                                        .cornerRadius(6)
                                }
                            }
                            .padding(.horizontal, 12)
                        }
                        .frame(height: 60)
                        
                        // Action buttons row
                        HStack(spacing: 12) {
                            Button {
                                appState.selectAll()
                            } label: {
                                Label("Select All", systemImage: "checkmark.circle")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.accentColor)
                            
                            Button {
                                appState.clearMultiSelection()
                            } label: {
                                Label("Deselect All", systemImage: "xmark.circle")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button {
                                showExportDialog = true
                            } label: {
                                Label("Export \(appState.selectionCount)", systemImage: "square.and.arrow.up.fill")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onHover { hovering in
                isHovering = hovering
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    private func syncEditToSelection() {
        guard let currentId = appState.selectedAssetId,
              let currentRecipe = appState.recipes[currentId] else { return }
        
        // Apply current recipe to all selected (preserving metadata like rating/flag)
        for assetId in appState.selectedAssetIds {
            if assetId != currentId {
                var recipe = appState.recipes[assetId] ?? EditRecipe()
                
                // Copy edit values, preserve organization
                recipe.exposure = currentRecipe.exposure
                recipe.contrast = currentRecipe.contrast
                recipe.highlights = currentRecipe.highlights
                recipe.shadows = currentRecipe.shadows
                recipe.whites = currentRecipe.whites
                recipe.blacks = currentRecipe.blacks
                recipe.whiteBalance = currentRecipe.whiteBalance
                recipe.vibrance = currentRecipe.vibrance
                recipe.saturation = currentRecipe.saturation
                recipe.clarity = currentRecipe.clarity
                recipe.dehaze = currentRecipe.dehaze
                recipe.texture = currentRecipe.texture
                recipe.toneCurve = currentRecipe.toneCurve
                recipe.hsl = currentRecipe.hsl
                recipe.vignette = currentRecipe.vignette
                recipe.sharpness = currentRecipe.sharpness
                recipe.noiseReduction = currentRecipe.noiseReduction
                recipe.splitToning = currentRecipe.splitToning
                recipe.grain = currentRecipe.grain
                
                appState.recipes[assetId] = recipe
            }
        }
        
        // Save all recipes
        Task {
            for assetId in appState.selectedAssetIds {
                if let asset = appState.assets.first(where: { $0.id == assetId }) {
                    let recipe = appState.recipes[assetId] ?? EditRecipe()
                    await SidecarService.shared.saveRecipe(recipe, snapshots: [], for: asset.url)
                }
            }
        }
        
        appState.showHUD("Applied to \(appState.selectionCount) photos")
    }
}

/// Individual thumbnail in selection HUD
struct SelectionThumbnail: View {
    let asset: PhotoAsset
    let isCurrentPhoto: Bool
    let onTap: () -> Void
    let onRemove: () -> Void
    
    @State private var thumbnail: NSImage?
    @State private var isHovering = false
    
    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(white: 0.2))
                    .frame(width: 50, height: 50)
            }
            
            // Remove button on hover
            if isHovering {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            onRemove()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(2)
            }
        }
        .frame(width: 50, height: 50)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isCurrentPhoto ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .shadow(color: isCurrentPhoto ? Color.accentColor.opacity(0.4) : .clear, radius: 3)
        .scaleEffect(isCurrentPhoto ? 1.05 : 1.0)
        .onTapGesture {
            onTap()
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .task {
            thumbnail = await ThumbnailService.shared.thumbnail(for: asset, size: 100)
        }
    }
}

#Preview {
    SelectionHUD(appState: AppState(), showExportDialog: .constant(false))
        .preferredColorScheme(.dark)
}
