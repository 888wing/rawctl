//
//  SurveyModeView.swift
//  rawctl
//
//  Full-screen survey mode for rapid culling
//

import SwiftUI

/// Full-screen survey mode for efficient culling
struct SurveyModeView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex: Int = 0
    @State private var previewImage: NSImage?
    @State private var isLoading = true

    private var assets: [PhotoAsset] {
        appState.filteredAssets
    }

    private var currentAsset: PhotoAsset? {
        assets[safe: currentIndex]
    }

    private var currentRecipe: EditRecipe {
        guard let asset = currentAsset else { return EditRecipe() }
        return appState.recipes[asset.id] ?? EditRecipe()
    }

    var body: some View {
        ZStack {
            // Black background
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                topBar

                // Main image
                imageView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom controls
                bottomControls
            }
        }
        .task {
            if let index = assets.firstIndex(where: { $0.id == appState.selectedAssetId }) {
                currentIndex = index
            }
            await loadCurrentImage()
        }
        .onKeyPress(.leftArrow) {
            navigatePrevious()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            navigateNext()
            return .handled
        }
        .onKeyPress("p") {
            setFlag(.pick)
            return .handled
        }
        .onKeyPress("x") {
            setFlag(.reject)
            return .handled
        }
        .onKeyPress("u") {
            setFlag(.none)
            return .handled
        }
        .onKeyPress("1") { setRating(1); return .handled }
        .onKeyPress("2") { setRating(2); return .handled }
        .onKeyPress("3") { setRating(3); return .handled }
        .onKeyPress("4") { setRating(4); return .handled }
        .onKeyPress("5") { setRating(5); return .handled }
        .onKeyPress("0") { setRating(0); return .handled }
        .onKeyPress(.space) {
            toggleFlag()
            return .handled
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
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

            Text("Survey Mode")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            // Stats
            HStack(spacing: 16) {
                StatBadge(label: "Picks", count: picksCount, color: .green)
                StatBadge(label: "Rejects", count: rejectsCount, color: .red)
                StatBadge(label: "Unrated", count: unratedCount, color: .gray)
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }

    // MARK: - Image View

    private var imageView: some View {
        ZStack {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else if let image = previewImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
            }

            // Rating/Flag overlay
            VStack {
                Spacer()
                HStack {
                    // Current rating
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= currentRecipe.rating ? "star.fill" : "star")
                                .foregroundColor(star <= currentRecipe.rating ? .yellow : .gray.opacity(0.5))
                        }
                    }
                    .font(.title2)

                    Spacer()

                    // Current flag
                    if currentRecipe.flag != .none {
                        Image(systemName: currentRecipe.flag == .pick ? "flag.fill" : "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(currentRecipe.flag == .pick ? .green : .red)
                    }
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 12) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.2))

                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 4)
            .cornerRadius(2)

            // Navigation and actions
            HStack(spacing: 40) {
                // Previous
                Button {
                    navigatePrevious()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 36))
                        Text("←")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.8))
                .disabled(currentIndex == 0)

                // Reject
                Button {
                    setFlag(.reject)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 44))
                        Text("X")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)

                // Unflag
                Button {
                    setFlag(.none)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "circle")
                            .font(.system(size: 44))
                        Text("U")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.6))

                // Pick
                Button {
                    setFlag(.pick)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 44))
                        Text("P")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.green)

                // Next
                Button {
                    navigateNext()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 36))
                        Text("→")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.8))
                .disabled(currentIndex >= assets.count - 1)
            }

            // Progress text
            Text("\(currentIndex + 1) of \(assets.count)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }

    // MARK: - Computed Properties

    private var progress: Double {
        guard !assets.isEmpty else { return 0 }
        return Double(currentIndex + 1) / Double(assets.count)
    }

    private var picksCount: Int {
        assets.filter { appState.recipes[$0.id]?.flag == .pick }.count
    }

    private var rejectsCount: Int {
        assets.filter { appState.recipes[$0.id]?.flag == .reject }.count
    }

    private var unratedCount: Int {
        assets.filter { (appState.recipes[$0.id]?.rating ?? 0) == 0 }.count
    }

    // MARK: - Actions

    private func navigatePrevious() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        Task { await loadCurrentImage() }
    }

    private func navigateNext() {
        guard currentIndex < assets.count - 1 else { return }
        currentIndex += 1
        Task { await loadCurrentImage() }
    }

    private func setRating(_ rating: Int) {
        guard let asset = currentAsset else { return }
        var recipe = appState.recipes[asset.id] ?? EditRecipe()
        recipe.rating = rating
        appState.recipes[asset.id] = recipe
        appState.saveCurrentRecipe()
    }

    private func setFlag(_ flag: Flag) {
        guard let asset = currentAsset else { return }
        var recipe = appState.recipes[asset.id] ?? EditRecipe()
        recipe.flag = flag
        appState.recipes[asset.id] = recipe
        appState.saveCurrentRecipe()

        // Auto-advance after flagging
        if currentIndex < assets.count - 1 {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(150))
                navigateNext()
            }
        }
    }

    private func toggleFlag() {
        guard let asset = currentAsset else { return }
        let currentFlag = appState.recipes[asset.id]?.flag ?? .none
        let newFlag: Flag = currentFlag == .pick ? .none : .pick
        setFlag(newFlag)
    }

    private func loadCurrentImage() async {
        guard let asset = currentAsset else { return }

        isLoading = true
        let recipe = appState.recipes[asset.id] ?? EditRecipe()

        if let image = await ImagePipeline.shared.renderPreview(
            for: asset,
            recipe: recipe,
            maxSize: 1600
        ) {
            await MainActor.run {
                previewImage = image
                isLoading = false
            }
        }
    }
}

/// Small stat badge for survey mode
struct StatBadge: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(count)")
                .font(.caption.monospacedDigit())
                .foregroundColor(.white)
        }
    }
}

#Preview {
    SurveyModeView(appState: AppState())
}
