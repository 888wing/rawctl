//
//  Catalog.swift
//  rawctl
//
//  Central catalog managing projects and collections
//

import Foundation

/// Import preferences for automatic import
struct ImportPreferences: Codable, Equatable {
    var autoCreateProject: Bool
    var projectNamingTemplate: String  // "{Date}_{CardName}"
    var subfoldersBy: DateGrouping
    var autoImportOnMount: Bool
    var deleteAfterImport: Bool

    enum DateGrouping: String, Codable, CaseIterable {
        case none = "No Subfolders"
        case day = "By Day (YYYY-MM-DD)"
        case month = "By Month (YYYY-MM)"
        case year = "By Year (YYYY)"
    }

    init() {
        self.autoCreateProject = true
        self.projectNamingTemplate = "{Date}_{CardName}"
        self.subfoldersBy = .day
        self.autoImportOnMount = false
        self.deleteAfterImport = false
    }
}

/// Export preset for quick export
struct ExportPreset: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var icon: String
    var maxSize: Int?        // nil = original
    var quality: Int         // 60-100
    var colorSpace: String   // sRGB, AdobeRGB
    var addWatermark: Bool
    var isBuiltIn: Bool

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "square.and.arrow.up",
        maxSize: Int? = nil,
        quality: Int = 90,
        colorSpace: String = "sRGB",
        addWatermark: Bool = false,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.maxSize = maxSize
        self.quality = quality
        self.colorSpace = colorSpace
        self.addWatermark = addWatermark
        self.isBuiltIn = isBuiltIn
    }

    // Built-in presets
    static let clientPreview = ExportPreset(
        name: "Client Preview",
        icon: "eye",
        maxSize: 1920,
        quality: 80,
        addWatermark: true,
        isBuiltIn: true
    )

    static let webGallery = ExportPreset(
        name: "Web Gallery",
        icon: "globe",
        maxSize: 2048,
        quality: 85,
        isBuiltIn: true
    )

    static let fullQuality = ExportPreset(
        name: "Full Quality",
        icon: "arrow.up.doc",
        maxSize: nil,
        quality: 100,
        isBuiltIn: true
    )

    static let socialMedia = ExportPreset(
        name: "Social Media",
        icon: "square.and.arrow.up.on.square",
        maxSize: 1080,
        quality: 90,
        isBuiltIn: true
    )
}

/// Central catalog for the rawctl library
struct Catalog: Codable, Equatable {
    static let currentVersion = 1

    var version: Int
    var libraryPath: URL
    var projects: [Project]
    var smartCollections: [SmartCollection]
    var importPreferences: ImportPreferences
    var exportPresets: [ExportPreset]
    var lastOpenedProjectId: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(libraryPath: URL) {
        self.version = Self.currentVersion
        self.libraryPath = libraryPath
        self.projects = []
        self.smartCollections = [
            .fiveStars,
            .picks,
            .rejects,
            .unrated,
            .edited
        ]
        self.importPreferences = ImportPreferences()
        self.exportPresets = [
            .clientPreview,
            .webGallery,
            .fullQuality,
            .socialMedia
        ]
        self.lastOpenedProjectId = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Project Management

    mutating func addProject(_ project: Project) {
        projects.append(project)
        updatedAt = Date()
    }

    mutating func removeProject(_ id: UUID) {
        projects.removeAll { $0.id == id }
        updatedAt = Date()
    }

    mutating func updateProject(_ project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
            updatedAt = Date()
        }
    }

    func getProject(_ id: UUID) -> Project? {
        projects.first { $0.id == id }
    }

    /// Projects grouped by month (for sidebar display)
    var projectsByMonth: [(month: String, projects: [Project])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"

        let grouped = Dictionary(grouping: projects) { project in
            formatter.string(from: project.shootDate)
        }

        return grouped
            .sorted { $0.key > $1.key }  // Newest first
            .map { (month: $0.key, projects: $0.value.sorted { $0.shootDate > $1.shootDate }) }
    }

    // MARK: - Smart Collection Management

    mutating func addSmartCollection(_ collection: SmartCollection) {
        smartCollections.append(collection)
        updatedAt = Date()
    }

    mutating func removeSmartCollection(_ id: UUID) {
        smartCollections.removeAll { $0.id == id && !$0.isBuiltIn }
        updatedAt = Date()
    }

    mutating func updateSmartCollection(_ collection: SmartCollection) {
        if let index = smartCollections.firstIndex(where: { $0.id == collection.id }) {
            // Only allow updating non-built-in collections
            if !smartCollections[index].isBuiltIn {
                smartCollections[index] = collection
                updatedAt = Date()
            }
        }
    }

    // MARK: - Export Preset Management

    mutating func addExportPreset(_ preset: ExportPreset) {
        exportPresets.append(preset)
        updatedAt = Date()
    }

    mutating func removeExportPreset(_ id: UUID) {
        exportPresets.removeAll { $0.id == id && !$0.isBuiltIn }
        updatedAt = Date()
    }

    // MARK: - Statistics

    var totalPhotos: Int {
        projects.reduce(0) { $0 + $1.totalPhotos }
    }

    var activeProjects: [Project] {
        projects.filter { $0.status != .archived && $0.status != .delivered }
    }
}
