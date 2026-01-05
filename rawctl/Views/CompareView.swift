//
//  CompareView.swift
//  rawctl
//
//  Side-by-side photo comparison view
//

import SwiftUI

/// Compare two photos side by side
struct CompareView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var leftIndex: Int = 0
    @State private var rightIndex: Int = 1
    @State private var leftImage: NSImage?
    @State private var rightImage: NSImage?
    @State private var syncZoom = true
    @State private var zoomLevel: Double = 1.0
    @State private var panOffset: CGSize = .zero

    private var assets: [PhotoAsset] {
        appState.filteredAssets
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                topBar

                // Compare area
                HStack(spacing: 2) {
                    // Left photo
                    ComparePanel(
                        asset: assets[safe: leftIndex],
                        recipe: recipeFor(leftIndex),
                        image: leftImage,
                        zoomLevel: zoomLevel,
                        panOffset: syncZoom ? panOffset : .zero,
                        isPrimary: true,
                        onFlag: { flag in setFlag(leftIndex, flag) },
                        onRate: { rating in setRating(leftIndex, rating) }
                    )

                    // Divider handle
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 2)

                    // Right photo
                    ComparePanel(
                        asset: assets[safe: rightIndex],
                        recipe: recipeFor(rightIndex),
                        image: rightImage,
                        zoomLevel: zoomLevel,
                        panOffset: syncZoom ? panOffset : .zero,
                        isPrimary: false,
                        onFlag: { flag in setFlag(rightIndex, flag) },
                        onRate: { rating in setRating(rightIndex, rating) }
                    )
                }

                // Bottom controls
                bottomControls
            }
        }
        .task {
            await loadImages()
        }
        .onKeyPress(.leftArrow) {
            navigateLeft()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            navigateRight()
            return .handled
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        .onKeyPress("1") { setFlag(leftIndex, .pick); return .handled }
        .onKeyPress("2") { setFlag(rightIndex, .pick); return .handled }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Compare Mode")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            Toggle(isOn: $syncZoom) {
                Label("Sync Zoom", systemImage: "lock.fill")
            }
            .toggleStyle(.button)
            .font(.caption)
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack(spacing: 20) {
            // Left navigation
            Button {
                navigateLeft()
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 28))
            }
            .buttonStyle(.plain)
            .foregroundColor(.white.opacity(0.8))

            // Zoom controls
            HStack(spacing: 8) {
                Button {
                    zoomLevel = max(0.5, zoomLevel - 0.25)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }

                Text("\(Int(zoomLevel * 100))%")
                    .font(.caption.monospacedDigit())
                    .frame(width: 50)

                Button {
                    zoomLevel = min(4.0, zoomLevel + 0.25)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }

                Button {
                    zoomLevel = 1.0
                    panOffset = .zero
                } label: {
                    Text("1:1")
                        .font(.caption)
                }
            }
            .foregroundColor(.white)

            // Swap button
            Button {
                swap(&leftIndex, &rightIndex)
                Task { await loadImages() }
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundColor(.white.opacity(0.8))

            // Right navigation
            Button {
                navigateRight()
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 28))
            }
            .buttonStyle(.plain)
            .foregroundColor(.white.opacity(0.8))
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }

    // MARK: - Helpers

    private func recipeFor(_ index: Int) -> EditRecipe {
        guard let asset = assets[safe: index] else { return EditRecipe() }
        return appState.recipes[asset.id] ?? EditRecipe()
    }

    private func setFlag(_ index: Int, _ flag: Flag) {
        guard let asset = assets[safe: index] else { return }
        var recipe = appState.recipes[asset.id] ?? EditRecipe()
        recipe.flag = flag
        appState.recipes[asset.id] = recipe
        appState.saveCurrentRecipe()
    }

    private func setRating(_ index: Int, _ rating: Int) {
        guard let asset = assets[safe: index] else { return }
        var recipe = appState.recipes[asset.id] ?? EditRecipe()
        recipe.rating = rating
        appState.recipes[asset.id] = recipe
        appState.saveCurrentRecipe()
    }

    private func navigateLeft() {
        if leftIndex > 0 {
            rightIndex = leftIndex
            leftIndex -= 1
            Task { await loadImages() }
        }
    }

    private func navigateRight() {
        if rightIndex < assets.count - 1 {
            leftIndex = rightIndex
            rightIndex += 1
            Task { await loadImages() }
        }
    }

    private func loadImages() async {
        async let leftLoad = loadImage(for: leftIndex)
        async let rightLoad = loadImage(for: rightIndex)

        let (left, right) = await (leftLoad, rightLoad)

        await MainActor.run {
            leftImage = left
            rightImage = right
        }
    }

    private func loadImage(for index: Int) async -> NSImage? {
        guard let asset = assets[safe: index] else { return nil }
        let recipe = appState.recipes[asset.id] ?? EditRecipe()
        return await ImagePipeline.shared.renderPreview(for: asset, recipe: recipe, maxSize: 1200)
    }
}

/// Single panel in compare view
struct ComparePanel: View {
    let asset: PhotoAsset?
    let recipe: EditRecipe
    let image: NSImage?
    let zoomLevel: Double
    let panOffset: CGSize
    let isPrimary: Bool
    let onFlag: (Flag) -> Void
    let onRate: (Int) -> Void

    var body: some View {
        ZStack {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(zoomLevel)
                    .offset(panOffset)
            } else {
                ProgressView()
            }

            // Overlay
            VStack {
                // Filename
                HStack {
                    Text(asset?.filename ?? "")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)

                    Spacer()

                    // Keyboard hint
                    Text(isPrimary ? "Press 1 to pick" : "Press 2 to pick")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(8)

                Spacer()

                // Rating and flag
                HStack {
                    // Stars
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= recipe.rating ? "star.fill" : "star")
                                .foregroundColor(star <= recipe.rating ? .yellow : .gray.opacity(0.5))
                        }
                    }

                    Spacer()

                    // Flag
                    if recipe.flag != .none {
                        Image(systemName: recipe.flag == .pick ? "flag.fill" : "xmark.circle.fill")
                            .foregroundColor(recipe.flag == .pick ? .green : .red)
                    }
                }
                .padding(8)
                .background(Color.black.opacity(0.6))
            }
        }
    }
}

#Preview {
    CompareView(appState: AppState())
}
