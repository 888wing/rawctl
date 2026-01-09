//
//  Project.swift
//  rawctl
//
//  Project model for organizing photo shoots
//

import Foundation

/// Type of photography project
enum ProjectType: String, Codable, CaseIterable, Identifiable {
    case wedding
    case portrait
    case event
    case landscape
    case street
    case product
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .wedding: return "Wedding"
        case .portrait: return "Portrait"
        case .event: return "Event"
        case .landscape: return "Landscape"
        case .street: return "Street"
        case .product: return "Product"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .wedding: return "heart.fill"
        case .portrait: return "person.fill"
        case .event: return "party.popper.fill"
        case .landscape: return "mountain.2.fill"
        case .street: return "building.2.fill"
        case .product: return "cube.fill"
        case .other: return "folder.fill"
        }
    }
}

/// Project workflow status
enum ProjectStatus: String, Codable, CaseIterable {
    case importing      // Photos being imported
    case culling        // Selection/rating in progress
    case editing        // Post-processing
    case readyForDelivery  // Ready to export
    case delivered      // Exported to client
    case archived       // Completed, archived

    var displayName: String {
        switch self {
        case .importing: return "Importing"
        case .culling: return "Culling"
        case .editing: return "Editing"
        case .readyForDelivery: return "Ready"
        case .delivered: return "Delivered"
        case .archived: return "Archived"
        }
    }

    var color: (r: Double, g: Double, b: Double) {
        switch self {
        case .importing: return (0.5, 0.5, 0.5)
        case .culling: return (1.0, 0.6, 0.2)
        case .editing: return (0.3, 0.6, 1.0)
        case .readyForDelivery: return (0.3, 0.8, 0.3)
        case .delivered: return (0.5, 0.8, 0.5)
        case .archived: return (0.6, 0.6, 0.6)
        }
    }
}

// MARK: - Project Import Source (v2)

/// Tracks where a project was imported from
enum ProjectImportSource: Codable, Equatable {
    case native                                                    // rawctl native
    case lightroom(catalogPath: String, importedAt: Date, lastSyncVersion: Int64?)

    var isLightroomImport: Bool {
        if case .lightroom = self { return true }
        return false
    }
}

// MARK: - Saved Filter State (v2)

/// Persistable filter state for Project save/restore
/// Separate from AppState.FilterState which is UI-only
struct SavedFilterState: Codable, Equatable {
    var minRating: Int                      // 0 = no filter
    var flagFilter: Flag?                   // nil = no filter
    var colorLabel: ColorLabel?             // nil = no filter
    var tag: String                         // "" = no filter

    init() {
        self.minRating = 0
        self.flagFilter = nil
        self.colorLabel = nil
        self.tag = ""
    }

    init(minRating: Int, flagFilter: Flag?, colorLabel: ColorLabel?, tag: String) {
        self.minRating = minRating
        self.flagFilter = flagFilter
        self.colorLabel = colorLabel
        self.tag = tag
    }

    var hasActiveFilters: Bool {
        minRating > 0 || flagFilter != nil || colorLabel != nil || !tag.isEmpty
    }
}

// MARK: - Saved View Mode (v2)

/// Persistable view mode for Project save/restore
enum SavedViewMode: String, Codable, Equatable {
    case grid
    case single
}

// MARK: - Project

/// Represents a photography project/shoot
struct Project: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var clientName: String?
    var shootDate: Date
    var projectType: ProjectType
    var sourceFolders: [URL]
    var outputFolder: URL?
    var status: ProjectStatus
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    // Cached statistics (updated on folder scan)
    var totalPhotos: Int
    var ratedPhotos: Int
    var flaggedPhotos: Int
    var exportedPhotos: Int

    // === State Memory (v2) ===
    var lastSelectedPhotoPath: String?              // URL path of last selected photo
    var savedFilterState: SavedFilterState?         // Filter conditions
    var sortCriteria: String?                       // Reuse AppState.SortCriteria raw value
    var sortAscending: Bool?
    var savedViewMode: SavedViewMode?               // grid / single
    var gridZoomLevel: Double?

    // === Bookmark Data (v2) ===
    var folderBookmarks: [String: Data]?            // path -> bookmark data

    // === Import Source (v2) ===
    var importSource: ProjectImportSource?

    init(
        id: UUID = UUID(),
        name: String,
        clientName: String? = nil,
        shootDate: Date,
        projectType: ProjectType,
        sourceFolders: [URL] = [],
        outputFolder: URL? = nil,
        status: ProjectStatus = .importing,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.clientName = clientName
        self.shootDate = shootDate
        self.projectType = projectType
        self.sourceFolders = sourceFolders
        self.outputFolder = outputFolder
        self.status = status
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
        self.totalPhotos = 0
        self.ratedPhotos = 0
        self.flaggedPhotos = 0
        self.exportedPhotos = 0

        // v2 fields default to nil
        self.lastSelectedPhotoPath = nil
        self.savedFilterState = nil
        self.sortCriteria = nil
        self.sortAscending = nil
        self.savedViewMode = nil
        self.gridZoomLevel = nil
        self.folderBookmarks = nil
        self.importSource = nil
    }

    /// Update statistics from assets and recipes
    mutating func updateStatistics(assets: [PhotoAsset], recipes: [UUID: EditRecipe]) {
        totalPhotos = assets.count
        ratedPhotos = assets.filter { recipes[$0.id]?.rating ?? 0 > 0 }.count
        flaggedPhotos = assets.filter { recipes[$0.id]?.flag == .pick }.count
        updatedAt = Date()
    }

    /// Progress percentage based on status
    var progressPercentage: Double {
        switch status {
        case .importing: return 0.1
        case .culling: return 0.3
        case .editing: return 0.6
        case .readyForDelivery: return 0.9
        case .delivered: return 1.0
        case .archived: return 1.0
        }
    }
}

// MARK: - Project Bookmark Management (v2)

extension Project {
    /// Get bookmark data for a specific folder URL
    func getBookmarkData(for url: URL) -> Data? {
        folderBookmarks?[url.path]
    }

    /// Store bookmark data for a folder URL
    mutating func setBookmarkData(_ data: Data, for url: URL) {
        if folderBookmarks == nil {
            folderBookmarks = [:]
        }
        folderBookmarks?[url.path] = data
    }

    /// Remove bookmark data for a folder URL
    mutating func removeBookmarkData(for url: URL) {
        folderBookmarks?.removeValue(forKey: url.path)
        if folderBookmarks?.isEmpty == true {
            folderBookmarks = nil
        }
    }

    /// Check if project has valid bookmarks for all source folders
    var hasValidBookmarks: Bool {
        guard let bookmarks = folderBookmarks else { return false }
        return sourceFolders.allSatisfy { bookmarks[$0.path] != nil }
    }
}
