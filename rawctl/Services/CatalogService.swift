//
//  CatalogService.swift
//  rawctl
//
//  Service for catalog persistence
//

import Foundation

/// Service for loading and saving the catalog
actor CatalogService {
    private let catalogPath: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(catalogPath: URL) {
        self.catalogPath = catalogPath

        self.encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    /// Default catalog location
    static var defaultCatalogPath: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let rawctlDir = appSupport.appendingPathComponent("rawctl", isDirectory: true)
        return rawctlDir.appendingPathComponent("rawctl-catalog.json")
    }

    /// Default library path
    static var defaultLibraryPath: URL {
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
        return pictures.appendingPathComponent("rawctl Library", isDirectory: true)
    }

    // MARK: - Load / Save

    /// Load catalog from disk
    func load() async throws -> Catalog? {
        guard FileManager.default.fileExists(atPath: catalogPath.path) else {
            return nil
        }

        let data = try Data(contentsOf: catalogPath)
        return try decoder.decode(Catalog.self, from: data)
    }

    /// Save catalog to disk
    func save(_ catalog: Catalog) async throws {
        // Ensure directory exists
        let directory = catalogPath.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let data = try encoder.encode(catalog)
        try data.write(to: catalogPath, options: .atomic)
    }

    /// Load existing catalog or create new one
    func loadOrCreate(libraryPath: URL) async throws -> Catalog {
        if let existing = try await load() {
            return existing
        }

        // Create new catalog
        let catalog = Catalog(libraryPath: libraryPath)

        // Ensure library directory exists
        if !FileManager.default.fileExists(atPath: libraryPath.path) {
            try FileManager.default.createDirectory(at: libraryPath, withIntermediateDirectories: true)
        }

        try await save(catalog)
        return catalog
    }

    /// Create a backup before major changes
    func createBackup() async throws -> URL {
        guard FileManager.default.fileExists(atPath: catalogPath.path) else {
            throw CatalogError.catalogNotFound
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let timestamp = formatter.string(from: Date())

        let backupName = "rawctl-catalog-backup-\(timestamp).json"
        let backupPath = catalogPath.deletingLastPathComponent().appendingPathComponent(backupName)

        try FileManager.default.copyItem(at: catalogPath, to: backupPath)
        return backupPath
    }
}

/// Catalog-related errors
enum CatalogError: Error, LocalizedError {
    case catalogNotFound
    case migrationFailed(String)
    case corruptedData

    var errorDescription: String? {
        switch self {
        case .catalogNotFound:
            return "Catalog file not found"
        case .migrationFailed(let reason):
            return "Catalog migration failed: \(reason)"
        case .corruptedData:
            return "Catalog data is corrupted"
        }
    }
}
