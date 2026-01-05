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
