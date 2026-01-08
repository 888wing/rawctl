//
//  NanoBananaEditorView.swift
//  rawctl
//
//  Full-screen AI editing interface with mask canvas and history
//

import SwiftUI

/// Full-screen AI editing view
struct NanoBananaEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState
    let asset: PhotoAsset
    
    // State
    @State private var selectedOperation: AIOperation = .inpaint
    @State private var previewImage: NSImage?
    @State private var isLoadingPreview = true
    
    // Mask state
    @StateObject private var mask = BrushMask()
    
    // Inpaint options
    @State private var inpaintPrompt = ""
    @State private var isRemoveMode = true  // true = remove object, false = custom prompt
    
    // Style transfer options
    @State private var referenceImage: NSImage?
    @State private var referenceURL: URL?
    @State private var styleStrength: Double = 0.7
    
    // Restore options
    @State private var selectedRestoreType: RestoreType = .enhance
    
    // Resolution
    @State private var resolution: AIEditResolution = .standard
    
    // Processing state
    @StateObject private var nanoBananaService = NanoBananaService.shared
    @State private var showProgress = false
    @State private var errorMessage: String?
    
    // AI Edit history for this asset
    @State private var aiEdits: [AIEdit] = []
    
    var body: some View {
        HSplitView {
            // Left sidebar - Tools
            toolsSidebar
                .frame(minWidth: 260, maxWidth: 300)
            
            // Center - Canvas
            VStack(spacing: 0) {
                // Top toolbar
                editorToolbar
                
                // Canvas area
                ZStack {
                    if isLoadingPreview {
                        ProgressView("Loading preview...")
                    } else {
                        canvasView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Right sidebar - History
            historySidebar
                .frame(minWidth: 200, maxWidth: 260)
        }
        .frame(minWidth: 1000, minHeight: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay {
            if showProgress {
                NanoBananaProgressView(
                    service: nanoBananaService,
                    onCancel: {
                        nanoBananaService.cancel()
                        showProgress = false
                    },
                    onDismiss: {
                        showProgress = false
                        nanoBananaService.state = .idle
                    }
                )
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            await loadPreview()
            loadAIEdits()
        }
    }
    
    // MARK: - Tools Sidebar
    
    private var toolsSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.yellow)
                    Text("AI Edit")
                        .font(.headline)
                    Spacer()
                    
                    // Credits badge
                    HStack(spacing: 4) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 9))
                        Text("\(AccountService.shared.creditsBalance?.totalRemaining ?? 0)")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(white: 0.15))
                    .cornerRadius(10)
                }
                .padding(.bottom, 8)
                
                Divider()
                
                // Operation selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Operation")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    ForEach(AIOperation.allCases) { op in
                        OperationButton(
                            operation: op,
                            isSelected: selectedOperation == op,
                            credits: op.credits(for: resolution)
                        ) {
                            withAnimation {
                                selectedOperation = op
                                if op != .inpaint {
                                    mask.clear()
                                }
                            }
                        }
                    }
                }
                
                Divider()
                
                // Operation-specific options
                operationOptions
                
                Divider()
                
                // Resolution picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Resolution")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $resolution) {
                        ForEach(AIEditResolution.allCases) { res in
                            Text(res.displayName).tag(res)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        startProcessing()
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Generate")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!canProcess)
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - Operation Options
    
    @ViewBuilder
    private var operationOptions: some View {
        switch selectedOperation {
        case .enhance:
            VStack(alignment: .leading, spacing: 8) {
                Text("Enhancement")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("AI will automatically enhance colors, lighting, and details.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
        case .inpaint:
            VStack(alignment: .leading, spacing: 12) {
                Text("Inpaint / Remove")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                // Mode toggle
                Picker("", selection: $isRemoveMode) {
                    Text("Remove Object").tag(true)
                    Text("Custom Prompt").tag(false)
                }
                .pickerStyle(.segmented)
                
                if !isRemoveMode {
                    TextField("Describe what to generate...", text: $inpaintPrompt, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...5)
                }
                
                // Brush instructions
                HStack(spacing: 8) {
                    Image(systemName: "paintbrush.pointed")
                        .foregroundColor(.accentColor)
                    Text("Paint over the area you want to edit")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(6)
            }
            
        case .style:
            VStack(alignment: .leading, spacing: 12) {
                Text("Style Transfer")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                // Reference image picker
                Button {
                    pickReferenceImage()
                } label: {
                    if let refImage = referenceImage {
                        Image(nsImage: refImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 100)
                            .clipped()
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.accentColor, lineWidth: 2)
                            )
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 24))
                            Text("Select Reference Image")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .background(Color(white: 0.15))
                        .cornerRadius(8)
                    }
                }
                .buttonStyle(.plain)
                
                // Strength slider
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Strength")
                            .font(.system(size: 11))
                        Spacer()
                        Text("\(Int(styleStrength * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $styleStrength, in: 0.1...1.0)
                }
            }
            
        case .restore:
            VStack(alignment: .leading, spacing: 12) {
                Text("Restoration Type")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                ForEach(RestoreType.allCases) { type in
                    RestoreTypeButton(
                        type: type,
                        isSelected: selectedRestoreType == type
                    ) {
                        selectedRestoreType = type
                    }
                }
            }
        }
    }
    
    // MARK: - Canvas View
    
    @ViewBuilder
    private var canvasView: some View {
        if selectedOperation == .inpaint {
            VStack(spacing: 0) {
                BrushToolbar(
                    mask: mask,
                    onClear: { mask.clear() },
                    onUndo: { mask.undo() }
                )
                
                MaskCanvasView(
                    mask: mask,
                    backgroundImage: previewImage,
                    imageSize: CGSize(width: asset.metadata?.width ?? 1000, height: asset.metadata?.height ?? 1000)
                )
            }
        } else {
            // Simple image preview for non-mask operations
            if let image = previewImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
            }
        }
    }
    
    // MARK: - Editor Toolbar
    
    private var editorToolbar: some View {
        HStack {
            Text(asset.filename)
                .font(.system(size: 13, weight: .medium))
            
            Spacer()
            
            // Zoom controls could go here
            
            Text("\(Int(asset.metadata?.width ?? 0)) × \(Int(asset.metadata?.height ?? 0))")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - History Sidebar
    
    private var historySidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("AI Edits")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(aiEdits.count)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(white: 0.2))
                    .cornerRadius(10)
            }
            .padding()
            
            Divider()
            
            // History list
            if aiEdits.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No AI edits yet")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(aiEdits.reversed()) { edit in
                            AIEditHistoryRow(
                                edit: edit,
                                onToggle: { toggleEdit(edit.id) },
                                onDelete: { deleteEdit(edit.id) }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - Helpers
    
    private var canProcess: Bool {
        switch selectedOperation {
        case .enhance:
            return true
        case .inpaint:
            return !mask.isEmpty
        case .style:
            return referenceURL != nil
        case .restore:
            return true
        }
    }
    
    private func loadPreview() async {
        isLoadingPreview = true
        previewImage = await ImagePipeline.shared.quickPreview(for: asset)
        isLoadingPreview = false
    }
    
    private func loadAIEdits() {
        // Load from sidecar
        Task {
            if let (_, _, edits) = await SidecarService.shared.loadRecipeAndAIEdits(for: asset.url) {
                await MainActor.run {
                    self.aiEdits = edits
                }
            }
        }
    }
    
    private func pickReferenceImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            referenceURL = url
            referenceImage = NSImage(contentsOf: url)
        }
    }
    
    private func startProcessing() {
        guard AccountService.shared.isAuthenticated else {
            errorMessage = "Please sign in to use AI features."
            return
        }
        
        let config = AIEditConfig(
            operation: selectedOperation,
            resolution: resolution,
            prompt: selectedOperation == .inpaint ? (isRemoveMode ? "Remove the selected object and fill with surrounding content" : inpaintPrompt) : nil,
            mask: selectedOperation == .inpaint ? mask : nil,
            referenceURL: selectedOperation == .style ? referenceURL : nil,
            restoreType: selectedOperation == .restore ? selectedRestoreType : nil,
            strength: selectedOperation == .style ? styleStrength : nil
        )
        
        if case .failure(let error) = config.validate() {
            errorMessage = error.localizedDescription
            return
        }
        
        showProgress = true
        
        Task {
            do {
                let edit = try await nanoBananaService.processAdvanced(
                    asset: asset,
                    config: config
                )
                
                await MainActor.run {
                    aiEdits.append(edit)
                    mask.clear()
                    appState.showHUD("AI edit complete!")
                }
            } catch {
                await MainActor.run {
                    if case NanoBananaError.cancelled = error {
                        // User cancelled
                    } else {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
    
    private func toggleEdit(_ editId: UUID) {
        if let index = aiEdits.firstIndex(where: { $0.id == editId }) {
            aiEdits[index].enabled.toggle()
            saveAIEdits()
        }
    }
    
    private func deleteEdit(_ editId: UUID) {
        aiEdits.removeAll { $0.id == editId }
        // Delete cache files
        Task {
            await CacheManager.shared.deleteAIEditCache(
                assetFingerprint: asset.fingerprint,
                editId: editId
            )
        }
        saveAIEdits()
    }
    
    private func saveAIEdits() {
        Task {
            await SidecarService.shared.saveAIEdits(aiEdits, for: asset.url)
        }
    }
}

// MARK: - Operation Button

private struct OperationButton: View {
    let operation: AIOperation
    let isSelected: Bool
    let credits: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: operation.icon)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(operation.displayName)
                        .font(.system(size: 12, weight: .medium))
                    Text(operation.description)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                HStack(spacing: 3) {
                    Text("\(credits)")
                        .font(.system(size: 11, weight: .medium))
                    Image(systemName: "sparkle")
                        .font(.system(size: 8))
                }
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color(white: 0.12))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Restore Type Button

private struct RestoreTypeButton: View {
    let type: RestoreType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: type.icon)
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                
                Text(type.displayName)
                    .font(.system(size: 12))
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AI Edit History Row

private struct AIEditHistoryRow: View {
    let edit: AIEdit
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            // Toggle
            Button(action: onToggle) {
                Image(systemName: edit.enabled ? "eye.fill" : "eye.slash")
                    .font(.system(size: 12))
                    .foregroundColor(edit.enabled ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: edit.operation.icon)
                        .font(.system(size: 10))
                    Text(edit.summary)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
                
                Text(edit.formattedDate)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Delete
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(0.6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(white: edit.enabled ? 0.15 : 0.1))
        .cornerRadius(6)
        .opacity(edit.enabled ? 1.0 : 0.6)
    }
}

// MARK: - Preview

#Preview {
    NanoBananaEditorView(
        appState: AppState(),
        asset: PhotoAsset(
            url: URL(fileURLWithPath: "/test.jpg")
        )
    )
    .preferredColorScheme(.dark)
}
