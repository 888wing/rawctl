//
//  ExportSettings.swift
//  rawctl
//
//  Export configuration model
//

import Foundation

/// Export settings for JPG output
struct ExportSettings: Codable {
    var destinationFolder: URL?
    var quality: Int = 85  // 60-100
    var sizeOption: SizeOption = .original
    var customSize: Int = 2048
    var filenameSuffix: String = "_edit"
    var exportSelection: ExportSelection = .current
    
    /// Size options for export
    enum SizeOption: String, CaseIterable, Identifiable, Codable {
        case original = "Original"
        case recipeResize = "Use Recipe Resize"
        case size2048 = "2048px"
        case size4096 = "4096px"
        case custom = "Custom"

        var id: String { rawValue }

        var maxSize: Int? {
            switch self {
            case .original: return nil
            case .recipeResize: return nil // Uses per-photo recipe resize settings
            case .size2048: return 2048
            case .size4096: return 4096
            case .custom: return nil // Use customSize
            }
        }

        /// Whether this option uses per-photo recipe resize settings
        var usesRecipeResize: Bool {
            self == .recipeResize
        }
    }
    
    /// What to export
    enum ExportSelection: String, CaseIterable, Identifiable, Codable {
        case current = "Current Photo"
        case selected = "Selected Photos"
        case all = "All Photos"
        
        var id: String { rawValue }
    }
    
    /// Get actual max size to use (for non-recipe-resize options)
    func getMaxSize(customSize: Int) -> CGFloat? {
        switch sizeOption {
        case .original:
            return nil
        case .recipeResize:
            return nil  // Handled by per-photo recipe
        case .size2048:
            return 2048
        case .size4096:
            return 4096
        case .custom:
            return CGFloat(customSize)
        }
    }
}

// MARK: - Quick Export Manager

/// Manages Quick Export settings persistence
class QuickExportManager {
    static let shared = QuickExportManager()
    
    private let settingsKey = "com.rawctl.quickExportSettings"
    private let defaults = UserDefaults.standard
    
    private init() {}
    
    /// Save settings for quick export
    func saveSettings(_ settings: ExportSettings) {
        if let encoded = try? JSONEncoder().encode(settings) {
            defaults.set(encoded, forKey: settingsKey)
        }
    }
    
    /// Load last used settings
    func loadSettings() -> ExportSettings? {
        guard let data = defaults.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(ExportSettings.self, from: data) else {
            return nil
        }
        return settings
    }
    
    /// Check if quick export is available (has valid destination)
    var isQuickExportAvailable: Bool {
        guard let settings = loadSettings() else { return false }
        return settings.destinationFolder != nil
    }
    
    /// Get quick export destination description
    var destinationDescription: String {
        guard let settings = loadSettings(),
              let folder = settings.destinationFolder else {
            return "Not configured"
        }
        return folder.lastPathComponent
    }
}

/// Single export job
struct ExportJob: Identifiable {
    let id: UUID = UUID()
    let asset: PhotoAsset
    let recipe: EditRecipe
    let settings: ExportSettings
    var status: ExportStatus = .pending
    var error: String?
    
    enum ExportStatus {
        case pending
        case processing
        case completed
        case failed
    }
}
