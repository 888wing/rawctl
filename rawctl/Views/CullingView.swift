//
//  CullingView.swift
//  rawctl
//
//  Fullscreen culling mode for fast photo selection workflow
//

import SwiftUI

/// Culling mode - fullscreen single photo with rating/flag controls
struct CullingView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var showShortcutHints = true
    @State private var currentImage: NSImage?
    @State private var isLoading = true
    @State private var autoAdvance = true
    
    private var currentAsset: PhotoAsset? {
        appState.selectedAsset
    }
    
    private var currentRecipe: EditRecipe {
        guard let id = appState.selectedAssetId else { return EditRecipe() }
        return appState.recipes[id] ?? EditRecipe()
    }
    
    var body: some View {
        ZStack {
            // Black background
            Color.black.ignoresSafeArea()
            
            // Main photo
            if let image = currentImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .transition(.opacity)
            } else if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            }
            
            // Overlays
            VStack {
                // Top bar
                topBar
                
                Spacer()
                
                // Bottom controls
                bottomControls
            }
            
            // Keyboard shortcut hints (toggleable)
            if showShortcutHints {
                shortcutHintsOverlay
            }
            
            // Navigation arrows
            HStack {
                navigationButton(direction: .left)
                Spacer()
                navigationButton(direction: .right)
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            loadCurrentPhoto()
        }
        .onChange(of: appState.selectedAssetId) { _, _ in
            loadCurrentPhoto()
        }
        .onKeyPress("1") { setRating(1); return .handled }
        .onKeyPress("2") { setRating(2); return .handled }
        .onKeyPress("3") { setRating(3); return .handled }
        .onKeyPress("4") { setRating(4); return .handled }
        .onKeyPress("5") { setRating(5); return .handled }
        .onKeyPress("0") { setRating(0); return .handled }
        .onKeyPress("p") { setFlag(.pick); return .handled }
        .onKeyPress("x") { setFlag(.reject); return .handled }
        .onKeyPress("u") { setFlag(.none); return .handled }
        .onKeyPress(.rightArrow) { navigateNext(); return .handled }
        .onKeyPress(.leftArrow) { navigatePrevious(); return .handled }
        .onKeyPress(.space) { navigateNext(); return .handled }
        .onKeyPress(.escape) { dismiss(); return .handled }
        .onKeyPress("h") { showShortcutHints.toggle(); return .handled }
        .onKeyPress("a") { autoAdvance.toggle(); appState.showHUD(autoAdvance ? "Auto-advance ON" : "Auto-advance OFF"); return .handled }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Exit Culling Mode (Esc)")
            
            Spacer()
            
            // Photo counter
            if let index = appState.selectedIndex {
                Text("\(index + 1) / \(appState.assets.count)")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial.opacity(0.5))
                    .cornerRadius(6)
            }
            
            Spacer()
            
            // Settings
            HStack(spacing: 16) {
                Toggle(isOn: $autoAdvance) {
                    Label("Auto-advance", systemImage: autoAdvance ? "arrow.right.circle.fill" : "arrow.right.circle")
                        .foregroundStyle(.white.opacity(0.7))
                }
                .toggleStyle(.button)
                .buttonStyle(.plain)
                .help("Auto-advance after rating (A)")
                
                Toggle(isOn: $showShortcutHints) {
                    Image(systemName: showShortcutHints ? "keyboard.fill" : "keyboard")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .toggleStyle(.button)
                .buttonStyle(.plain)
                .help("Show keyboard hints (H)")
            }
        }
        .padding(20)
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Filename
            if let asset = currentAsset {
                Text(asset.filename)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            HStack(spacing: 40) {
                // Flag controls
                flagControls
                
                Divider()
                    .frame(height: 40)
                    .background(.white.opacity(0.2))
                
                // Rating controls
                ratingControls
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial.opacity(0.6))
            .cornerRadius(12)
        }
        .padding(.bottom, 40)
    }
    
    private var flagControls: some View {
        HStack(spacing: 20) {
            FlagButton(flag: .pick, currentFlag: currentRecipe.flag) {
                setFlag(.pick)
            }
            
            FlagButton(flag: .none, currentFlag: currentRecipe.flag) {
                setFlag(.none)
            }
            
            FlagButton(flag: .reject, currentFlag: currentRecipe.flag) {
                setFlag(.reject)
            }
        }
    }
    
    private var ratingControls: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { star in
                Button {
                    setRating(star)
                } label: {
                    Image(systemName: star <= currentRecipe.rating ? "star.fill" : "star")
                        .font(.system(size: 24))
                        .foregroundStyle(star <= currentRecipe.rating ? .yellow : .white.opacity(0.4))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(KeyEquivalent(Character("\(star)")), modifiers: [])
            }
            
            // Clear rating
            Button {
                setRating(0)
            } label: {
                Text("0")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Clear rating (0)")
        }
    }
    
    // MARK: - Navigation
    
    private enum NavigationDirection {
        case left, right
    }
    
    private func navigationButton(direction: NavigationDirection) -> some View {
        Button {
            if direction == .left {
                navigatePrevious()
            } else {
                navigateNext()
            }
        } label: {
            Image(systemName: direction == .left ? "chevron.left.circle.fill" : "chevron.right.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.3))
        }
        .buttonStyle(.plain)
        .opacity(canNavigate(direction) ? 1 : 0.3)
        .disabled(!canNavigate(direction))
    }
    
    private func canNavigate(_ direction: NavigationDirection) -> Bool {
        guard let index = appState.selectedIndex else { return false }
        if direction == .left {
            return index > 0
        } else {
            return index < appState.assets.count - 1
        }
    }
    
    // MARK: - Shortcut Hints Overlay
    
    private var shortcutHintsOverlay: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 24) {
                shortcutHint("P", "Pick")
                shortcutHint("U", "Unflag")
                shortcutHint("X", "Reject")
                
                Divider()
                    .frame(height: 30)
                    .background(.white.opacity(0.2))
                
                shortcutHint("1-5", "Rating")
                shortcutHint("0", "Clear")
                
                Divider()
                    .frame(height: 30)
                    .background(.white.opacity(0.2))
                
                shortcutHint("←→", "Navigate")
                shortcutHint("Space", "Next")
                shortcutHint("Esc", "Exit")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.black.opacity(0.6))
            .cornerRadius(8)
        }
        .padding(.bottom, 130)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: showShortcutHints)
    }
    
    private func shortcutHint(_ key: String, _ action: String) -> some View {
        HStack(spacing: 6) {
            Text(key)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.white.opacity(0.15))
                .cornerRadius(4)
            
            Text(action)
                .font(.system(size: 11))
        }
        .foregroundStyle(.white.opacity(0.7))
    }
    
    // MARK: - Actions
    
    private func loadCurrentPhoto() {
        guard let asset = currentAsset else { return }
        isLoading = true
        
        Task {
            let recipe = await MainActor.run { currentRecipe }
            if let image = await ImagePipeline.shared.renderPreview(
                for: asset,
                recipe: recipe,
                maxSize: 1600
            ) {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        self.currentImage = image
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    private func setRating(_ rating: Int) {
        guard let id = appState.selectedAssetId else { return }
        var recipe = appState.recipes[id] ?? EditRecipe()
        recipe.rating = rating
        appState.recipes[id] = recipe
        appState.saveCurrentRecipe()
        
        appState.showHUD(rating > 0 ? "Rating: \(String(repeating: "★", count: rating))" : "Rating cleared")
        
        if autoAdvance && rating > 0 {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                navigateNext()
            }
        }
    }
    
    private func setFlag(_ flag: Flag) {
        guard let id = appState.selectedAssetId else { return }
        var recipe = appState.recipes[id] ?? EditRecipe()
        recipe.flag = flag
        appState.recipes[id] = recipe
        appState.saveCurrentRecipe()
        
        let message: String
        switch flag {
        case .pick: message = "Flagged as Pick"
        case .reject: message = "Flagged as Reject"
        case .none: message = "Flag cleared"
        }
        appState.showHUD(message)
        
        if autoAdvance && flag != .none {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                navigateNext()
            }
        }
    }
    
    private func navigateNext() {
        withAnimation(.easeInOut(duration: 0.15)) {
            currentImage = nil
        }
        appState.selectNext()
    }
    
    private func navigatePrevious() {
        withAnimation(.easeInOut(duration: 0.15)) {
            currentImage = nil
        }
        appState.selectPrevious()
    }
}

// MARK: - Flag Button

private struct FlagButton: View {
    let flag: Flag
    let currentFlag: Flag
    let action: () -> Void
    
    private var isSelected: Bool {
        flag == currentFlag
    }
    
    private var icon: String {
        switch flag {
        case .pick: return isSelected ? "flag.fill" : "flag"
        case .reject: return isSelected ? "xmark.circle.fill" : "xmark.circle"
        case .none: return "minus.circle"
        }
    }
    
    private var color: Color {
        guard isSelected else { return .white.opacity(0.5) }
        switch flag {
        case .pick: return .green
        case .reject: return .red
        case .none: return .white.opacity(0.5)
        }
    }
    
    private var label: String {
        switch flag {
        case .pick: return "Pick"
        case .reject: return "Reject"
        case .none: return "Unflag"
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(color)
                
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(width: 60)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CullingView(appState: AppState())
}
