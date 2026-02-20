//
//  FolderManager.swift
//  rawctl
//
//  Multi-folder management with bookmark persistence
//

import Foundation

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
                url = resolvedURL.standardizedFileURL
            } else {
                url = URL(fileURLWithPath: "/")
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
@MainActor
final class FolderManager: ObservableObject {
    static let shared = FolderManager()

    @Published private(set) var sources: [FolderSource] = []
    @Published private(set) var recentFolders: [URL] = []

    private let userDefaults: UserDefaults
    private let sourcesKey: String
    private let recentFoldersKey: String
    private let legacySourcesKeys: [String]
    private let legacyRecentFoldersKeys: [String]
    private let maxRecentFolders: Int
    private var activeScopedURL: URL?

    init(
        userDefaults: UserDefaults = .standard,
        namespace: String = "latent",
        legacyNamespaces: [String] = ["rawctl"],
        maxRecentFolders: Int = 10
    ) {
        self.userDefaults = userDefaults
        self.sourcesKey = "\(namespace).folderSources"
        self.recentFoldersKey = "\(namespace).recentFolders"
        self.legacySourcesKeys = legacyNamespaces.map { "\($0).folderSources" }
        self.legacyRecentFoldersKeys = legacyNamespaces.map { "\($0).recentFolders" }
        self.maxRecentFolders = max(1, maxRecentFolders)
        loadFromUserDefaults()
    }

    var defaultFolderURL: URL? {
        sources.first(where: { $0.isDefault })?.url
    }

    // MARK: - Folder Management

    /// Add (or upsert) a folder source and update recent list
    @discardableResult
    func addFolder(_ url: URL) -> FolderSource? {
        let normalizedURL = url.standardizedFileURL
        if let index = sources.firstIndex(where: { samePath($0.url, normalizedURL) }) {
            addToRecent(normalizedURL)
            return sources[index]
        }

        var source = FolderSource(url: normalizedURL)
        source.bookmarkData = createBookmark(for: normalizedURL)

        // If no default, make this the default
        if sources.isEmpty || !sources.contains(where: { $0.isDefault }) {
            source.isDefault = true
        }

        sources.append(source)
        saveToUserDefaults()
        addToRecent(normalizedURL)

        return source
    }

    /// Remove a folder source
    func removeFolder(_ id: UUID) {
        guard let removed = sources.first(where: { $0.id == id }) else { return }
        sources.removeAll { $0.id == id }

        if let activeScopedURL, samePath(activeScopedURL, removed.url) {
            endAccess()
        }

        if !sources.isEmpty && !sources.contains(where: { $0.isDefault }) {
            sources[0].isDefault = true
        }

        saveToUserDefaults()
    }

    /// Set a folder as the default startup folder
    func setAsDefault(_ id: UUID) {
        for index in sources.indices {
            sources[index].isDefault = (sources[index].id == id)
        }
        saveToUserDefaults()
    }

    /// Update folder's loaded state and asset count
    func updateFolderState(_ id: UUID, isLoaded: Bool, assetCount: Int? = nil) {
        guard let index = sources.firstIndex(where: { $0.id == id }) else { return }
        sources[index].isLoaded = isLoaded
        if isLoaded {
            sources[index].lastOpened = Date()
        }
        if let assetCount {
            sources[index].assetCount = assetCount
        }
        saveToUserDefaults()
    }

    func source(for url: URL) -> FolderSource? {
        let normalizedURL = url.standardizedFileURL
        return sources.first { samePath($0.url, normalizedURL) }
    }

    /// Get the default folder to open on startup
    func getDefaultFolder() -> FolderSource? {
        guard let defaultSource = sources.first(where: { $0.isDefault }) else { return nil }
        guard beginAccess(for: defaultSource) else { return nil }
        return source(for: defaultSource.url) ?? defaultSource
    }

    /// Begin scoped access for a saved folder source.
    func beginAccess(for source: FolderSource) -> Bool {
        guard let bookmark = source.bookmarkData else {
            return true
        }

        var isStale = false
        guard let resolvedURL = try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return false
        }

        if isStale, let refreshed = createBookmark(for: resolvedURL) {
            if let index = sources.firstIndex(where: { $0.id == source.id }) {
                sources[index].bookmarkData = refreshed
                sources[index].url = resolvedURL.standardizedFileURL
                saveToUserDefaults()
            }
        }

        let normalizedResolvedURL = resolvedURL.standardizedFileURL
        if let activeScopedURL, !samePath(activeScopedURL, normalizedResolvedURL) {
            activeScopedURL.stopAccessingSecurityScopedResource()
            self.activeScopedURL = nil
        }

        if let activeScopedURL, samePath(activeScopedURL, normalizedResolvedURL) {
            return true
        }

        guard normalizedResolvedURL.startAccessingSecurityScopedResource() else {
            return false
        }
        activeScopedURL = normalizedResolvedURL
        return true
    }

    /// Begin access for an arbitrary URL. Uses saved bookmark if available.
    func beginAccess(for url: URL) -> Bool {
        let normalizedURL = url.standardizedFileURL
        if let source = source(for: normalizedURL) {
            return beginAccess(for: source)
        }

        if let activeScopedURL, !samePath(activeScopedURL, normalizedURL) {
            activeScopedURL.stopAccessingSecurityScopedResource()
            self.activeScopedURL = nil
        }
        return true
    }

    /// Backward-compatible API
    func startAccessingFolder(_ source: FolderSource) -> Bool {
        beginAccess(for: source)
    }

    /// Stop accessing current security-scoped folder
    func stopAccessingFolder(_ source: FolderSource) {
        guard let activeScopedURL else { return }
        if samePath(activeScopedURL, source.url) {
            endAccess()
        }
    }

    func endAccess() {
        activeScopedURL?.stopAccessingSecurityScopedResource()
        activeScopedURL = nil
    }

    // MARK: - Recent Folders

    /// Add a folder to recent list
    func addToRecent(_ url: URL) {
        let normalizedURL = url.standardizedFileURL
        recentFolders.removeAll { samePath($0, normalizedURL) }
        recentFolders.insert(normalizedURL, at: 0)
        if recentFolders.count > maxRecentFolders {
            recentFolders = Array(recentFolders.prefix(maxRecentFolders))
        }
        saveRecentFolders()
    }

    func clearRecentFolders() {
        recentFolders = []
        saveRecentFolders()
    }

    /// One-time migration from AppState's old default folder key.
    @discardableResult
    func migrateLegacyDefaultFolder(path: String) -> Bool {
        let expandedPath = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return false
        }

        if let existing = source(for: url) {
            setAsDefault(existing.id)
            return true
        }

        if let newSource = addFolder(url) {
            setAsDefault(newSource.id)
            return true
        }
        return false
    }

    // MARK: - Persistence

    private func createBookmark(for url: URL) -> Data? {
        do {
            return try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            print("[FolderManager] Bookmark creation error: \(error)")
            return nil
        }
    }

    func saveToUserDefaults() {
        do {
            let data = try JSONEncoder().encode(sources)
            userDefaults.set(data, forKey: sourcesKey)
        } catch {
            print("[FolderManager] Save error: \(error)")
        }
    }

    private func loadFromUserDefaults() {
        migrateLegacyStorageIfNeeded()

        if let data = userDefaults.data(forKey: sourcesKey) {
            do {
                sources = try JSONDecoder().decode([FolderSource].self, from: data)
            } catch {
                print("[FolderManager] Load error: \(error)")
            }
        }

        if let recentData = userDefaults.array(forKey: recentFoldersKey) as? [String] {
            recentFolders = recentData.map { URL(fileURLWithPath: $0).standardizedFileURL }
        }

        normalizeLoadedSources()
    }

    private func normalizeLoadedSources() {
        var seenPaths: Set<String> = []
        sources = sources.filter { source in
            let path = source.url.standardizedFileURL.path
            guard !path.isEmpty else { return false }
            if seenPaths.contains(path) {
                return false
            }
            seenPaths.insert(path)
            return true
        }

        if !sources.isEmpty && !sources.contains(where: { $0.isDefault }) {
            sources[0].isDefault = true
        }
    }

    private func saveRecentFolders() {
        let paths = recentFolders.map { $0.standardizedFileURL.path }
        userDefaults.set(paths, forKey: recentFoldersKey)
    }

    private func migrateLegacyStorageIfNeeded() {
        if userDefaults.data(forKey: sourcesKey) == nil {
            for legacyKey in legacySourcesKeys {
                if let data = userDefaults.data(forKey: legacyKey) {
                    userDefaults.set(data, forKey: sourcesKey)
                    break
                }
            }
        }

        if userDefaults.array(forKey: recentFoldersKey) == nil {
            for legacyKey in legacyRecentFoldersKeys {
                if let paths = userDefaults.array(forKey: legacyKey) as? [String] {
                    userDefaults.set(paths, forKey: recentFoldersKey)
                    break
                }
            }
        }
    }

    private func samePath(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.standardizedFileURL.path == rhs.standardizedFileURL.path
    }
}
