//
//  AILayer.swift
//  rawctl
//
//  AI layer data structure for layer-based AI image generation
//

import Foundation
import SwiftUI

// MARK: - AI Layer Type

/// Types of AI layer generation operations
enum AILayerType: String, Codable, CaseIterable, Identifiable {
    case inpaint    // Region-based inpainting/removal
    case outpaint   // Extend image boundaries
    case transform  // Scene transformation
    case style      // Style transfer
    case enhance    // Quality enhancement

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .inpaint: return "Inpaint"
        case .outpaint: return "Outpaint"
        case .transform: return "Scene"
        case .style: return "Style"
        case .enhance: return "Enhance"
        }
    }

    var icon: String {
        switch self {
        case .inpaint: return "paintbrush.pointed"
        case .outpaint: return "rectangle.expand.vertical"
        case .transform: return "photo.on.rectangle"
        case .style: return "paintpalette"
        case .enhance: return "sparkles"
        }
    }

    var description: String {
        switch self {
        case .inpaint: return "Edit or remove selected areas"
        case .outpaint: return "Extend image beyond boundaries"
        case .transform: return "Transform scene or content"
        case .style: return "Apply artistic style"
        case .enhance: return "Improve image quality"
        }
    }
}

// MARK: - AI Resolution

/// Resolution options for AI generation
enum AIResolution: String, Codable, CaseIterable, Identifiable {
    case standard = "1K"   // 1024px - 1 credit
    case high = "2K"       // 2048px - 3 credits
    case ultra = "4K"      // 4096px - 6 credits

    var id: String { rawValue }

    var credits: Int {
        switch self {
        case .standard: return 1
        case .high: return 3
        case .ultra: return 6
        }
    }

    var displayName: String {
        switch self {
        case .standard: return "1K (1 credit)"
        case .high: return "2K (3 credits)"
        case .ultra: return "4K (6 credits)"
        }
    }

    var maxPixels: Int {
        switch self {
        case .standard: return 1024
        case .high: return 2048
        case .ultra: return 4096
        }
    }
}

// MARK: - AI Generation Mode

/// Mode of AI generation (region-based or full image)
enum AIGenerationMode: String, Codable, CaseIterable, Identifiable {
    case region     // Brush mask selection
    case fullImage  // Entire image transformation

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .region: return "Region"
        case .fullImage: return "Full Image"
        }
    }
}

// MARK: - AI Layer

/// A single AI-generated layer that can be composited with the original image
struct AILayer: Identifiable, Codable, Equatable {
    let id: UUID
    let type: AILayerType
    let prompt: String
    let originalPrompt: String      // Pre-enhancement prompt
    let maskData: Data?             // Brush mask for region generation
    let generatedImagePath: String  // Path to cached result image
    let preserveStrength: Double    // 0-100% original preservation
    let resolution: AIResolution
    let creditsUsed: Int
    let createdAt: Date
    let parentLayerId: UUID?        // For version tracking

    // Compositing properties
    var isVisible: Bool
    var opacity: Double
    var blendMode: AIBlendMode

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        type: AILayerType,
        prompt: String,
        originalPrompt: String,
        maskData: Data? = nil,
        generatedImagePath: String,
        preserveStrength: Double = 70,
        resolution: AIResolution = .standard,
        creditsUsed: Int,
        createdAt: Date = Date(),
        parentLayerId: UUID? = nil,
        isVisible: Bool = true,
        opacity: Double = 1.0,
        blendMode: AIBlendMode = .normal
    ) {
        self.id = id
        self.type = type
        self.prompt = prompt
        self.originalPrompt = originalPrompt
        self.maskData = maskData
        self.generatedImagePath = generatedImagePath
        self.preserveStrength = preserveStrength
        self.resolution = resolution
        self.creditsUsed = creditsUsed
        self.createdAt = createdAt
        self.parentLayerId = parentLayerId
        self.isVisible = isVisible
        self.opacity = opacity
        self.blendMode = blendMode
    }

    // MARK: - Display

    /// Human-readable summary
    var summary: String {
        let truncatedPrompt = prompt.prefix(25)
        return prompt.count > 25 ? "\(truncatedPrompt)..." : String(truncatedPrompt)
    }

    /// Formatted creation date
    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    /// Metadata string
    var metadata: String {
        "\(resolution.rawValue) • \(creditsUsed) credit\(creditsUsed == 1 ? "" : "s") • \(formattedDate)"
    }

    // MARK: - Equatable

    static func == (lhs: AILayer, rhs: AILayer) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - AI Blend Mode

/// Blend modes for AI layer compositing
enum AIBlendMode: String, Codable, CaseIterable, Identifiable {
    case normal
    case multiply
    case screen
    case overlay
    case softLight
    case hardLight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .multiply: return "Multiply"
        case .screen: return "Screen"
        case .overlay: return "Overlay"
        case .softLight: return "Soft Light"
        case .hardLight: return "Hard Light"
        }
    }
}

// MARK: - AI Layer Stack

/// Collection of AI layers for an image with compositing
class AILayerStack: ObservableObject {
    @Published var layers: [AILayer] = []
    @Published var selectedLayerId: UUID?

    /// Document ID this stack belongs to
    let documentId: UUID

    init(documentId: UUID, layers: [AILayer] = []) {
        self.documentId = documentId
        self.layers = layers
    }

    // MARK: - Layer Management

    /// Add a new layer (inserted at top)
    func addLayer(_ layer: AILayer) {
        layers.insert(layer, at: 0)
        selectedLayerId = layer.id
    }

    /// Remove a layer by ID
    func removeLayer(id: UUID) {
        layers.removeAll { $0.id == id }
        if selectedLayerId == id {
            selectedLayerId = layers.first?.id
        }
    }

    /// Toggle layer visibility
    func toggleVisibility(id: UUID) {
        if let index = layers.firstIndex(where: { $0.id == id }) {
            layers[index].isVisible.toggle()
        }
    }

    /// Update layer opacity
    func setOpacity(id: UUID, opacity: Double) {
        if let index = layers.firstIndex(where: { $0.id == id }) {
            layers[index].opacity = max(0, min(1, opacity))
        }
    }

    /// Update layer blend mode
    func setBlendMode(id: UUID, blendMode: AIBlendMode) {
        if let index = layers.firstIndex(where: { $0.id == id }) {
            layers[index].blendMode = blendMode
        }
    }

    /// Reorder layers (using IndexSet)
    func move(from source: IndexSet, to destination: Int) {
        layers.move(fromOffsets: source, toOffset: destination)
    }

    /// Move a layer from one position to another (for drag-and-drop by UUID)
    func moveLayer(from sourceId: UUID, to targetId: UUID) {
        guard let sourceIndex = layers.firstIndex(where: { $0.id == sourceId }),
              let targetIndex = layers.firstIndex(where: { $0.id == targetId }),
              sourceIndex != targetIndex else { return }

        let layer = layers.remove(at: sourceIndex)
        let newIndex = sourceIndex < targetIndex ? targetIndex : targetIndex
        layers.insert(layer, at: newIndex)
    }

    /// Get selected layer
    var selectedLayer: AILayer? {
        guard let id = selectedLayerId else { return nil }
        return layers.first { $0.id == id }
    }

    /// Get all visible layers in order (bottom to top for compositing)
    var visibleLayers: [AILayer] {
        layers.reversed().filter { $0.isVisible }
    }

    /// Total credits used
    var totalCreditsUsed: Int {
        layers.reduce(0) { $0 + $1.creditsUsed }
    }
}

// MARK: - AI Generation Request

/// Configuration for creating a new AI layer
struct AIGenerationRequest {
    var mode: AIGenerationMode = .fullImage
    var type: AILayerType = .transform
    var prompt: String = ""
    var enhancedPrompt: String?
    var mask: BrushMask?
    var preserveStrength: Double = 70
    var resolution: AIResolution = .standard

    /// Get the prompt to use (enhanced if available)
    var effectivePrompt: String {
        enhancedPrompt ?? prompt
    }

    /// Estimated credits cost
    var estimatedCredits: Int {
        resolution.credits
    }

    /// Validate configuration
    func validate() -> Result<Void, AIGenerationError> {
        guard !prompt.isEmpty else {
            return .failure(.promptRequired)
        }

        if mode == .region {
            guard let mask = mask, !mask.isEmpty else {
                return .failure(.maskRequired)
            }
        }

        return .success(())
    }
}

// MARK: - Errors

enum AIGenerationError: LocalizedError {
    case promptRequired
    case maskRequired
    case insufficientCredits
    case authenticationRequired
    case networkError
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .promptRequired:
            return "Please enter a prompt."
        case .maskRequired:
            return "Please paint the area you want to edit."
        case .insufficientCredits:
            return "Not enough credits. Please purchase more."
        case .authenticationRequired:
            return "Please sign in to continue."
        case .networkError:
            return "Network error. Please check your connection."
        case .generationFailed(let message):
            return "Generation failed: \(message)"
        }
    }
}

// MARK: - AI Layer History

/// Layer edit history for an image with undo/redo support
struct AILayerHistory: Identifiable, Codable {
    let id: UUID
    let assetFingerprint: String
    var snapshots: [AILayerHistorySnapshot]
    var currentIndex: Int
    let createdAt: Date
    var lastModified: Date

    init(
        id: UUID = UUID(),
        assetFingerprint: String,
        snapshots: [AILayerHistorySnapshot] = [],
        currentIndex: Int = -1,
        createdAt: Date = Date(),
        lastModified: Date = Date()
    ) {
        self.id = id
        self.assetFingerprint = assetFingerprint
        self.snapshots = snapshots
        self.currentIndex = currentIndex
        self.createdAt = createdAt
        self.lastModified = lastModified
    }

    // MARK: - History Navigation

    /// Can undo to previous state
    var canUndo: Bool {
        currentIndex > 0
    }

    /// Can redo to next state
    var canRedo: Bool {
        currentIndex < snapshots.count - 1
    }

    /// Current snapshot
    var currentSnapshot: AILayerHistorySnapshot? {
        guard currentIndex >= 0 && currentIndex < snapshots.count else { return nil }
        return snapshots[currentIndex]
    }

    /// Undo to previous state
    mutating func undo() -> AILayerHistorySnapshot? {
        guard canUndo else { return nil }
        currentIndex -= 1
        lastModified = Date()
        return snapshots[currentIndex]
    }

    /// Redo to next state
    mutating func redo() -> AILayerHistorySnapshot? {
        guard canRedo else { return nil }
        currentIndex += 1
        lastModified = Date()
        return snapshots[currentIndex]
    }

    /// Add new snapshot (removes any redo history)
    mutating func addSnapshot(_ snapshot: AILayerHistorySnapshot) {
        // Remove any snapshots after current index (discard redo history)
        if currentIndex < snapshots.count - 1 {
            snapshots = Array(snapshots.prefix(currentIndex + 1))
        }

        snapshots.append(snapshot)
        currentIndex = snapshots.count - 1
        lastModified = Date()
    }

    /// Go to specific snapshot index
    mutating func goTo(index: Int) -> AILayerHistorySnapshot? {
        guard index >= 0 && index < snapshots.count else { return nil }
        currentIndex = index
        lastModified = Date()
        return snapshots[index]
    }

    /// Total history count
    var count: Int {
        snapshots.count
    }

    /// Clear all history
    mutating func clear() {
        snapshots.removeAll()
        currentIndex = -1
        lastModified = Date()
    }
}

/// A single snapshot in layer edit history
struct AILayerHistorySnapshot: Identifiable, Codable {
    let id: UUID
    let layerId: UUID
    let action: AILayerHistoryAction
    let layerData: AILayer
    let timestamp: Date

    init(
        id: UUID = UUID(),
        layerId: UUID,
        action: AILayerHistoryAction,
        layerData: AILayer,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.layerId = layerId
        self.action = action
        self.layerData = layerData
        self.timestamp = timestamp
    }

    /// Display description
    var description: String {
        switch action {
        case .created:
            return "Created \(layerData.type.displayName)"
        case .modified:
            return "Modified \(layerData.type.displayName)"
        case .deleted:
            return "Deleted \(layerData.type.displayName)"
        case .visibilityChanged:
            return layerData.isVisible ? "Show layer" : "Hide layer"
        case .opacityChanged:
            return "Opacity: \(Int(layerData.opacity * 100))%"
        case .blendModeChanged:
            return "Blend: \(layerData.blendMode.displayName)"
        case .reordered:
            return "Reordered layers"
        }
    }

    /// Icon for the action
    var icon: String {
        switch action {
        case .created: return "plus.circle"
        case .modified: return "pencil.circle"
        case .deleted: return "trash.circle"
        case .visibilityChanged: return layerData.isVisible ? "eye" : "eye.slash"
        case .opacityChanged: return "slider.horizontal.3"
        case .blendModeChanged: return "square.stack"
        case .reordered: return "arrow.up.arrow.down"
        }
    }
}

/// Types of layer history actions
enum AILayerHistoryAction: String, Codable {
    case created
    case modified
    case deleted
    case visibilityChanged
    case opacityChanged
    case blendModeChanged
    case reordered
}

// MARK: - AI Layer History Manager

/// Manager for persisting AI layer edit history across sessions
class AILayerHistoryManager {
    static let shared = AILayerHistoryManager()

    private let fileManager = FileManager.default
    private var historyCache: [String: AILayerHistory] = [:]

    private init() {}

    /// Base directory for history storage
    private var historyBaseURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("rawctl/layer_history", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Get history file path for an asset
    private func historyPath(for assetFingerprint: String) -> URL {
        historyBaseURL.appendingPathComponent("\(assetFingerprint).json")
    }

    // MARK: - Load/Save

    /// Load history for an asset
    func loadHistory(for assetFingerprint: String) -> AILayerHistory {
        // Check cache first
        if let cached = historyCache[assetFingerprint] {
            return cached
        }

        // Load from disk
        let path = historyPath(for: assetFingerprint)
        if fileManager.fileExists(atPath: path.path),
           let data = try? Data(contentsOf: path),
           let history = try? JSONDecoder().decode(AILayerHistory.self, from: data) {
            historyCache[assetFingerprint] = history
            return history
        }

        // Create new history
        let newHistory = AILayerHistory(assetFingerprint: assetFingerprint)
        historyCache[assetFingerprint] = newHistory
        return newHistory
    }

    /// Save history for an asset
    func saveHistory(_ history: AILayerHistory) {
        historyCache[history.assetFingerprint] = history

        let path = historyPath(for: history.assetFingerprint)
        if let data = try? JSONEncoder().encode(history) {
            try? data.write(to: path)
        }
    }

    /// Record a layer creation
    func recordLayerCreated(assetFingerprint: String, layer: AILayer) {
        var history = loadHistory(for: assetFingerprint)
        let snapshot = AILayerHistorySnapshot(
            layerId: layer.id,
            action: .created,
            layerData: layer
        )
        history.addSnapshot(snapshot)
        saveHistory(history)
    }

    /// Record a layer deletion
    func recordLayerDeleted(assetFingerprint: String, layer: AILayer) {
        var history = loadHistory(for: assetFingerprint)
        let snapshot = AILayerHistorySnapshot(
            layerId: layer.id,
            action: .deleted,
            layerData: layer
        )
        history.addSnapshot(snapshot)
        saveHistory(history)
    }

    /// Record a layer modification
    func recordLayerModified(assetFingerprint: String, layer: AILayer, action: AILayerHistoryAction) {
        var history = loadHistory(for: assetFingerprint)
        let snapshot = AILayerHistorySnapshot(
            layerId: layer.id,
            action: action,
            layerData: layer
        )
        history.addSnapshot(snapshot)
        saveHistory(history)
    }

    /// Delete history for an asset
    func deleteHistory(for assetFingerprint: String) {
        historyCache.removeValue(forKey: assetFingerprint)
        let path = historyPath(for: assetFingerprint)
        try? fileManager.removeItem(at: path)
    }

    /// Clear all history (use with caution)
    func clearAllHistory() {
        historyCache.removeAll()
        try? fileManager.removeItem(at: historyBaseURL)
        try? fileManager.createDirectory(at: historyBaseURL, withIntermediateDirectories: true)
    }

    /// Get total history storage size
    func getTotalStorageSize() -> Int64 {
        var totalSize: Int64 = 0

        guard let enumerator = fileManager.enumerator(
            at: historyBaseURL,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(size)
            }
        }

        return totalSize
    }
}

// MARK: - Preview

#if DEBUG
extension AILayer {
    static var sample: AILayer {
        AILayer(
            type: .transform,
            prompt: "Transform to sunset beach scene with golden sand",
            originalPrompt: "Make it a beach",
            generatedImagePath: "sample_result.png",
            preserveStrength: 70,
            resolution: .high,
            creditsUsed: 3
        )
    }

    static var samples: [AILayer] {
        [
            AILayer(
                type: .style,
                prompt: "Watercolor painting style",
                originalPrompt: "Watercolor style",
                generatedImagePath: "style_result.png",
                resolution: .high,
                creditsUsed: 3
            ),
            AILayer(
                type: .transform,
                prompt: "Transform to sunset beach scene",
                originalPrompt: "Beach scene",
                generatedImagePath: "scene_result.png",
                resolution: .standard,
                creditsUsed: 1
            ),
            AILayer(
                type: .inpaint,
                prompt: "Remove the person in the background",
                originalPrompt: "Remove person",
                maskData: Data(),
                generatedImagePath: "inpaint_result.png",
                resolution: .standard,
                creditsUsed: 1
            ),
        ]
    }
}

extension AILayerStack {
    static var sample: AILayerStack {
        let stack = AILayerStack(documentId: UUID(), layers: AILayer.samples)
        return stack
    }
}
#endif
