//
//  AIGenerationPanel.swift
//  rawctl
//
//  AI image generation panel for Inspector sidebar
//

import SwiftUI

/// AI Generation panel for the Inspector sidebar
struct AIGenerationPanel: View {
    @ObservedObject var appState: AppState
    @StateObject private var generationService = AIGenerationService.shared
    @ObservedObject var accountService = AccountService.shared

    // Generation configuration
    @State private var mode: AIGenerationMode = .fullImage
    @State private var selectedType: AILayerType = .transform
    @State private var prompt: String = ""
    @State private var enhancedPrompt: String?
    @State private var preserveStrength: Double = 70
    @State private var resolution: AIResolution = .standard

    // UI state
    @State private var isEnhancing = false
    @State private var isGenerating = false
    @State private var showEnhancedPrompt = false
    @State private var currentError: AIGenerationError?
    @State private var showErrorSheet = false
    @State private var lastFailedRequest: AIGenerationRequest?

    var body: some View {
        VStack(spacing: 12) {
            // Mode Selector
            modeSelector

            Divider()

            // Type Selector
            typeSelector

            // Mask Section (only for region mode)
            if mode == .region {
                Divider()
                maskSection
            }

            Divider()

            // Prompt Input
            promptSection

            Divider()

            // Preserve Strength
            ControlSlider(
                label: "Preserve Original",
                value: $preserveStrength,
                range: 0...100,
                format: "%.0f%%",
                showSign: false,
                defaultValue: 70
            )

            Divider()

            // Resolution Picker
            resolutionPicker

            Divider()

            // Generate Button
            generateButton

            // Credits Display
            creditsDisplay

            // Error Display (inline)
            if let error = currentError {
                errorView(for: error)
            }
        }
        .padding(.top, 6)
        .sheet(isPresented: $showErrorSheet) {
            if let error = currentError {
                ErrorDetailSheet(
                    error: error,
                    onRetry: {
                        showErrorSheet = false
                        currentError = nil
                        Task { await retryGeneration() }
                    },
                    onDismiss: {
                        showErrorSheet = false
                        currentError = nil
                        lastFailedRequest = nil
                    },
                    onBuyCredits: {
                        showErrorSheet = false
                        currentError = nil
                        // Navigate to credits purchase
                        appState.showAccountSheet = true
                    }
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .aiLayerReEdit)) { notification in
            if let promptText = notification.userInfo?["prompt"] as? String {
                self.prompt = promptText
                self.enhancedPrompt = nil
                self.showEnhancedPrompt = false
            }
            if let type = notification.userInfo?["type"] as? AILayerType {
                self.selectedType = type
                // Switch to appropriate mode based on type
                if type == .inpaint || type == .outpaint {
                    self.mode = .region
                } else {
                    self.mode = .fullImage
                }
            }
        }
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        HStack(spacing: 8) {
            Text("Mode")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Spacer()

            Picker("", selection: $mode) {
                ForEach(AIGenerationMode.allCases) { m in
                    Text(m.displayName).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .frame(width: 160)
        }
    }

    // MARK: - Type Selector

    private var typeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Type")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            HStack(spacing: 6) {
                ForEach(availableTypes, id: \.self) { type in
                    TypeButton(
                        type: type,
                        isSelected: selectedType == type,
                        action: { selectedType = type }
                    )
                }
            }
        }
    }

    /// Available types based on current mode
    private var availableTypes: [AILayerType] {
        switch mode {
        case .region:
            return [.inpaint, .outpaint]
        case .fullImage:
            return [.transform, .style, .enhance]
        }
    }

    // MARK: - Mask Section

    private var maskSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Mask")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                // Stroke count
                if !appState.currentBrushMask.isEmpty {
                    Text("\(appState.currentBrushMask.strokes.count) strokes")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 8) {
                // Paint/Edit Mask button
                Button {
                    appState.maskPaintingMode.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: appState.maskPaintingMode ? "checkmark.circle.fill" : "paintbrush.pointed.fill")
                            .font(.system(size: 10))
                        Text(appState.maskPaintingMode ? "Done Painting" : "Paint Mask")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .tint(appState.maskPaintingMode ? .green : .accentColor)

                // Clear mask button
                Button {
                    appState.currentBrushMask.clear()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                }
                .buttonStyle(.bordered)
                .disabled(appState.currentBrushMask.isEmpty)
                .help("Clear mask")
            }

            // Mask status indicator
            if appState.currentBrushMask.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.orange)
                    Text("Paint on the image to select the area to edit")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.green)
                    Text("Mask ready")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Prompt Section

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Prompt")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                // Enhance button
                Button {
                    Task { await enhancePrompt() }
                } label: {
                    HStack(spacing: 4) {
                        if isEnhancing {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text("Enhance")
                    }
                    .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(prompt.isEmpty || isEnhancing)
                .help("Enhance prompt for better results (Free)")
            }

            // Prompt input
            TextEditor(text: $prompt)
                .font(.system(size: 12))
                .frame(height: 60)
                .padding(6)
                .background(Color(white: 0.15))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .onChange(of: prompt) { _, _ in
                    // Clear enhanced prompt when user edits
                    if showEnhancedPrompt {
                        showEnhancedPrompt = false
                        enhancedPrompt = nil
                    }
                }

            // Enhanced prompt preview
            if showEnhancedPrompt, let enhanced = enhancedPrompt {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.yellow)
                        Text("Enhanced")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.yellow)

                        Spacer()

                        Button("Use Original") {
                            showEnhancedPrompt = false
                            enhancedPrompt = nil
                        }
                        .font(.system(size: 9))
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }

                    Text(enhanced)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(4)
                        .padding(8)
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(6)
                }
            }
        }
    }

    // MARK: - Resolution Picker

    private var resolutionPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Resolution")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            ForEach(AIResolution.allCases) { res in
                HStack {
                    Image(systemName: resolution == res ? "circle.inset.filled" : "circle")
                        .font(.system(size: 12))
                        .foregroundColor(resolution == res ? .accentColor : .secondary)

                    Text(res.displayName)
                        .font(.system(size: 11))

                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    resolution = res
                }
            }
        }
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button {
            Task { await generate() }
        } label: {
            HStack {
                if isGenerating {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "wand.and.stars")
                }

                Text("Generate")

                Text("(\(resolution.credits) ⭐)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .font(.system(size: 13, weight: .medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!canGenerate)
    }

    private var canGenerate: Bool {
        // Must be logged in to use AI features
        guard accountService.isAuthenticated else { return false }
        guard !prompt.isEmpty else { return false }
        guard !isGenerating else { return false }
        guard let balance = accountService.creditsBalance else { return false }
        guard balance.totalRemaining >= resolution.credits else { return false }

        // Region mode requires a mask
        if mode == .region {
            guard !appState.currentBrushMask.isEmpty else { return false }
        }

        return true
    }

    // MARK: - Credits Display

    private var creditsDisplay: some View {
        VStack(spacing: 6) {
            // Sign in required message
            if !accountService.isAuthenticated {
                signInRequiredView
            } else {
                HStack {
                    Text("Credits:")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    if let balance = accountService.creditsBalance {
                        Text("\(balance.totalRemaining) remaining")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(balance.totalRemaining >= resolution.credits ? .primary : .red)
                    } else {
                        Text("Loading...")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                // Insufficient credits warning
                if let balance = accountService.creditsBalance,
                   balance.totalRemaining < resolution.credits {
                    insufficientCreditsWarning(needed: resolution.credits, available: balance.totalRemaining)
                } else if let balance = accountService.creditsBalance,
                          balance.totalRemaining <= 5 {
                    // Low credits warning (5 or less)
                    lowCreditsWarning(remaining: balance.totalRemaining)
                }
            }
        }
    }

    private var signInRequiredView: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 14))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Sign in required")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.orange)
                Text("Sign in to use AI generation features")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                appState.showAccountSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 9))
                    Text("Sign In")
                }
                .font(.system(size: 10, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private func insufficientCreditsWarning(needed: Int, available: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Not enough credits")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.orange)
                Text("Need \(needed), have \(available)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                appState.showAccountSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                    Text("Get Credits")
                }
                .font(.system(size: 10, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private func lowCreditsWarning(remaining: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 10))
                .foregroundColor(.yellow)

            Text("Low credits: \(remaining) remaining")
                .font(.system(size: 10))
                .foregroundColor(.yellow)

            Spacer()

            Button("Top Up") {
                appState.showAccountSheet = true
            }
            .font(.system(size: 10))
            .buttonStyle(.plain)
            .foregroundColor(.blue)
        }
        .padding(6)
        .background(Color.yellow.opacity(0.05))
        .cornerRadius(6)
    }

    // MARK: - Actions

    private func enhancePrompt() async {
        guard !prompt.isEmpty else { return }

        isEnhancing = true
        defer { isEnhancing = false }

        do {
            let enhanced = try await generationService.enhancePrompt(prompt)
            await MainActor.run {
                self.enhancedPrompt = enhanced
                self.showEnhancedPrompt = true
            }
        } catch let error as AIGenerationError {
            await MainActor.run {
                self.currentError = error
            }
        } catch {
            await MainActor.run {
                self.currentError = .generationFailed(error.localizedDescription)
            }
        }
    }

    private func generate() async {
        // Verify authentication before generation
        guard accountService.isAuthenticated else {
            currentError = .authenticationRequired
            return
        }

        guard let asset = appState.selectedAsset else {
            currentError = .generationFailed("No photo selected")
            return
        }

        isGenerating = true
        defer { isGenerating = false }

        // Build request
        var request = AIGenerationRequest()
        request.mode = mode
        request.type = selectedType
        request.prompt = prompt
        request.enhancedPrompt = showEnhancedPrompt ? enhancedPrompt : nil
        request.preserveStrength = preserveStrength
        request.resolution = resolution

        // Include mask for region mode
        if mode == .region {
            request.mask = appState.currentBrushMask
        }

        do {
            let layer = try await generationService.generateLayer(
                for: asset,
                request: request
            )

            await MainActor.run {
                // Add layer to asset's layer stack
                let layerStack = appState.aiLayerStack(for: asset.id)
                layerStack.addLayer(layer)

                // Record history for layer creation
                AILayerHistoryManager.shared.recordLayerCreated(
                    assetFingerprint: asset.fingerprint,
                    layer: layer
                )

                appState.showHUD("AI layer generated")

                // Clear prompt for next generation
                prompt = ""
                enhancedPrompt = nil
                showEnhancedPrompt = false

                // Clear mask and exit painting mode
                if mode == .region {
                    appState.exitMaskPaintingMode()
                }
            }
        } catch let error as AIGenerationError {
            await MainActor.run {
                self.currentError = error
                self.lastFailedRequest = request
            }
        } catch {
            await MainActor.run {
                self.currentError = .generationFailed(error.localizedDescription)
                self.lastFailedRequest = request
            }
        }
    }

    private func retryGeneration() async {
        // Verify authentication before retry
        guard accountService.isAuthenticated else {
            currentError = .authenticationRequired
            return
        }

        guard let asset = appState.selectedAsset,
              let request = lastFailedRequest else { return }

        isGenerating = true
        defer { isGenerating = false }

        do {
            let layer = try await generationService.generateLayer(
                for: asset,
                request: request
            )

            await MainActor.run {
                let layerStack = appState.aiLayerStack(for: asset.id)
                layerStack.addLayer(layer)

                // Record history for layer creation
                AILayerHistoryManager.shared.recordLayerCreated(
                    assetFingerprint: asset.fingerprint,
                    layer: layer
                )

                appState.showHUD("AI layer generated")
                prompt = ""
                enhancedPrompt = nil
                showEnhancedPrompt = false
                lastFailedRequest = nil
                if request.mode == .region {
                    appState.exitMaskPaintingMode()
                }
            }
        } catch let error as AIGenerationError {
            await MainActor.run {
                self.currentError = error
            }
        } catch {
            await MainActor.run {
                self.currentError = .generationFailed(error.localizedDescription)
            }
        }
    }

    // MARK: - Error View

    @ViewBuilder
    private func errorView(for error: AIGenerationError) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: error.icon)
                    .font(.system(size: 12))
                    .foregroundColor(error.iconColor)

                Text(error.shortMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()

                Button {
                    currentError = nil
                    lastFailedRequest = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                if error.isRetryable, lastFailedRequest != nil {
                    Button {
                        currentError = nil
                        Task { await retryGeneration() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry")
                        }
                        .font(.system(size: 10, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if case .insufficientCredits = error {
                    Button {
                        appState.showAccountSheet = true
                        currentError = nil
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                            Text("Get Credits")
                        }
                        .font(.system(size: 10, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                Button("Details") {
                    showErrorSheet = true
                }
                .font(.system(size: 10))
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(error.backgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(error.borderColor, lineWidth: 1)
        )
    }
}

// MARK: - Error Detail Sheet

private struct ErrorDetailSheet: View {
    let error: AIGenerationError
    let onRetry: () -> Void
    let onDismiss: () -> Void
    let onBuyCredits: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: error.icon)
                    .font(.system(size: 24))
                    .foregroundColor(error.iconColor)

                Text("Generation Failed")
                    .font(.headline)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Error details
            VStack(alignment: .leading, spacing: 8) {
                Text("What happened:")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                Text(error.detailedMessage)
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)

                if !error.suggestion.isEmpty {
                    Text("Suggestion:")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.top, 8)

                    Text(error.suggestion)
                        .font(.system(size: 13))
                        .foregroundColor(.blue)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            // Actions
            HStack(spacing: 12) {
                Button("Dismiss", action: onDismiss)
                    .buttonStyle(.bordered)

                if case .insufficientCredits = error {
                    Button("Buy Credits", action: onBuyCredits)
                        .buttonStyle(.borderedProminent)
                } else if error.isRetryable {
                    Button("Retry", action: onRetry)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(20)
        .frame(width: 360, height: 280)
    }
}

// MARK: - AIGenerationError UI Extensions

extension AIGenerationError {
    var icon: String {
        switch self {
        case .promptRequired: return "text.cursor"
        case .maskRequired: return "paintbrush.pointed"
        case .insufficientCredits: return "star.slash"
        case .authenticationRequired: return "person.crop.circle.badge.exclamationmark"
        case .networkError: return "wifi.slash"
        case .generationFailed: return "exclamationmark.triangle"
        }
    }

    var iconColor: Color {
        switch self {
        case .insufficientCredits: return .orange
        case .authenticationRequired: return .red
        case .networkError: return .yellow
        default: return .red
        }
    }

    var shortMessage: String {
        switch self {
        case .promptRequired: return "Prompt required"
        case .maskRequired: return "Mask required"
        case .insufficientCredits: return "Not enough credits"
        case .authenticationRequired: return "Sign in required"
        case .networkError: return "Connection failed"
        case .generationFailed: return "Generation failed"
        }
    }

    var detailedMessage: String {
        switch self {
        case .promptRequired:
            return "Please enter a prompt describing what you want to generate."
        case .maskRequired:
            return "Region-based editing requires a painted mask. Use the brush tool to select the area you want to modify."
        case .insufficientCredits:
            return "You don't have enough credits for this generation. Higher resolutions require more credits."
        case .authenticationRequired:
            return "You need to sign in to your account to use AI generation features."
        case .networkError:
            return "Unable to connect to the AI service. Please check your internet connection and try again."
        case .generationFailed(let message):
            return "The AI service encountered an error: \(message)"
        }
    }

    var suggestion: String {
        switch self {
        case .promptRequired: return "Try describing the scene, style, or changes you want."
        case .maskRequired: return "Click 'Paint Mask' and brush over the area to edit."
        case .insufficientCredits: return "Purchase more credits or try a lower resolution."
        case .authenticationRequired: return "Go to Account to sign in."
        case .networkError: return "Wait a moment and try again."
        case .generationFailed: return "Try simplifying your prompt or using a different type."
        }
    }

    var backgroundColor: Color {
        switch self {
        case .insufficientCredits: return Color.orange.opacity(0.1)
        case .authenticationRequired: return Color.red.opacity(0.1)
        case .networkError: return Color.yellow.opacity(0.1)
        default: return Color.red.opacity(0.1)
        }
    }

    var borderColor: Color {
        switch self {
        case .insufficientCredits: return Color.orange.opacity(0.3)
        case .authenticationRequired: return Color.red.opacity(0.3)
        case .networkError: return Color.yellow.opacity(0.3)
        default: return Color.red.opacity(0.3)
        }
    }

    var isRetryable: Bool {
        switch self {
        case .networkError, .generationFailed: return true
        default: return false
        }
    }
}

// MARK: - Type Button

private struct TypeButton: View {
    let type: AILayerType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.system(size: 14))

                Text(type.displayName)
                    .font(.system(size: 9))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? .accentColor : .secondary)
    }
}

// MARK: - Preview

#Preview {
    DisclosureGroup("AI Generation") {
        AIGenerationPanel(appState: AppState())
    }
    .padding()
    .frame(width: 300)
    .preferredColorScheme(.dark)
}
