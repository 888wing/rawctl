//
//  AIEdit.swift
//  rawctl
//
//  AI editing operation record for non-destructive AI edits
//

import Foundation

// MARK: - AI Operation Types

/// Types of AI editing operations
enum AIOperation: String, Codable, CaseIterable, Identifiable {
    case enhance    // General enhancement
    case inpaint    // Mask-based inpainting/removal
    case style      // Style transfer with reference image
    case restore    // Restoration (denoise, deblur, colorize)
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .enhance: return "Enhance"
        case .inpaint: return "Inpaint"
        case .style: return "Style Transfer"
        case .restore: return "Restore"
        }
    }
    
    var icon: String {
        switch self {
        case .enhance: return "sparkles"
        case .inpaint: return "paintbrush.pointed"
        case .style: return "paintpalette"
        case .restore: return "wand.and.rays"
        }
    }
    
    var description: String {
        switch self {
        case .enhance: return "AI-powered image enhancement"
        case .inpaint: return "Edit or remove selected areas"
        case .style: return "Apply style from reference image"
        case .restore: return "Fix noise, blur, or colorize"
        }
    }
    
    /// Credits cost per resolution
    func credits(for resolution: AIEditResolution) -> Int {
        switch (self, resolution) {
        case (.enhance, .standard): return 1
        case (.enhance, .pro2k): return 3
        case (.enhance, .pro4k): return 6
        case (.inpaint, _): return 2  // Inpaint is fixed cost
        case (.style, _): return 3    // Style transfer fixed cost
        case (.restore, .standard): return 1
        case (.restore, .pro2k): return 2
        case (.restore, .pro4k): return 4
        }
    }
}

/// Resolution options for AI processing
enum AIEditResolution: String, Codable, CaseIterable, Identifiable {
    case standard = "1k"
    case pro2k = "2k"
    case pro4k = "4k"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .standard: return "Standard (1K)"
        case .pro2k: return "Pro (2K)"
        case .pro4k: return "Pro (4K)"
        }
    }
    
    var maxPixels: Int {
        switch self {
        case .standard: return 1024
        case .pro2k: return 2048
        case .pro4k: return 4096
        }
    }
}

/// Restore operation subtypes
enum RestoreType: String, Codable, CaseIterable, Identifiable {
    case denoise = "denoise"
    case deblur = "deblur"
    case colorize = "colorize"
    case enhance = "enhance"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .denoise: return "Denoise"
        case .deblur: return "Deblur"
        case .colorize: return "Colorize"
        case .enhance: return "Auto Enhance"
        }
    }
    
    var icon: String {
        switch self {
        case .denoise: return "sparkle"
        case .deblur: return "camera.metering.spot"
        case .colorize: return "paintpalette.fill"
        case .enhance: return "wand.and.stars"
        }
    }
}

// MARK: - AI Edit Record

/// A single AI editing operation record
struct AIEdit: Codable, Identifiable, Equatable {
    let id: UUID
    var operation: AIOperation
    var resolution: AIEditResolution
    
    // Operation-specific parameters
    var prompt: String?
    var maskPath: String?           // Relative path to mask cache
    var referencePath: String?      // Relative path to reference image cache
    var resultPath: String          // Relative path to result cache
    var restoreType: RestoreType?
    var strength: Double?           // For style transfer (0.0-1.0)
    
    // Metadata
    var createdAt: Date
    var enabled: Bool               // Can toggle visibility
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        operation: AIOperation,
        resolution: AIEditResolution = .standard,
        prompt: String? = nil,
        maskPath: String? = nil,
        referencePath: String? = nil,
        resultPath: String,
        restoreType: RestoreType? = nil,
        strength: Double? = nil,
        createdAt: Date = Date(),
        enabled: Bool = true
    ) {
        self.id = id
        self.operation = operation
        self.resolution = resolution
        self.prompt = prompt
        self.maskPath = maskPath
        self.referencePath = referencePath
        self.resultPath = resultPath
        self.restoreType = restoreType
        self.strength = strength
        self.createdAt = createdAt
        self.enabled = enabled
    }
    
    // MARK: - Display
    
    /// Human-readable summary of this edit
    var summary: String {
        switch operation {
        case .enhance:
            return "Enhanced (\(resolution.displayName))"
        case .inpaint:
            if let prompt = prompt, !prompt.isEmpty {
                return "Inpaint: \(prompt.prefix(30))..."
            }
            return "Object Removal"
        case .style:
            return "Style Transfer (\(Int((strength ?? 0.5) * 100))%)"
        case .restore:
            return restoreType?.displayName ?? "Restored"
        }
    }
    
    /// Formatted creation date
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}

// MARK: - AI Edit Configuration

/// Configuration for creating a new AI edit
struct AIEditConfig {
    var operation: AIOperation
    var resolution: AIEditResolution = .standard
    var prompt: String?
    var mask: BrushMask?
    var referenceURL: URL?
    var restoreType: RestoreType?
    var strength: Double?
    
    /// Validate configuration for the operation
    func validate() -> Result<Void, AIEditConfigError> {
        switch operation {
        case .enhance:
            return .success(())
            
        case .inpaint:
            guard mask != nil && !(mask?.strokes.isEmpty ?? true) else {
                return .failure(.maskRequired)
            }
            return .success(())
            
        case .style:
            guard referenceURL != nil else {
                return .failure(.referenceRequired)
            }
            return .success(())
            
        case .restore:
            guard restoreType != nil else {
                return .failure(.restoreTypeRequired)
            }
            return .success(())
        }
    }
}

enum AIEditConfigError: LocalizedError {
    case maskRequired
    case referenceRequired
    case restoreTypeRequired
    
    var errorDescription: String? {
        switch self {
        case .maskRequired:
            return "Please paint the area you want to edit."
        case .referenceRequired:
            return "Please select a reference image."
        case .restoreTypeRequired:
            return "Please select a restoration type."
        }
    }
}

// MARK: - AI Edit History

/// Collection of AI edits for an asset
struct AIEditHistory: Codable {
    var edits: [AIEdit]
    
    init(edits: [AIEdit] = []) {
        self.edits = edits
    }
    
    /// Get all enabled edits in order
    var enabledEdits: [AIEdit] {
        edits.filter { $0.enabled }
    }
    
    /// Add a new edit
    mutating func add(_ edit: AIEdit) {
        edits.append(edit)
    }
    
    /// Toggle edit visibility
    mutating func toggle(_ editId: UUID) {
        if let index = edits.firstIndex(where: { $0.id == editId }) {
            edits[index].enabled.toggle()
        }
    }
    
    /// Remove an edit
    mutating func remove(_ editId: UUID) {
        edits.removeAll { $0.id == editId }
    }
    
    /// Get edit by ID
    func edit(with id: UUID) -> AIEdit? {
        edits.first { $0.id == id }
    }
}
