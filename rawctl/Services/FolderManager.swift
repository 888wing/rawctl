//
//  FolderManager.swift
//  rawctl
//
//  Multi-folder management with bookmark persistence
//

import Foundation
import AppKit

/// Represents a saved folder source
struct FolderSource: Identifiable, Codable {
    let id: UUID
    var url: URL
    var name: String
    var isDefault: Bool         // Open on app launch
    var isLoaded: Bool          // Currently loaded in app
    var assetCount: Int
    var lastOpened: Date?
    
    // Security-scoped bookmark data for persisting sandbox permissions
    var bookmarkData: Data?
    
    init(url: URL, name: String? = nil) {
        self.id = UUID()
        self.url = url
        self.name = name ?? url.lastPathComponent
        self.isDefault = false
        self.isLoaded = false
        self.assetCount = 0
        self.lastOpened = nil
        self.bookmarkData = nil
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, isDefault, isLoaded, assetCount, lastOpened, bookmarkData
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isDefault = try container.decode(Bool.self, forKey: .isDefault)
        isLoaded = try container.decodeIfPresent(Bool.self, forKey: .isLoaded) ?? false
        assetCount = try container.decodeIfPresent(Int.self, forKey: .assetCount) ?? 0
        lastOpened = try container.decodeIfPresent(Date.self, forKey: .lastOpened)
        bookmarkData = try container.decodeIfPresent(Data.self, forKey: .bookmarkData)
        
        // Restore URL from bookmark
        if let bookmark = bookmarkData {
            var isStale = false
            if let resolvedURL = try? URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                url = resolvedURL
            } else {
                url = URL(fileURLWithPath: "/") // Fallback
            }
        } else {
            url = URL(fileURLWithPath: "/")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(isDefault, forKey: .isDefault)
        try container.encode(isLoaded, forKey: .isLoaded)
        try container.encode(assetCount, forKey: .assetCount)
        try container.encodeIfPresent(lastOpened, forKey: .lastOpened)
        try container.encodeIfPresent(bookmarkData, forKey: .bookmarkData)
    }
}

/// Manager for multiple folder sources with persistence
class FolderManager: ObservableObject {
    static let shared = FolderManager()
    
    @Published var sources: [FolderSource] = []
    @Published var recentFolders: [URL] = []
    
    private let userDefaultsKey = "rawctl.folderSources"
    private let recentFoldersKey = "rawctl.recentFolders"
    private let maxRecentFolders = 10
    
    init() {
        loadFromUserDefaults()
    }
    
    // MARK: - Folder Management
    
    /// Add a new folder source
    func addFolder(_ url: URL) -> FolderSource? {
        // Check if already exists
        if sources.contains(where: { $0.url == url }) {
            return sources.first { $0.url == url }
        }
        
        // Create security-scoped bookmark
        guard let bookmark = createBookmark(for: url) else {
            print("[FolderManager] Failed to create bookmark for \(url.path)")
            return nil
        }
        
        var source = FolderSource(url: url)
        source.bookmarkData = bookmark
        
        // If no default, make this the default
        if sources.isEmpty || !sources.contains(where: { $0.isDefault }) {
            source.isDefault = true
        }
        
        sources.append(source)
        saveToUserDefaults()
        
        addToRecent(url)
        
        return source
    }
    
    /// Remove a folder source
    func removeFolder(_ id: UUID) {
        sources.removeAll { $0.id == id }
        saveToUserDefaults()
    }
    
    /// Set a folder as the default startup folder
    func setAsDefault(_ id: UUID) {
        for i in sources.indices {
            sources[i].isDefault = (sources[i].id == id)
        }
        saveToUserDefaults()
    }
    
    /// Update folder's loaded state and asset count
    func updateFolderState(_ id: UUID, isLoaded: Bool, assetCount: Int? = nil) {
        if let index = sources.firstIndex(where: { $0.id == id }) {
            sources[index].isLoaded = isLoaded
            if isLoaded {
                sources[index].lastOpened = Date()
            }
            if let count = assetCount {
                sources[index].assetCount = count
            }
            saveToUserDefaults()
        }
    }
    
    /// Get the default folder to open on startup
    func getDefaultFolder() -> FolderSource? {
        if let defaultSource = sources.first(where: { $0.isDefault }) {
            // Start security-scoped access
            if startAccessingFolder(defaultSource) {
                return defaultSource
            }
        }
        return nil
    }
    
    /// Start accessing a security-scoped folder
    func startAccessingFolder(_ source: FolderSource) -> Bool {
        guard let bookmark = source.bookmarkData else { return false }
        
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return false
        }
        
        if isStale {
            // Need to recreate bookmark
            if let newBookmark = createBookmark(for: url) {
                if let index = sources.firstIndex(where: { $0.id == source.id }) {
                    sources[index].bookmarkData = newBookmark
                    saveToUserDefaults()
                }
            }
        }
        
        return url.startAccessingSecurityScopedResource()
    }
    
    /// Stop accessing a security-scoped folder
    func stopAccessingFolder(_ source: FolderSource) {
        source.url.stopAccessingSecurityScopedResource()
    }
    
    // MARK: - Recent Folders
    
    /// Add a folder to recent list
    func addToRecent(_ url: URL) {
        recentFolders.removeAll { $0 == url }
        recentFolders.insert(url, at: 0)
        if recentFolders.count > maxRecentFolders {
            recentFolders = Array(recentFolders.prefix(maxRecentFolders))
        }
        saveRecentFolders()
    }
    
    // MARK: - Persistence
    
    private func createBookmark(for url: URL) -> Data? {
        do {
            let bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            return bookmark
        } catch {
            print("[FolderManager] Bookmark creation error: \(error)")
            return nil
        }
    }
    
    func saveToUserDefaults() {
        do {
            let data = try JSONEncoder().encode(sources)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("[FolderManager] Save error: \(error)")
        }
    }
    
    private func loadFromUserDefaults() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey) {
            do {
                sources = try JSONDecoder().decode([FolderSource].self, from: data)
            } catch {
                print("[FolderManager] Load error: \(error)")
            }
        }
        
        // Load recent folders
        if let recentData = UserDefaults.standard.array(forKey: recentFoldersKey) as? [String] {
            recentFolders = recentData.compactMap { URL(fileURLWithPath: $0) }
        }
    }
    
    private func saveRecentFolders() {
        let paths = recentFolders.map { $0.path }
        UserDefaults.standard.set(paths, forKey: recentFoldersKey)
    }
}
