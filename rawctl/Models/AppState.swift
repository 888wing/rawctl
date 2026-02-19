//
//  AppState.swift
//  rawctl
//
//  Global application state managing UI and data
//

import SwiftUI
import Combine

/// Main application state
@MainActor
final class AppState: ObservableObject {
    private enum StartupStorageKeys {
        static let lastOpenedFolder = "latent.lastOpenedFolder"
        static let legacyLastOpenedFolder = "lastOpenedFolder"
        static let legacyDefaultFolderPath = "defaultFolderPath"
    }

    enum StartupFolderChoice: Equatable {
        case defaultFolder(URL)
        case lastOpened(URL)
        case none
    }

    // MARK: - Undo/Redo Storage
    
    struct HistoryStack {
        var undoStack: [EditRecipe] = []
        var redoStack: [EditRecipe] = []
        
        mutating func push(_ recipe: EditRecipe) {
            undoStack.append(recipe)
            if undoStack.count > 50 { undoStack.removeFirst() } // Cap history
            redoStack.removeAll() // New action clears redo
        }
        
        mutating func undo(current: EditRecipe) -> EditRecipe? {
            guard let last = undoStack.popLast() else { return nil }
            redoStack.append(current)
            return last
        }
        
        mutating func redo(current: EditRecipe) -> EditRecipe? {
            guard let next = redoStack.popLast() else { return nil }
            undoStack.append(current)
            return next
        }
    }
    
    @Published var history: [UUID: HistoryStack] = [:]
    
    // MARK: - Folder & Assets

    private let userDefaults: UserDefaults
    private let folderManager: FolderManager
    
    @Published var selectedFolder: URL? {
        didSet {
            // Save to UserDefaults when folder changes
            if let folder = selectedFolder {
                userDefaults.set(folder.path, forKey: StartupStorageKeys.lastOpenedFolder)
            }
        }
    }
    @Published var assets: [PhotoAsset] = []
    @Published var isLoading: Bool = false
    @Published var loadingMessage: String = ""
    
    // MARK: - Thumbnail Preloading Progress
    
    /// Thumbnail loading progress state
    enum ThumbnailLoadingProgress: Equatable {
        case idle
        case loading(loaded: Int, total: Int)
        case complete
        
        var isLoading: Bool {
            if case .loading = self { return true }
            return false
        }
    }
    
    @Published var thumbnailLoadingProgress: ThumbnailLoadingProgress = .idle

    // MARK: - AI Culling Progress

    /// Progress state for the background AI culling pass.
    enum CullingProgress: Equatable {
        case idle
        case running(completed: Int, total: Int)
        case complete(scored: Int)

        var isRunning: Bool {
            if case .running = self { return true }
            return false
        }
    }

    @Published var cullingProgress: CullingProgress = .idle
    private var cullingAutoHideTask: Task<Void, Never>?

    // MARK: - Smart Sync Progress

    /// Progress state for the background Smart Sync pass.
    enum SmartSyncState: Equatable {
        case idle
        case indexing(completed: Int, total: Int)
        case complete(synced: Int)

        var isRunning: Bool {
            if case .indexing = self { return true }
            return false
        }

        static func == (lhs: SmartSyncState, rhs: SmartSyncState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case (.indexing(let a, let b), .indexing(let c, let d)): return a == c && b == d
            case (.complete(let a), .complete(let b)): return a == b
            default: return false
            }
        }
    }

    @Published var smartSyncState: SmartSyncState = .idle
    /// Pending match results awaiting user confirmation.
    @Published var smartSyncMatches: [SmartSyncMatch] = []
    /// Whether the Smart Sync confirmation sheet is presented.
    @Published var showSmartSyncSheet: Bool = false
    private var smartSyncAutoHideTask: Task<Void, Never>?

    private var recipeLoadTask: Task<Void, Never>?
    private var thumbnailPreloadTask: Task<Void, Never>?
    private var thumbnailAutoHideTask: Task<Void, Never>?
    private var sidecarWriteMetricsTask: Task<Void, Never>?
    private var pendingRecipeSaveTask: Task<Void, Never>?
    private var pendingRecipeSavePayloads: [UUID: RecipeSavePayload] = [:]
    private let thumbnailWarmupDelayNs: UInt64 = 120_000_000
    private let e2eSidecarMetricsPollIntervalNs: UInt64 = 300_000_000
    private lazy var selectionCoordinator = SelectionCoordinator(appState: self)
    private lazy var editStateCoordinator = EditStateCoordinator(appState: self)
    private lazy var librarySyncCoordinator = LibrarySyncCoordinator(appState: self)
    
    /// Load last opened or default folder on startup
    func loadStartupFolder() async {
        let choice = Self.resolveStartupFolderChoice(
            defaultFolderURL: folderManager.defaultFolderURL,
            lastOpenedFolderPath: userDefaults.string(forKey: StartupStorageKeys.lastOpenedFolder)
        )

        switch choice {
        case .defaultFolder(let url):
            let didOpenDefault = await openFolder(at: url, registerInFolderHistory: false)
            if !didOpenDefault,
               let lastOpened = userDefaults.string(forKey: StartupStorageKeys.lastOpenedFolder) {
                _ = await openFolderFromPath(lastOpened, registerInFolderHistory: true)
            }
        case .lastOpened(let url):
            _ = await openFolder(at: url, registerInFolderHistory: true)
        case .none:
            return
        }
    }

    static func resolveStartupFolderChoice(
        defaultFolderURL: URL?,
        lastOpenedFolderPath: String?
    ) -> StartupFolderChoice {
        if let defaultFolderURL {
            return .defaultFolder(defaultFolderURL)
        }
        if let lastOpenedFolderPath, !lastOpenedFolderPath.isEmpty {
            return .lastOpened(URL(fileURLWithPath: lastOpenedFolderPath))
        }
        return .none
    }

    init(
        userDefaults: UserDefaults = .standard,
        folderManager: FolderManager = .shared
    ) {
        self.userDefaults = userDefaults
        self.folderManager = folderManager
        migrateLegacyStartupKeysIfNeeded()

        if ProcessInfo.processInfo.environment["RAWCTL_E2E_STATUS"] == "1" {
            sidecarWriteMetricsTask = Task { [weak self] in
                guard let self else { return }
                await SidecarService.shared.resetWriteMetrics()
                while !Task.isCancelled {
                    await self.refreshSidecarWriteMetrics()
                    try? await Task.sleep(nanoseconds: self.e2eSidecarMetricsPollIntervalNs)
                }
            }
        }
    }

    private func migrateLegacyStartupKeysIfNeeded() {
        if userDefaults.string(forKey: StartupStorageKeys.lastOpenedFolder) == nil,
           let legacyPath = userDefaults.string(forKey: StartupStorageKeys.legacyLastOpenedFolder),
           !legacyPath.isEmpty {
            userDefaults.set(legacyPath, forKey: StartupStorageKeys.lastOpenedFolder)
        }

        if let legacyDefault = userDefaults.string(forKey: StartupStorageKeys.legacyDefaultFolderPath),
           !legacyDefault.isEmpty {
            let migrated = folderManager.migrateLegacyDefaultFolder(path: legacyDefault)
            if migrated {
                userDefaults.removeObject(forKey: StartupStorageKeys.legacyDefaultFolderPath)
            }
        }
    }

    func cancelBackgroundAssetLoading(resetThumbnailProgress: Bool = false) {
        recipeLoadTask?.cancel()
        recipeLoadTask = nil
        thumbnailPreloadTask?.cancel()
        thumbnailPreloadTask = nil
        thumbnailAutoHideTask?.cancel()
        thumbnailAutoHideTask = nil
        if e2eSidecarLoadState == "running" {
            e2eSidecarLoadState = "cancelled"
        }
        if e2eThumbnailPreloadState == "running" {
            e2eThumbnailPreloadState = "cancelled"
        }
        if resetThumbnailProgress {
            thumbnailLoadingProgress = .idle
        }
    }

    func schedulePostScanBackgroundWork(expectedFolder: URL? = nil) {
        let expectedFolderPath = expectedFolder?.standardizedFileURL.path
        cancelBackgroundAssetLoading(resetThumbnailProgress: false)
        recipeLoadTask = Task {
            await primeSelectedAssetSidecar(expectedFolderPath: expectedFolderPath)
            guard !Task.isCancelled else { return }
            guard isAssetLoadContextValid(expectedFolderPath: expectedFolderPath) else { return }
            await loadAllRecipes(expectedFolderPath: expectedFolderPath, excludingAssetId: selectedAssetId)
            guard !Task.isCancelled else { return }
            guard isAssetLoadContextValid(expectedFolderPath: expectedFolderPath) else { return }
            // Let first-selection UI settle before thumbnail fan-out to reduce contention.
            try? await Task.sleep(nanoseconds: thumbnailWarmupDelayNs)
            guard !Task.isCancelled else { return }
            guard isAssetLoadContextValid(expectedFolderPath: expectedFolderPath) else { return }
            preloadThumbnails(expectedFolderPath: expectedFolderPath)
        }
    }

    private func isAssetLoadContextValid(expectedFolderPath: String?) -> Bool {
        guard let expectedFolderPath else { return true }
        return selectedFolder?.standardizedFileURL.path == expectedFolderPath
    }

    private func primeSelectedAssetSidecar(expectedFolderPath: String?) async {
        guard isAssetLoadContextValid(expectedFolderPath: expectedFolderPath) else { return }
        guard let selected = selectedAsset else { return }
        guard recipes[selected.id] == nil || localNodes[selected.url] == nil || aiEditsByURL[selected.url] == nil || aiLayerStacks[selected.id] == nil else { return }

        if let state = await SidecarService.shared.loadRenderState(for: selected.url) {
            guard !Task.isCancelled else { return }
            guard isAssetLoadContextValid(expectedFolderPath: expectedFolderPath) else { return }
            guard selectedAssetId == selected.id else { return }
            recipes[selected.id] = state.recipe
            snapshots[selected.id] = state.snapshots
            localNodes[selected.url] = state.localNodes
            aiEditsByURL[selected.url] = state.aiEdits
            setAILayers(state.aiLayers, for: selected.id)
        }
    }

    private func resetE2EPhaseMetrics() {
        e2eScanPhaseMs = 0
        e2eSidecarLoadState = "idle"
        e2eSidecarLoadedCount = 0
        e2eSidecarLoadMs = 0
        e2eSidecarLoadUs = 0
        e2eSidecarWriteQueued = 0
        e2eSidecarWriteSkippedNoOp = 0
        e2eSidecarWriteFlushed = 0
        e2eSidecarWriteWritten = 0
        e2eThumbnailPreloadState = "idle"
        e2eThumbnailPreloadMs = 0
        e2eLocalExportMatch = "idle"
        e2eLocalPreviewDiff = ""
        e2eLocalPreviewHash = ""
        e2eLocalExportHash = ""

        if ProcessInfo.processInfo.environment["RAWCTL_E2E_STATUS"] == "1" {
            Task { [weak self] in
                guard let self else { return }
                await self.resetE2ESidecarWriteMetrics()
            }
        }
    }
    
    // MARK: - Selection & View
    
    @Published var selectedAssetId: PhotoAsset.ID?
    @Published var selectedAssetIds: Set<UUID> = []  // Multi-selection
    @Published var isSelectionMode: Bool = false     // Selection mode toggle
    @Published var viewMode: ViewMode = .grid
    @Published var previewQuality: PreviewQuality = .full
    @Published var currentPreviewImage: NSImage?  // For histogram

    // Eyedropper mode for white balance
    @Published var eyedropperMode: Bool = false

    // Transform mode for crop/rotate/resize editing
    @Published var transformMode: Bool = false

    // E2E performance/status hooks
    @Published var e2eSliderStressState: String = "idle"
    @Published var e2eFirstSelectionLatencyMs: Int = 0
    @Published var e2eScanPhaseMs: Int = 0
    @Published var e2eSidecarLoadState: String = "idle"
    @Published var e2eSidecarLoadedCount: Int = 0
    @Published var e2eSidecarLoadMs: Int = 0
    @Published var e2eSidecarLoadUs: Int = 0
    @Published var e2eSidecarWriteQueued: Int = 0
    @Published var e2eSidecarWriteSkippedNoOp: Int = 0
    @Published var e2eSidecarWriteFlushed: Int = 0
    @Published var e2eSidecarWriteWritten: Int = 0
    @Published var e2eThumbnailPreloadState: String = "idle"
    @Published var e2eThumbnailPreloadMs: Int = 0
    @Published var e2eLocalExportMatch: String = "idle"   // "1" | "0" | "idle" | "error:*"
    @Published var e2eLocalPreviewDiff: String = ""
    @Published var e2eLocalPreviewHash: String = ""
    @Published var e2eLocalExportHash: String = ""

    // MARK: - Catalog & Project Mode

    /// The loaded catalog (nil if using legacy folder mode)
    @Published var catalog: Catalog?

    /// Currently selected project (nil = legacy folder mode or library view)
    @Published var selectedProject: Project?

    /// Currently active smart collection filter
    @Published var activeSmartCollection: SmartCollection? {
        didSet { invalidateFilterCache() }
    }

    /// Whether we're in project mode vs legacy folder mode
    var isProjectMode: Bool {
        selectedProject != nil
    }

    /// Whether we're viewing a smart collection
    var isSmartCollectionMode: Bool {
        activeSmartCollection != nil
    }

    /// Assets filtered by active smart collection
    var smartFilteredAssets: [PhotoAsset] {
        filteredAssets
    }

    /// Select a project and load assets from ALL source folders
    func selectProject(_ project: Project) async {
        selectedProject = project
        activeSmartCollection = nil
        cancelBackgroundAssetLoading(resetThumbnailProgress: true)
        resetE2EPhaseMetrics()

        // Clear existing assets before loading
        assets = []
        recipes = [:]
        snapshots = [:]
        localNodes = [:]
        aiLayerStacks = [:]
        aiEditsByURL = [:]

        // Load all source folders
        if !project.sourceFolders.isEmpty {
            isLoading = true
            loadingMessage = "Loading project folders..."

            var allAssets: [PhotoAsset] = []

            for folder in project.sourceFolders {
                loadingMessage = "Scanning \(folder.lastPathComponent)..."
                do {
                    let folderAssets = try await FileSystemService.scanFolder(folder)
                    allAssets.append(contentsOf: folderAssets)
                } catch {
                    print("[AppState] Error scanning folder \(folder.path): \(error)")
                }
            }

            // Sort combined assets by filename
            assets = allAssets.sorted {
                $0.filename.localizedStandardCompare($1.filename) == .orderedAscending
            }

            // Set selected folder to first folder (for display purposes)
            selectedFolder = project.sourceFolders.first

            isLoading = false
            loadingMessage = ""

            // Select first asset
            if let first = assets.first {
                select(first, switchToSingleView: false)
            }

            // Load recipes and thumbnails in cancellable background tasks.
            schedulePostScanBackgroundWork()
        }

        // Update catalog's last opened
        if var cat = catalog {
            cat.lastOpenedProjectId = project.id
            catalog = cat
        }
    }

    /// Clear project selection (return to library view)
    func clearProjectSelection() {
        librarySyncCoordinator.clearProjectSelection()
    }

    /// Apply a smart collection filter
    func applySmartCollection(_ collection: SmartCollection?) {
        librarySyncCoordinator.applySmartCollection(collection)
    }

    func applyRecentImportsFilter(days: Int = 7) {
        librarySyncCoordinator.applyRecentImportsFilter(days: days)
    }

    func showAllPhotosInLibrary() {
        librarySyncCoordinator.showAllPhotosInLibrary()
    }

    // Comparison and Zoom State
    enum ComparisonMode {
        case none
        case sideBySide
    }
    @Published var comparisonMode: ComparisonMode = .none
    @Published var isZoomed: Bool = false
    
    // MARK: - Multi-Selection
    
    /// Check if an asset is selected in multi-select mode
    func isSelected(_ assetId: UUID) -> Bool {
        selectedAssetIds.contains(assetId)
    }
    
    /// Toggle selection for multi-select (Cmd+click)
    func toggleSelection(_ assetId: UUID) {
        selectionCoordinator.toggleSelection(assetId)
    }
    
    /// Extend selection to asset (Shift+click)
    func extendSelection(to assetId: UUID) {
        selectionCoordinator.extendSelection(to: assetId)
    }
    
    /// Clear multi-selection
    func clearMultiSelection() {
        selectionCoordinator.clearMultiSelection()
    }
    
    /// Select all filtered assets
    func selectAll() {
        selectionCoordinator.selectAll()
    }
    
    /// Get selected assets
    var selectedAssets: [PhotoAsset] {
        filteredAssets.filter { selectedAssetIds.contains($0.id) }
    }
    
    /// Count of selected assets
    var selectionCount: Int {
        selectedAssetIds.count
    }
    
    // Professional Tools
    @Published var showHighlightClipping: Bool = false
    @Published var showShadowClipping: Bool = false

    // Global sheets
    @Published var showAccountSheet: Bool = false

    enum ViewMode: String, CaseIterable {
        case grid
        case single
    }
    
    /// Preview quality mode for performance optimization
    enum PreviewQuality {
        case fast   // 800px - used during slider drag
        case full   // 1600px - used after slider release
        
        var maxSize: CGFloat {
            switch self {
            case .fast: return 800
            case .full: return 1600
            }
        }
    }
    
    // MARK: - Editing (per-photo recipes)

    /// Recipes dictionary keyed by asset ID
    @Published var recipes: [UUID: EditRecipe] = [:] {
        didSet { invalidateFilterCache() }
    }

    // MARK: - AI Layer Stacks

    /// AI layer stacks dictionary keyed by asset ID
    @Published var aiLayerStacks: [UUID: AILayerStack] = [:]

    /// AI edit history keyed by photo asset URL.
    @Published var aiEditsByURL: [URL: [AIEdit]] = [:]

    /// Get or create AI layer stack for an asset
    func aiLayerStack(for assetId: UUID) -> AILayerStack {
        if let stack = aiLayerStacks[assetId] {
            return stack
        }
        let newStack = AILayerStack(documentId: assetId)
        aiLayerStacks[assetId] = newStack
        return newStack
    }

    /// Current AI layer stack for selected photo
    var currentAILayerStack: AILayerStack? {
        guard let id = selectedAssetId else { return nil }
        return aiLayerStack(for: id)
    }

    // MARK: - Mask Painting Mode

    /// Whether mask painting mode is active (for region-based AI generation)
    @Published var maskPaintingMode: Bool = false

    /// Current brush mask for region editing
    @Published var currentBrushMask: BrushMask = BrushMask()

    /// Clear mask and exit painting mode
    func exitMaskPaintingMode() {
        maskPaintingMode = false
        currentBrushMask.clear()
    }

    /// Current recipe for selected photo (convenience computed property)
    var currentRecipe: EditRecipe {
        get {
            guard let id = selectedAssetId else { return EditRecipe() }
            return recipes[id] ?? EditRecipe()
        }
        set {
            guard let id = selectedAssetId else { return }
            recipes[id] = newValue
        }
    }
    
    // MARK: - Local Adjustments

    /// Local adjustment nodes keyed by photo asset URL
    @Published var localNodes: [URL: [ColorNode]] = [:]

    /// Which node's mask is being edited (nil = none)
    @Published var editingMaskId: UUID? = nil

    /// Whether to show mask overlay in SingleView
    @Published var showMaskOverlay: Bool = false

    /// Local nodes for the currently selected photo
    var currentLocalNodes: [ColorNode] {
        guard let url = selectedAsset?.url else { return [] }
        return localNodes[url] ?? []
    }

    /// AI edits for the currently selected photo.
    var currentAIEdits: [AIEdit] {
        guard let url = selectedAsset?.url else { return [] }
        return aiEditsByURL[url] ?? []
    }

    /// Unified render context builder shared by preview/export call sites.
    func makeRenderContext(
        for asset: PhotoAsset,
        recipe: EditRecipe? = nil,
        localNodes: [ColorNode]? = nil
    ) -> RenderContext {
        RenderContext(
            assetId: asset.id,
            recipe: recipe ?? recipes[asset.id] ?? EditRecipe(),
            localNodes: localNodes ?? self.localNodes[asset.url] ?? [],
            aiLayers: aiLayerStacks[asset.id]?.layers ?? [],
            aiEdits: aiEditsByURL[asset.url] ?? []
        )
    }

    /// Update in-memory AI edits for an asset so preview/export contexts refresh immediately.
    func setAIEdits(_ edits: [AIEdit], for assetURL: URL) {
        aiEditsByURL[assetURL] = edits
    }

    /// Update in-memory AI layers for an asset while preserving observable stack identity.
    func setAILayers(_ layers: [AILayer], for assetId: UUID) {
        if layers.isEmpty {
            aiLayerStacks.removeValue(forKey: assetId)
            return
        }

        if let existing = aiLayerStacks[assetId] {
            existing.layers = layers
        } else {
            aiLayerStacks[assetId] = AILayerStack(documentId: assetId, layers: layers)
        }
    }

    /// Add a new local adjustment node for the current photo
    func addLocalNode(_ node: ColorNode) {
        editStateCoordinator.addLocalNode(node)
    }

    /// Remove a local node by id for the current photo
    func removeLocalNode(id: UUID) {
        editStateCoordinator.removeLocalNode(id: id)
    }

    /// Update a local node's adjustments or mask
    func updateLocalNode(_ node: ColorNode) {
        editStateCoordinator.updateLocalNode(node)
    }

    // MARK: - Memory Card & Auto Export
    
    @Published var autoExportEnabled: Bool = false
    @Published var autoExportDestination: URL?
    @Published var monitoredVolumes: [URL] = []
    
    // MARK: - Filters (with caching)
    
    /// Combined filter state for efficient cache invalidation
    struct FilterState: Equatable {
        var rating: Int = 0
        var color: ColorLabel? = nil
        var flag: Flag? = nil
        var tag: String = ""
        var recentImportsEnabled: Bool = false
        var recentImportsDays: Int = 0
    }

    @Published var isRecentImportsMode: Bool = false {
        didSet { invalidateFilterCache() }
    }
    var recentImportsWindowDays: Int = 7
    
    @Published var filterRating: Int = 0 {
        didSet { invalidateFilterCache() }
    }
    @Published var filterColor: ColorLabel? = nil {
        didSet { invalidateFilterCache() }
    }
    @Published var filterFlag: Flag? = nil {
        didSet { invalidateFilterCache() }
    }
    @Published var filterTag: String = "" {
        didSet { invalidateFilterCache() }
    }
    
    // Cache for filtered results
    private var cachedFilteredAssets: [PhotoAsset]?
    private var lastFilterState: FilterState?
    private var lastRecipesCount: Int = 0
    private var lastAssetsCount: Int = 0
    
    private func invalidateFilterCache() {
        cachedFilteredAssets = nil
    }
    
    // MARK: - Sorting
    
    /// Photo sorting criteria
    enum SortCriteria: String, CaseIterable, Codable {
        case filename = "Filename"
        case captureDate = "Capture Date"
        case modificationDate = "Modified Date"
        case fileSize = "File Size"
        case fileType = "File Type"
        case rating = "Rating"
        
        var icon: String {
            switch self {
            case .filename: return "textformat"
            case .captureDate: return "calendar"
            case .modificationDate: return "clock"
            case .fileSize: return "externaldrive"
            case .fileType: return "doc"
            case .rating: return "star"
            }
        }
    }
    
    /// Sort order
    enum SortOrder: String, CaseIterable {
        case ascending = "Ascending"
        case descending = "Descending"
        
        var icon: String {
            switch self {
            case .ascending: return "arrow.up"
            case .descending: return "arrow.down"
            }
        }
    }
    
    @Published var sortCriteria: SortCriteria = .captureDate {
        didSet { invalidateFilterCache() }
    }
    @Published var sortOrder: SortOrder = .descending {
        didSet { invalidateFilterCache() }
    }
    
    /// Filtered and sorted assets (with caching)
    var filteredAssets: [PhotoAsset] {
        // Check if cache is valid
        let currentFilterState = FilterState(
            rating: filterRating,
            color: filterColor,
            flag: filterFlag,
            tag: filterTag,
            recentImportsEnabled: isRecentImportsMode,
            recentImportsDays: recentImportsWindowDays
        )
        
        if let cached = cachedFilteredAssets,
           lastFilterState == currentFilterState,
           lastRecipesCount == recipes.count,
           lastAssetsCount == assets.count {
            return cached
        }
        
        // Recompute
        let result = computeFilteredAssets()
        cachedFilteredAssets = result
        lastFilterState = currentFilterState
        lastRecipesCount = recipes.count
        lastAssetsCount = assets.count
        return result
    }
    
    /// Compute filtered and sorted assets
    private func computeFilteredAssets() -> [PhotoAsset] {
        let filteredByControls = assets.filter { asset in
            let recipe = recipes[asset.id] ?? EditRecipe()
            
            // Rating filter
            if filterRating > 0 && recipe.rating < filterRating {
                return false
            }
            
            // Color filter
            if let color = filterColor, recipe.colorLabel != color {
                return false
            }
            
            // Flag filter
            if let flag = filterFlag, recipe.flag != flag {
                return false
            }
            
            // Tag filter
            if !filterTag.isEmpty {
                let hasTag = recipe.tags.contains { $0.localizedCaseInsensitiveContains(filterTag) }
                if !hasTag { return false }
            }
            
            return true
        }

        let sorted = sortAssets(filteredByControls)
        let libraryScopedAssets: [PhotoAsset]
        if isRecentImportsMode {
            let cutoff = Calendar.current.date(
                byAdding: .day,
                value: -recentImportsWindowDays,
                to: Date()
            ) ?? .distantPast
            libraryScopedAssets = sorted.filter { asset in
                guard let captureDate = asset.metadata?.dateTime ?? asset.creationDate ?? asset.modificationDate else {
                    return false
                }
                return captureDate >= cutoff
            }
        } else {
            libraryScopedAssets = sorted
        }

        // Apply active Smart Collection on top of control-based filters and sorting.
        if let collection = activeSmartCollection {
            return collection.filter(assets: libraryScopedAssets, recipes: recipes)
        }

        return libraryScopedAssets
    }
    
    /// Sort assets according to current criteria and order
    private func sortAssets(_ assets: [PhotoAsset]) -> [PhotoAsset] {
        let sorted = assets.sorted { a, b in
            let comparison: Bool
            switch sortCriteria {
            case .filename:
                comparison = a.filename.localizedCompare(b.filename) == .orderedAscending
            case .captureDate:
                let dateA = a.metadata?.dateTime ?? a.creationDate ?? .distantPast
                let dateB = b.metadata?.dateTime ?? b.creationDate ?? .distantPast
                comparison = dateA < dateB
            case .modificationDate:
                let dateA = a.modificationDate ?? .distantPast
                let dateB = b.modificationDate ?? .distantPast
                comparison = dateA < dateB
            case .fileSize:
                comparison = a.fileSize < b.fileSize
            case .fileType:
                comparison = a.fileExtension < b.fileExtension
            case .rating:
                let ratingA = recipes[a.id]?.rating ?? 0
                let ratingB = recipes[b.id]?.rating ?? 0
                comparison = ratingA < ratingB
            }
            return comparison
        }
        return sortOrder == .ascending ? sorted : sorted.reversed()
    }
    
    /// Clear all filters
    func clearFilters() {
        filterRating = 0
        filterColor = nil
        filterFlag = nil
        filterTag = ""
        exifFilter = nil
    }
    
    // MARK: - EXIF Filtering
    
    /// Current EXIF filter
    @Published var exifFilter: EXIFFilter?
    
    /// EXIF filter configuration
    struct EXIFFilter {
        var field: EXIFSearchField
        var exactValue: Any?
        var rangeStart: Any?
        var rangeEnd: Any?
        var gpsCenter: (lat: Double, lon: Double)?
        var gpsRadius: Double?  // in kilometers
        
        func matches(exif: EXIFData?) -> Bool {
            guard let exif = exif else { return false }
            
            switch field {
            case .cameraMake:
                guard let target = exactValue as? String else { return true }
                return exif.cameraMake == target
                
            case .cameraModel:
                guard let target = exactValue as? String else { return true }
                return exif.cameraModel == target
                
            case .lens:
                guard let target = exactValue as? String else { return true }
                return exif.lens == target || exif.lensModel == target
                
            case .iso:
                if let exact = exactValue as? Int {
                    return exif.iso == exact
                }
                if let start = rangeStart as? Int, let end = rangeEnd as? Int {
                    guard let iso = exif.iso else { return false }
                    return iso >= start && iso <= end
                }
                return true
                
            case .aperture:
                if let exact = exactValue as? Double {
                    guard let f = exif.aperture else { return false }
                    return abs(f - exact) < 0.1
                }
                if let start = rangeStart as? Double, let end = rangeEnd as? Double {
                    guard let f = exif.aperture else { return false }
                    return f >= start && f <= end
                }
                return true
                
            case .shutterSpeed:
                guard let exact = exactValue as? Double, let s = exif.shutterSpeed else { return true }
                return abs(s - exact) < 0.001
                
            case .focalLength:
                guard let exact = exactValue as? Double, let fl = exif.focalLength else { return true }
                return abs(fl - exact) < 1.0
                
            case .dateTimeOriginal:
                if let start = rangeStart as? Date, let end = rangeEnd as? Date {
                    guard let date = exif.dateTimeOriginal else { return false }
                    return date >= start && date < end
                }
                return true
                
            case .gpsLocation:
                guard let center = gpsCenter, let radius = gpsRadius else { return true }
                guard let lat = exif.gpsLatitude, let lon = exif.gpsLongitude else { return false }
                let distance = haversineDistance(lat1: center.lat, lon1: center.lon, lat2: lat, lon2: lon)
                return distance <= radius
            }
        }
        
        // Calculate distance between two GPS points in km
        private func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
            let R = 6371.0 // Earth radius in km
            let dLat = (lat2 - lat1) * .pi / 180
            let dLon = (lon2 - lon1) * .pi / 180
            let a = sin(dLat/2) * sin(dLat/2) +
                    cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
                    sin(dLon/2) * sin(dLon/2)
            let c = 2 * atan2(sqrt(a), sqrt(1-a))
            return R * c
        }
    }
    
    /// Set EXIF filter with exact value
    func setEXIFFilter<T>(field: EXIFSearchField, value: T?, mode: EXIFSearchMode = .exact) {
        guard value != nil else { return }
        exifFilter = EXIFFilter(field: field, exactValue: value)
    }
    
    /// Set EXIF filter with range
    func setEXIFFilter<T: Comparable>(field: EXIFSearchField, range: ClosedRange<T>) {
        exifFilter = EXIFFilter(field: field, rangeStart: range.lowerBound, rangeEnd: range.upperBound)
    }
    
    /// Set EXIF filter for GPS location
    func setEXIFFilter(field: EXIFSearchField, location: (lat: Double, lon: Double), radius: Double) {
        exifFilter = EXIFFilter(field: field, gpsCenter: location, gpsRadius: radius)
    }
    
    /// Cache for loaded EXIF data
    private var exifCache: [UUID: EXIFData] = [:]
    
    /// Get EXIF data for an asset (from cache or load)
    func getEXIF(for asset: PhotoAsset) async -> EXIFData? {
        if let cached = exifCache[asset.id] {
            return cached
        }
        if let exif = await EXIFService.shared.extractEXIF(from: asset.url) {
            exifCache[asset.id] = exif
            return exif
        }
        return nil
    }
    
    // MARK: - Computed Properties
    
    var selectedAsset: PhotoAsset? {
        guard let id = selectedAssetId else { return nil }
        return assets.first { $0.id == id }
    }
    
    var selectedIndex: Int? {
        guard let id = selectedAssetId else { return nil }
        return assets.firstIndex { $0.id == id }
    }
    
    var hasSelection: Bool {
        selectedAssetId != nil
    }

    /// Ensure there's a primary selected asset when entering single-view workflows.
    @discardableResult
    func ensurePrimarySelection() -> Bool {
        selectionCoordinator.ensurePrimarySelection()
    }

    /// Switch to single view and auto-select the first available photo when needed.
    @discardableResult
    func switchToSingleViewIfPossible(showFeedback: Bool = true) -> Bool {
        selectionCoordinator.switchToSingleViewIfPossible(showFeedback: showFeedback)
    }
    
    // MARK: - AI Culling

    /// Run AI culling on all currently loaded assets.
    /// Updates each asset's `rating` and `flag` in-place and saves to sidecar.
    func startAICulling() async {
        guard !assets.isEmpty, !cullingProgress.isRunning else { return }

        cullingAutoHideTask?.cancel()
        cullingProgress = .running(completed: 0, total: assets.count * 2)

        let currentAssets = assets
        let results = await CullingService.shared.score(assets: currentAssets) { [weak self] done, total in
            Task { @MainActor [weak self] in
                self?.cullingProgress = .running(completed: done, total: total)
            }
        }

        await applyCullingResults(results)

        cullingProgress = .complete(scored: results.count)

        // Auto-hide the completion badge after 4 seconds.
        cullingAutoHideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.cullingProgress = .idle }
        }
    }

    private func applyCullingResults(_ results: [UUID: CullingScore]) async {
        for asset in assets {
            guard let score = results[asset.id] else { continue }
            var recipe = recipes[asset.id] ?? EditRecipe()
            recipe.rating = score.suggestedRating
            recipe.flag   = score.suggestedFlag
            recipes[asset.id] = recipe
            // Persist asynchronously (debounced via SidecarService).
            await SidecarService.shared.saveRecipe(
                recipe,
                snapshots: snapshots[asset.id] ?? [],
                for: asset.url
            )
        }
    }

    // MARK: - Smart Sync

    /// Find visually similar scenes and stage adapted recipes for user confirmation.
    ///
    /// Populates `smartSyncMatches` and sets `showSmartSyncSheet = true`.
    /// No recipes are saved until the user confirms in the sheet.
    func startSmartSync() async {
        guard let source = selectedAsset else { return }
        guard !smartSyncState.isRunning else { return }

        smartSyncAutoHideTask?.cancel()
        let total = assets.count
        smartSyncState = .indexing(completed: 0, total: total)

        let currentAssets = assets
        let sourceRecipe  = recipes[source.id] ?? EditRecipe()

        let matches = await SmartSyncService.shared.findAndAdapt(
            source: source,
            sourceRecipe: sourceRecipe,
            candidates: currentAssets,
            onProgress: { [weak self] done, total in
                Task { @MainActor [weak self] in
                    self?.smartSyncState = .indexing(completed: done, total: total)
                }
            }
        )

        smartSyncMatches  = matches
        showSmartSyncSheet = !matches.isEmpty

        if matches.isEmpty {
            smartSyncState = .complete(synced: 0)
            scheduleSmartSyncAutoHide()
        } else {
            smartSyncState = .idle   // Sheet is now showing; reset progress bar.
        }
    }

    /// Apply confirmed Smart Sync matches — write adapted recipes and save sidecars.
    ///
    /// Call this from the confirmation sheet's "Apply" button.
    func applySmartSync(selections: [SmartSyncMatch]) async {
        showSmartSyncSheet = false
        for match in selections {
            var recipe = match.adaptedRecipe
            recipes[match.id] = recipe
            if let asset = assets.first(where: { $0.id == match.id }) {
                await SidecarService.shared.saveRecipe(
                    recipe,
                    snapshots: snapshots[match.id] ?? [],
                    for: asset.url
                )
            }
        }
        smartSyncMatches = []
        smartSyncState   = .complete(synced: selections.count)
        scheduleSmartSyncAutoHide()
    }

    private func scheduleSmartSyncAutoHide() {
        smartSyncAutoHideTask?.cancel()
        smartSyncAutoHideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.smartSyncState = .idle }
        }
    }

    // MARK: - Actions

    func select(
        _ asset: PhotoAsset,
        switchToSingleView: Bool = true,
        loadSidecarImmediately: Bool = true
    ) {
        let isSwitchingAsset = selectedAssetId != asset.id
        // Save and flush current recipe before switching.
        flushPendingRecipeSave()

        // Reset mask editing state when switching asset.
        if isSwitchingAsset {
            editingMaskId = nil
            showMaskOverlay = false
        }

        selectedAssetId = asset.id

        if loadSidecarImmediately {
            // Load recipe from sidecar if not already in memory (may have been prefetched).
            if recipes[asset.id] == nil || aiEditsByURL[asset.url] == nil || localNodes[asset.url] == nil || aiLayerStacks[asset.id] == nil {
                Task { [weak self] in
                    guard let self else { return }
                    if let state = await SidecarService.shared.loadRenderState(for: asset.url) {
                        await MainActor.run {
                            // Only update if this asset is still selected.
                            guard self.selectedAssetId == asset.id else { return }
                            if self.recipes[asset.id] == nil {
                                self.recipes[asset.id] = state.recipe
                                self.snapshots[asset.id] = state.snapshots
                            }
                            self.localNodes[asset.url] = state.localNodes
                            self.aiEditsByURL[asset.url] = state.aiEdits
                            self.setAILayers(state.aiLayers, for: asset.id)
                            self.objectWillChange.send()
                        }
                    }
                }
            }
        }

        // Switch view mode after recipe is set up
        // This ensures SingleView has data available immediately
        if switchToSingleView {
            viewMode = .single
        }
    }
    
    func updateRecipe(_ recipe: EditRecipe) {
        guard let id = selectedAssetId else { return }
        recipes[id] = recipe
        saveCurrentRecipe()
    }
    
    private struct RecipeSavePayload {
        let asset: PhotoAsset
        let recipe: EditRecipe
        let snapshots: [RecipeSnapshot]
        let nodes: [ColorNode]?
        let aiLayers: [AILayer]?
    }

    private func currentRecipeSavePayload() -> RecipeSavePayload? {
        guard let asset = selectedAsset else { return nil }
        return RecipeSavePayload(
            asset: asset,
            recipe: recipes[asset.id] ?? EditRecipe(),
            snapshots: snapshots[asset.id] ?? [],
            nodes: localNodes[asset.url],
            aiLayers: aiLayerStacks[asset.id]?.layers
        )
    }

    private func persistRecipe(_ payload: RecipeSavePayload) async {
        // Use save(recipe:localNodes:aiLayers:for:) so localNodes and AI layers persist with recipe.
        // This method preserves existing sidecar fields (snapshots, AI edits) by reading
        // the current sidecar before writing. Falls back to the debounced path for snapshots.
        do {
            try await SidecarService.shared.save(
                recipe: payload.recipe,
                localNodes: payload.nodes,
                aiLayers: payload.aiLayers,
                for: payload.asset.url
            )
        } catch {
            print("[AppState] save(recipe:localNodes:aiLayers:) failed: \(error) — local nodes/AI layers will NOT be persisted in fallback path.")
            await SidecarService.shared.saveRecipe(payload.recipe, snapshots: payload.snapshots, for: payload.asset.url)
        }
    }

    func saveCurrentRecipe() {
        pendingRecipeSaveTask?.cancel()
        pendingRecipeSaveTask = nil
        guard let payload = currentRecipeSavePayload() else { return }
        pendingRecipeSavePayloads[payload.asset.id] = nil
        Task {
            await persistRecipe(payload)
        }
    }

    func saveCurrentRecipeDebounced() {
        pendingRecipeSaveTask?.cancel()
        guard let payload = currentRecipeSavePayload() else { return }
        pendingRecipeSavePayloads[payload.asset.id] = payload
        pendingRecipeSaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            self?.flushPendingRecipeSave()
        }
    }

    private func consumePendingRecipeSavePayloads() -> [RecipeSavePayload] {
        pendingRecipeSaveTask?.cancel()
        pendingRecipeSaveTask = nil

        var payloads = pendingRecipeSavePayloads
        pendingRecipeSavePayloads.removeAll()

        // Ensure current in-memory state is also flushed even if it wasn't queued.
        if let current = currentRecipeSavePayload() {
            payloads[current.asset.id] = current
        }

        return Array(payloads.values)
    }

    func flushPendingRecipeSave() {
        let payloads = consumePendingRecipeSavePayloads()
        guard !payloads.isEmpty else { return }
        Task {
            for payload in payloads {
                await persistRecipe(payload)
            }
        }
    }

    /// Flush pending recipe writes and await completion (lifecycle-safe path).
    func flushPendingRecipeSaveAndWait() async {
        let payloads = consumePendingRecipeSavePayloads()
        for payload in payloads {
            await persistRecipe(payload)
        }
        await SidecarService.shared.flushPendingDebouncedSaves()
    }
    
    // MARK: - Undo/Redo Actions
    
    func pushHistory(_ recipe: EditRecipe) {
        guard let id = selectedAssetId else { return }
        var h = history[id] ?? HistoryStack()
        h.push(recipe)
        history[id] = h
    }
    
    func undo() {
        guard let id = selectedAssetId else { return }
        var h = history[id] ?? HistoryStack()
        if let previous = h.undo(current: recipes[id] ?? EditRecipe()) {
            recipes[id] = previous
            history[id] = h
            saveCurrentRecipe()
            objectWillChange.send()
        }
    }
    
    func redo() {
        guard let id = selectedAssetId else { return }
        var h = history[id] ?? HistoryStack()
        if let next = h.redo(current: recipes[id] ?? EditRecipe()) {
            recipes[id] = next
            history[id] = h
            saveCurrentRecipe()
            objectWillChange.send()
        }
    }
    
    // MARK: - Persistent Snapshots (Versions)
    
    @Published var snapshots: [UUID: [RecipeSnapshot]] = [:]
    
    func createSnapshot(name: String) {
        guard let id = selectedAssetId else { return }
        let recipe = recipes[id] ?? EditRecipe()
        let snapshot = RecipeSnapshot(name: name, recipe: recipe)
        var list = snapshots[id] ?? []
        list.append(snapshot)
        snapshots[id] = list
        saveCurrentRecipe()
    }
    
    func applySnapshot(_ snapshot: RecipeSnapshot) {
        guard let id = selectedAssetId else { return }
        pushHistory(recipes[id] ?? EditRecipe())
        recipes[id] = snapshot.recipe
        saveCurrentRecipe()
    }
    
    func deleteSnapshot(_ snapshot: RecipeSnapshot) {
        guard let id = selectedAssetId else { return }
        snapshots[id]?.removeAll(where: { $0.id == snapshot.id })
        saveCurrentRecipe()
    }
    
    // MARK: - Navigation Helpers
    
    func selectNext() {
        guard let currentIndex = selectedIndex else { return }
        let nextIndex = min(currentIndex + 1, assets.count - 1)
        if let nextAsset = assets[safe: nextIndex] {
            select(nextAsset)
        }
    }
    
    func selectPrevious() {
        guard let currentIndex = selectedIndex else { return }
        let prevIndex = max(currentIndex - 1, 0)
        if let prevAsset = assets[safe: prevIndex] {
            select(prevAsset)
        }
    }
    
    // MARK: - HUD Notifications
    
    @Published var hudMessage: String?
    private var hudTask: Task<Void, Never>?
    
    func showHUD(_ message: String) {
        hudMessage = message
        hudTask?.cancel()
        hudTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
            guard !Task.isCancelled else { return }
            hudMessage = nil
        }
    }
    
    func getRecipe(for asset: PhotoAsset) -> EditRecipe {
        return recipes[asset.id] ?? EditRecipe()
    }
    
    func clearSelection() {
        selectionCoordinator.clearSelection()
    }
    
    /// Load all recipes from sidecars for current folder (parallel with concurrency limit)
    func loadAllRecipes(expectedFolderPath: String? = nil, excludingAssetId: UUID? = nil) async {
        guard isAssetLoadContextValid(expectedFolderPath: expectedFolderPath) else { return }
        let clock = ContinuousClock()
        let phaseStart = clock.now
        let signpostId = PerformanceSignposts.signposter.makeSignpostID()
        let signpostState = PerformanceSignposts.begin("sidecarLoadAll", id: signpostId)
        var phaseStatus = "done"
        var shouldAbort = false
        e2eSidecarLoadState = "running"
        e2eSidecarLoadedCount = 0
        e2eSidecarLoadMs = 0
        e2eSidecarLoadUs = 0
        defer {
            PerformanceSignposts.end("sidecarLoadAll", signpostState)
            if isAssetLoadContextValid(expectedFolderPath: expectedFolderPath) {
                if phaseStatus == "done" {
                    let duration = phaseStart.duration(to: clock.now)
                    e2eSidecarLoadUs = durationMicroseconds(duration)
                    e2eSidecarLoadMs = max(1, e2eSidecarLoadUs / 1_000)
                }
                e2eSidecarLoadState = phaseStatus
            }
        }

        let assetsCopy = assets.filter { $0.id != excludingAssetId }  // Capture for background processing
        let plannedAssets = tunedSidecarLoadAssets(assetsCopy, preferredAssetId: selectedAssetId)
        guard !plannedAssets.isEmpty else {
            loadingMessage = ""
            return
        }

        let totalCount = plannedAssets.count
        var loadedCount = 0
        
        // Update loading message
        loadingMessage = "Loading edits..."
        
        // Parallel loading with concurrency limit
        await withTaskGroup(of: (UUID, URL, SidecarService.RenderState?).self) { group in
            var pending = 0
            let maxConcurrent = Self.sidecarLoadConcurrency(forAssetCount: plannedAssets.count)
            
            for asset in plannedAssets {
                if Task.isCancelled || !isAssetLoadContextValid(expectedFolderPath: expectedFolderPath) {
                    shouldAbort = true
                    group.cancelAll()
                    break
                }

                // If at max concurrency, wait for one to finish
                if pending >= maxConcurrent {
                    if let result = await group.next() {
                        if Task.isCancelled || !isAssetLoadContextValid(expectedFolderPath: expectedFolderPath) {
                            shouldAbort = true
                            group.cancelAll()
                            break
                        }

                        if let state = result.2 {
                            recipes[result.0] = state.recipe
                            localNodes[result.1] = state.localNodes
                            aiEditsByURL[result.1] = state.aiEdits
                            setAILayers(state.aiLayers, for: result.0)
                        } else {
                            localNodes[result.1] = []
                            aiEditsByURL[result.1] = []
                            setAILayers([], for: result.0)
                        }
                        loadedCount += 1
                        e2eSidecarLoadedCount = loadedCount
                        pending -= 1
                    }
                }
                
                group.addTask { [url = asset.url, id = asset.id] in
                    guard !Task.isCancelled else { return (id, url, nil) }
                    let state = await SidecarService.shared.loadRenderState(for: url)
                    guard !Task.isCancelled else { return (id, url, nil) }
                    return (id, url, state)
                }
                pending += 1
            }
            
            if !shouldAbort {
                // Collect remaining results
                for await result in group {
                    if Task.isCancelled || !isAssetLoadContextValid(expectedFolderPath: expectedFolderPath) {
                        shouldAbort = true
                        group.cancelAll()
                        break
                    }

                    if let state = result.2 {
                        recipes[result.0] = state.recipe
                        localNodes[result.1] = state.localNodes
                        aiEditsByURL[result.1] = state.aiEdits
                        setAILayers(state.aiLayers, for: result.0)
                    } else {
                        localNodes[result.1] = []
                        aiEditsByURL[result.1] = []
                        setAILayers([], for: result.0)
                    }
                    loadedCount += 1
                    e2eSidecarLoadedCount = loadedCount
                    
                    // Update progress periodically with a larger step for big folders.
                    let progressStep = max(10, totalCount / 20)
                    if loadedCount % progressStep == 0 {
                        loadingMessage = "Loading edits... \(loadedCount)/\(totalCount)"
                    }
                }
            }
        }

        if shouldAbort || Task.isCancelled || !isAssetLoadContextValid(expectedFolderPath: expectedFolderPath) {
            phaseStatus = "cancelled"
            loadingMessage = ""
            return
        }
        e2eSidecarLoadedCount = loadedCount
        loadingMessage = ""
    }
    
    /// Prefetch adjacent photos for faster navigation
    func prefetchAdjacent() {
        guard let currentIndex = selectedIndex else { return }

        // Prefetch N-1, N+1, N+2 in background
        let indicesToPrefetch = [currentIndex - 1, currentIndex + 1, currentIndex + 2]

        Task {
            for index in indicesToPrefetch {
                guard let asset = await MainActor.run(body: { self.assets[safe: index] }) else { continue }
                let recipe = await MainActor.run(body: { self.recipes[asset.id] ?? EditRecipe() })
                let renderContext = await MainActor.run {
                    self.makeRenderContext(for: asset, recipe: recipe)
                }

                // Prefetch at low resolution for fast loading
                _ = await ImagePipeline.shared.renderPreview(
                    for: asset,
                    context: renderContext,
                    maxSize: 800
                )
            }
        }
    }

    /// Prefetch a photo for SingleView (called on selection in GridView)
    /// Pre-loads the recipe so double-click transition doesn't need to wait for sidecar I/O
    func prefetchForSingleView(_ asset: PhotoAsset) {
        // Only load recipe from sidecar if not already in memory
        // (Image rendering is handled by ImagePipeline cache in SingleView)
        guard recipes[asset.id] == nil || aiEditsByURL[asset.url] == nil || localNodes[asset.url] == nil || aiLayerStacks[asset.id] == nil else { return }

        Task {
            if let state = await SidecarService.shared.loadRenderState(for: asset.url) {
                await MainActor.run {
                    // Only set if still nil (avoid race conditions)
                    if self.recipes[asset.id] == nil {
                        self.recipes[asset.id] = state.recipe
                        self.snapshots[asset.id] = state.snapshots
                    }
                    self.localNodes[asset.url] = state.localNodes
                    self.aiEditsByURL[asset.url] = state.aiEdits
                    self.setAILayers(state.aiLayers, for: asset.id)
                }
            }
        }
    }
    
    @discardableResult
    func openFolderFromPicker() async -> Bool {
        guard let url = FileSystemService.selectFolder() else { return false }
        return await openFolder(at: url, registerInFolderHistory: true)
    }

    @discardableResult
    func openFolder(at url: URL, registerInFolderHistory: Bool = true) async -> Bool {
        await openFolderFromPath(url.path, registerInFolderHistory: registerInFolderHistory)
    }

    /// Open folder from path string
    @discardableResult
    func openFolderFromPath(_ path: String, registerInFolderHistory: Bool = true) async -> Bool {
        let expandedPath = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath).standardizedFileURL
        let clock = ContinuousClock()
        let start = clock.now
        let signpostId = PerformanceSignposts.signposter.makeSignpostID()
        let signpostState = PerformanceSignposts.begin("folderToFirstSelection", id: signpostId)
        let scanSignpostId = PerformanceSignposts.signposter.makeSignpostID()
        let scanSignpostState = PerformanceSignposts.begin("folderScanPhase", id: scanSignpostId)
        var didFinishFirstSelectionSignpost = false
        var didFinishScanSignpost = false

        defer {
            if !didFinishFirstSelectionSignpost {
                PerformanceSignposts.end("folderToFirstSelection", signpostState)
            }
            if !didFinishScanSignpost {
                PerformanceSignposts.end("folderScanPhase", scanSignpostState)
            }
        }
        
        // Check if path exists and is directory
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            print("[AppState] Invalid path: \(url.path)")
            return false
        }

        if registerInFolderHistory {
            _ = folderManager.addFolder(url)
        }
        guard folderManager.beginAccess(for: url) else {
            print("[AppState] Cannot access folder: \(url.path)")
            return false
        }

        // Lifecycle hardening: ensure debounced recipe/sidecar writes are fully persisted
        // before we switch folder context and cancel background loaders.
        await flushPendingRecipeSaveAndWait()

        cancelBackgroundAssetLoading(resetThumbnailProgress: true)
        resetE2EPhaseMetrics()
        selectedFolder = url
        isLoading = true
        loadingMessage = "Scanning folder..."
        
        do {
            let scanStart = clock.now
            let scannedAssets = try await FileSystemService.scanFolder(url)
            e2eScanPhaseMs = durationMilliseconds(scanStart.duration(to: clock.now))
            PerformanceSignposts.end("folderScanPhase", scanSignpostState)
            didFinishScanSignpost = true
            assets = scannedAssets
            recipes = [:]
            snapshots = [:]
            localNodes = [:]
            aiLayerStacks = [:]
            aiEditsByURL = [:]

            // Select the first asset immediately so view switching/shortcuts work while edits load.
            if let first = scannedAssets.first {
                select(first, switchToSingleView: false, loadSidecarImmediately: false)
                e2eFirstSelectionLatencyMs = durationMilliseconds(start.duration(to: clock.now))
            } else {
                e2eFirstSelectionLatencyMs = 0
            }
            PerformanceSignposts.end("folderToFirstSelection", signpostState)
            didFinishFirstSelectionSignpost = true
            isLoading = false
            loadingMessage = ""
            
            // Save folder state for incremental scanning
            let state = FileSystemService.buildFolderState(for: url, assets: scannedAssets)
            FileSystemService.saveFolderState(state, for: url)

            if let source = folderManager.source(for: url) {
                folderManager.updateFolderState(source.id, isLoaded: true, assetCount: scannedAssets.count)
            }

            // Continue sidecar/thumbnails in cancellable background tasks.
            schedulePostScanBackgroundWork(expectedFolder: url)
            return true
        } catch {
            e2eScanPhaseMs = 0
            isLoading = false
            loadingMessage = ""
            print("[AppState] Error scanning: \(error)")
            return false
        }
    }

    /// E2E-only synthetic slider interaction workload for signpost measurement.
    func runE2ESliderStress() async {
        guard ProcessInfo.processInfo.environment["RAWCTL_E2E_STATUS"] == "1" else { return }
        guard e2eSliderStressState != "running" else { return }
        guard ensurePrimarySelection(), let id = selectedAssetId else {
            e2eSliderStressState = "no-selection"
            return
        }

        viewMode = .single
        transformMode = false
        let baseline = recipes[id] ?? EditRecipe()

        e2eSliderStressState = "running"
        let signpostId = PerformanceSignposts.signposter.makeSignpostID()
        let signpostState = PerformanceSignposts.begin("sliderStress", id: signpostId)
        defer {
            recipes[id] = baseline
            e2eSliderStressState = "done"
            PerformanceSignposts.end("sliderStress", signpostState)
        }

        NotificationCenter.default.post(name: .sliderDragStateChanged, object: true)

        let exposureSteps: [Double] = [-1.0, -0.5, 0.0, 0.75, 1.25, 0.25]
        for step in exposureSteps {
            var recipe = baseline
            recipe.exposure = step
            recipe.contrast = step * 28
            recipe.highlights = step * -20
            recipe.shadows = step * 16
            recipes[id] = recipe
            try? await Task.sleep(nanoseconds: 35_000_000)
        }

        NotificationCenter.default.post(name: .sliderDragStateChanged, object: false)
        try? await Task.sleep(nanoseconds: 450_000_000)
    }

    /// E2E helper: create/update one local radial node and enter local edit mode.
    func runE2ELocalAdjustmentSetup() {
        guard ProcessInfo.processInfo.environment["RAWCTL_E2E_STATUS"] == "1" else { return }
        guard ensurePrimarySelection(), let asset = selectedAsset else { return }

        var nodes = localNodes[asset.url] ?? []
        if nodes.isEmpty {
            var node = ColorNode(name: "E2E Local", type: .serial)
            node.mask = NodeMask(type: .radial(centerX: 0.5, centerY: 0.5, radius: 0.35))
            node.adjustments.exposure = 0.9
            node.adjustments.contrast = 12
            nodes.append(node)
        } else {
            nodes[0].adjustments.exposure = 0.9
            nodes[0].adjustments.contrast = 12
            if nodes[0].mask == nil {
                nodes[0].mask = NodeMask(type: .radial(centerX: 0.5, centerY: 0.5, radius: 0.35))
            }
        }

        localNodes[asset.url] = nodes
        if let first = nodes.first {
            editingMaskId = first.id
            showMaskOverlay = true
        }
        e2eLocalExportMatch = "idle"
        e2eLocalPreviewDiff = ""
        e2eLocalPreviewHash = ""
        e2eLocalExportHash = ""
        saveCurrentRecipeDebounced()
    }

    /// E2E helper: verify preview and export render paths produce equivalent local-node output.
    func runE2ELocalExportConsistencyCheck() async {
        guard ProcessInfo.processInfo.environment["RAWCTL_E2E_STATUS"] == "1" else { return }
        guard let asset = selectedAsset else {
            e2eLocalExportMatch = "error:no-selection"
            return
        }

        let recipe = recipes[asset.id] ?? EditRecipe()
        let nodes = localNodes[asset.url] ?? []
        let renderContext = makeRenderContext(
            for: asset,
            recipe: recipe,
            localNodes: nodes
        )
        e2eLocalExportMatch = "running"

        guard let preview = await ImagePipeline.shared.renderPreview(
            for: asset,
            context: renderContext,
            maxSize: 1200,
            fastMode: false
        ),
        let previewCG = cgImage(from: preview),
        let exportCG = await ImagePipeline.shared.renderForExport(
            for: asset,
            context: renderContext,
            maxSize: 1200
        ) else {
            e2eLocalExportMatch = "error:render"
            return
        }

        let diff = meanAbsoluteDifference(previewCG, exportCG)
        e2eLocalPreviewDiff = String(format: "%.5f", diff)
        e2eLocalPreviewHash = perceptualHash(of: previewCG)
        e2eLocalExportHash = perceptualHash(of: exportCG)
        e2eLocalExportMatch = diff < 0.018 ? "1" : "0"
    }

    func refreshSidecarWriteMetrics() async {
        let metrics = await SidecarService.shared.currentWriteMetrics()
        e2eSidecarWriteQueued = metrics.queued
        e2eSidecarWriteSkippedNoOp = metrics.skippedNoOp
        e2eSidecarWriteFlushed = metrics.flushed
        e2eSidecarWriteWritten = metrics.written
    }

    func resetE2ESidecarWriteMetrics() async {
        await SidecarService.shared.resetWriteMetrics()
        await refreshSidecarWriteMetrics()
    }

    private func cgImage(from image: NSImage) -> CGImage? {
        if let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return cg
        }
        guard let data = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: data) else {
            return nil
        }
        return rep.cgImage
    }

    private func meanAbsoluteDifference(_ lhs: CGImage, _ rhs: CGImage) -> Double {
        let repA = NSBitmapImageRep(cgImage: lhs)
        let repB = NSBitmapImageRep(cgImage: rhs)
        let width = min(repA.pixelsWide, repB.pixelsWide)
        let height = min(repA.pixelsHigh, repB.pixelsHigh)
        let step = max(1, min(width, height) / 64)

        var total = 0.0
        var count = 0
        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                guard let ca = repA.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                      let cb = repB.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                    continue
                }
                total += abs(Double(ca.redComponent - cb.redComponent))
                total += abs(Double(ca.greenComponent - cb.greenComponent))
                total += abs(Double(ca.blueComponent - cb.blueComponent))
                count += 3
            }
        }
        return count > 0 ? total / Double(count) : 0
    }

    private func perceptualHash(of image: CGImage) -> String {
        let rep = NSBitmapImageRep(cgImage: image)
        let sample = 8
        var values: [Double] = []
        values.reserveCapacity(sample * sample)

        for j in 0..<sample {
            for i in 0..<sample {
                let x = min(rep.pixelsWide - 1, Int(Double(i) / Double(sample - 1) * Double(max(1, rep.pixelsWide - 1))))
                let y = min(rep.pixelsHigh - 1, Int(Double(j) / Double(sample - 1) * Double(max(1, rep.pixelsHigh - 1))))
                if let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) {
                    let luma = 0.2126 * Double(c.redComponent) + 0.7152 * Double(c.greenComponent) + 0.0722 * Double(c.blueComponent)
                    values.append(luma)
                } else {
                    values.append(0)
                }
            }
        }

        let average = values.reduce(0, +) / Double(max(1, values.count))
        var bits = ""
        bits.reserveCapacity(values.count)
        for value in values {
            bits.append(value >= average ? "1" : "0")
        }
        return bits
    }

    private func durationMilliseconds(_ duration: Duration) -> Int {
        let components = duration.components
        let secondsMs = components.seconds * 1_000
        let attoMs = components.attoseconds / 1_000_000_000_000_000
        return Int(secondsMs + attoMs)
    }

    private func durationMicroseconds(_ duration: Duration) -> Int {
        let components = duration.components
        let secondsUs = components.seconds * 1_000_000
        let attoUs = components.attoseconds / 1_000_000_000_000
        return Int(secondsUs + attoUs)
    }

    static func sidecarLoadConcurrency(forAssetCount assetCount: Int) -> Int {
        switch assetCount {
        case ..<180:
            return 8
        case ..<700:
            return 6
        case ..<2_400:
            return 4
        default:
            return 3
        }
    }

    static func thumbnailPreloadConcurrency(forAssetCount assetCount: Int) -> Int {
        switch assetCount {
        case ..<220:
            return 6
        case ..<900:
            return 5
        case ..<2_800:
            return 4
        default:
            return 3
        }
    }

    static func sidecarPriorityWindowSize(forAssetCount assetCount: Int) -> Int {
        switch assetCount {
        case ..<320:
            return assetCount
        case ..<1_200:
            return 420
        case ..<3_200:
            return 280
        default:
            return 180
        }
    }

    static func thumbnailPreloadWindowSize(forAssetCount assetCount: Int) -> Int {
        switch assetCount {
        case ..<320:
            return assetCount
        case ..<1_200:
            return 360
        case ..<3_200:
            return 240
        default:
            return 160
        }
    }

    static func prioritizedAssetOrder(
        for assets: [PhotoAsset],
        preferredAssetId: UUID?,
        prioritizeWindowSize: Int,
        includeRemainder: Bool
    ) -> [PhotoAsset] {
        guard !assets.isEmpty else { return [] }

        let maxIndex = assets.count - 1
        let centerIndex = preferredAssetId.flatMap { id in
            assets.firstIndex(where: { $0.id == id })
        } ?? 0

        let clampedWindow = max(1, min(prioritizeWindowSize, assets.count))
        var lowerBound = max(0, centerIndex - clampedWindow / 2)
        var upperBound = min(maxIndex, centerIndex + clampedWindow / 2)
        while upperBound - lowerBound + 1 < clampedWindow {
            if lowerBound > 0 {
                lowerBound -= 1
            } else if upperBound < maxIndex {
                upperBound += 1
            } else {
                break
            }
        }

        let priorityIndices = centeredIndices(
            around: centerIndex,
            lowerBound: lowerBound,
            upperBound: upperBound,
            limit: clampedWindow
        )

        guard includeRemainder else {
            return priorityIndices.map { assets[$0] }
        }

        var orderedIndices = priorityIndices
        let used = Set(priorityIndices)
        for index in 0...maxIndex where !used.contains(index) {
            orderedIndices.append(index)
        }
        return orderedIndices.map { assets[$0] }
    }

    private static func centeredIndices(
        around centerIndex: Int,
        lowerBound: Int,
        upperBound: Int,
        limit: Int
    ) -> [Int] {
        guard limit > 0, lowerBound <= upperBound else { return [] }

        var indices: [Int] = []
        indices.reserveCapacity(limit)

        if centerIndex >= lowerBound && centerIndex <= upperBound {
            indices.append(centerIndex)
        } else {
            indices.append(lowerBound)
        }

        var distance = 1
        while indices.count < limit {
            let left = centerIndex - distance
            let right = centerIndex + distance
            var added = false

            if left >= lowerBound {
                indices.append(left)
                added = true
                if indices.count >= limit { break }
            }
            if right <= upperBound {
                indices.append(right)
                added = true
                if indices.count >= limit { break }
            }
            if !added { break }
            distance += 1
        }

        return indices
    }

    private func tunedSidecarLoadAssets(_ sourceAssets: [PhotoAsset], preferredAssetId: UUID?) -> [PhotoAsset] {
        guard !sourceAssets.isEmpty else { return [] }
        let windowSize = Self.sidecarPriorityWindowSize(forAssetCount: sourceAssets.count)
        return Self.prioritizedAssetOrder(
            for: sourceAssets,
            preferredAssetId: preferredAssetId,
            prioritizeWindowSize: windowSize,
            includeRemainder: true
        )
    }

    private func tunedThumbnailPreloadAssets(_ sourceAssets: [PhotoAsset], preferredAssetId: UUID?) -> [PhotoAsset] {
        guard !sourceAssets.isEmpty else { return [] }
        let windowSize = Self.thumbnailPreloadWindowSize(forAssetCount: sourceAssets.count)
        return Self.prioritizedAssetOrder(
            for: sourceAssets,
            preferredAssetId: preferredAssetId,
            prioritizeWindowSize: windowSize,
            includeRemainder: false
        )
    }

    private func removeAssetState(for removedAssets: [PhotoAsset]) {
        for asset in removedAssets {
            recipes.removeValue(forKey: asset.id)
            snapshots.removeValue(forKey: asset.id)
            aiLayerStacks.removeValue(forKey: asset.id)
            localNodes.removeValue(forKey: asset.url)
            aiEditsByURL.removeValue(forKey: asset.url)
        }
    }

    private func pruneDetachedAssetState() {
        let liveAssetIds = Set(assets.map(\.id))
        recipes = recipes.filter { liveAssetIds.contains($0.key) }
        snapshots = snapshots.filter { liveAssetIds.contains($0.key) }
        aiLayerStacks = aiLayerStacks.filter { liveAssetIds.contains($0.key) }

        let liveAssetURLs = Set(assets.map(\.url))
        localNodes = localNodes.filter { liveAssetURLs.contains($0.key) }
        aiEditsByURL = aiEditsByURL.filter { liveAssetURLs.contains($0.key) }

        if let selectedAssetId, !liveAssetIds.contains(selectedAssetId) {
            self.selectedAssetId = assets.first?.id
        }
    }
    
    /// Refresh current folder using incremental scanning (much faster than full rescan)
    func refreshCurrentFolder() async {
        guard let url = selectedFolder else { return }

        cancelBackgroundAssetLoading(resetThumbnailProgress: false)
        isLoading = true
        loadingMessage = "Checking file changes..."
        
        do {
            let cachedState = FileSystemService.loadFolderState(for: url)
            
            let result = try await FileSystemService.incrementalScan(
                url,
                previousAssets: assets,
                cachedState: cachedState
            )
            
            // Remove deleted/changed assets and their state before merging additions.
            removeAssetState(for: result.removed)
            let removedAssetIds = Set(result.removed.map(\.id))
            assets.removeAll { removedAssetIds.contains($0.id) }
            
            // Add new assets
            assets.append(contentsOf: result.added)
            
            // Sort
            assets.sort { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }
            pruneDetachedAssetState()
            
            // Load recipes only for new assets
            if !result.added.isEmpty {
                loadingMessage = "Loading new edits..."
                await loadRecipes(for: result.added)
            }
            
            // Update folder state
            let newState = FileSystemService.buildFolderState(for: url, assets: assets)
            FileSystemService.saveFolderState(newState, for: url)
            
            isLoading = false
            loadingMessage = ""
            invalidateFilterCache()
            
            print("[AppState] Refresh complete: \(result.added.count) added, \(result.removed.count) removed")
        } catch {
            isLoading = false
            loadingMessage = ""
            print("[AppState] Error refreshing: \(error)")
        }
    }
    
    /// Load recipes for specific assets only
    private func loadRecipes(for assetsToLoad: [PhotoAsset]) async {
        await withTaskGroup(of: (UUID, URL, SidecarService.RenderState?).self) { group in
            for asset in assetsToLoad {
                group.addTask { [url = asset.url, id = asset.id] in
                    let state = await SidecarService.shared.loadRenderState(for: url)
                    return (id, url, state)
                }
            }
            
            for await result in group {
                if let state = result.2 {
                    recipes[result.0] = state.recipe
                    snapshots[result.0] = state.snapshots
                    localNodes[result.1] = state.localNodes
                    aiEditsByURL[result.1] = state.aiEdits
                    setAILayers(state.aiLayers, for: result.0)
                } else {
                    localNodes[result.1] = []
                    aiEditsByURL[result.1] = []
                    setAILayers([], for: result.0)
                }
            }
        }
    }
    
    /// Preload all thumbnails for current folder in background
    func preloadThumbnails(expectedFolderPath: String? = nil) {
        thumbnailPreloadTask?.cancel()
        thumbnailPreloadTask = nil
        thumbnailAutoHideTask?.cancel()
        thumbnailAutoHideTask = nil

        guard isAssetLoadContextValid(expectedFolderPath: expectedFolderPath) else { return }

        let assetsCopy = assets
        let preloadAssets = tunedThumbnailPreloadAssets(assetsCopy, preferredAssetId: selectedAssetId)
        guard !preloadAssets.isEmpty else {
            thumbnailLoadingProgress = .idle
            e2eThumbnailPreloadState = "idle"
            e2eThumbnailPreloadMs = 0
            return
        }
        
        thumbnailLoadingProgress = .loading(loaded: 0, total: preloadAssets.count)
        e2eThumbnailPreloadState = "running"
        e2eThumbnailPreloadMs = 0
        
        thumbnailPreloadTask = Task {
            let clock = ContinuousClock()
            let phaseStart = clock.now
            let signpostId = PerformanceSignposts.signposter.makeSignpostID()
            let signpostState = PerformanceSignposts.begin("thumbnailPreloadAll", id: signpostId)
            var phaseStatus = "done"
            defer {
                PerformanceSignposts.end("thumbnailPreloadAll", signpostState)
                if self.isAssetLoadContextValid(expectedFolderPath: expectedFolderPath) {
                    if phaseStatus == "done" {
                        self.e2eThumbnailPreloadMs = self.durationMilliseconds(phaseStart.duration(to: clock.now))
                    }
                    self.e2eThumbnailPreloadState = phaseStatus
                }
            }

            var loaded = 0
            let maxConcurrent = Self.thumbnailPreloadConcurrency(forAssetCount: preloadAssets.count)
            let progressStep = max(1, maxConcurrent)
            let preloadSize: CGFloat = 320  // Matches default grid request (160 * 2) to maximize cache reuse.

            await withTaskGroup(of: Void.self) { group in
                var nextIndex = 0
                var inFlight = 0

                func enqueueNext() {
                    guard nextIndex < preloadAssets.count else { return }
                    let asset = preloadAssets[nextIndex]
                    nextIndex += 1
                    inFlight += 1
                    group.addTask {
                        guard !Task.isCancelled else { return }
                        _ = await ThumbnailService.shared.thumbnail(for: asset, size: preloadSize)
                    }
                }

                let initial = min(maxConcurrent, preloadAssets.count)
                for _ in 0..<initial {
                    enqueueNext()
                }

                while inFlight > 0 {
                    _ = await group.next()
                    inFlight -= 1

                    if Task.isCancelled || !isAssetLoadContextValid(expectedFolderPath: expectedFolderPath) {
                        phaseStatus = "cancelled"
                        group.cancelAll()
                        return
                    }

                    loaded += 1
                    if loaded == preloadAssets.count || loaded % progressStep == 0 {
                        self.thumbnailLoadingProgress = .loading(loaded: loaded, total: preloadAssets.count)
                    }

                    enqueueNext()
                }
            }
            
            guard !Task.isCancelled, isAssetLoadContextValid(expectedFolderPath: expectedFolderPath) else {
                phaseStatus = "cancelled"
                return
            }

            // Mark as complete
            self.thumbnailLoadingProgress = .complete
            
            // Auto-hide after 2 seconds
            thumbnailAutoHideTask = Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                guard self.isAssetLoadContextValid(expectedFolderPath: expectedFolderPath) else { return }
                if case .complete = self.thumbnailLoadingProgress {
                    self.thumbnailLoadingProgress = .idle
                }
            }
        }
    }
}

// MARK: - Project State Persistence (v2)

extension AppState {
    /// Save current UI state to the selected project
    func saveCurrentStateToProject() {
        guard var project = selectedProject else { return }

        // Save filter state
        project.savedFilterState = SavedFilterState(
            minRating: filterRating,
            flagFilter: filterFlag,
            colorLabel: filterColor,
            tag: filterTag
        )

        // Save sort criteria
        project.sortCriteria = sortCriteria.rawValue
        project.sortAscending = (sortOrder == .ascending)

        // Save view mode
        project.savedViewMode = viewMode == .grid ? .grid : .single

        // Save selected photo path
        if let selectedId = selectedAssetId,
           let asset = assets.first(where: { $0.id == selectedId }) {
            project.lastSelectedPhotoPath = asset.url.path
        } else {
            project.lastSelectedPhotoPath = nil
        }

        // Note: gridZoomLevel is stored in GridView's @State, not AppState
        // It would need to be propagated if we want to save it

        // Update timestamps
        project.updatedAt = Date()

        // Update in catalog
        selectedProject = project
        catalog?.updateProject(project)
    }

    /// Restore UI state from a project
    func restoreStateFromProject(_ project: Project) {
        // Restore filter state
        if let savedFilter = project.savedFilterState {
            filterRating = savedFilter.minRating
            filterFlag = savedFilter.flagFilter
            filterColor = savedFilter.colorLabel
            filterTag = savedFilter.tag
        } else {
            // Clear filters if no saved state
            filterRating = 0
            filterFlag = nil
            filterColor = nil
            filterTag = ""
        }

        // Restore sort criteria
        if let savedCriteria = project.sortCriteria,
           let criteria = SortCriteria(rawValue: savedCriteria) {
            sortCriteria = criteria
        }
        if let ascending = project.sortAscending {
            sortOrder = ascending ? .ascending : .descending
        }

        // Restore view mode
        if let savedMode = project.savedViewMode {
            viewMode = savedMode == .grid ? .grid : .single
        }

        // Note: lastSelectedPhotoPath will be restored after assets are loaded
        // See restoreLastSelectedPhoto()
    }

    /// Restore the last selected photo after assets are loaded
    func restoreLastSelectedPhoto(from project: Project) {
        guard let photoPath = project.lastSelectedPhotoPath else { return }

        // Find asset by path
        if let asset = assets.first(where: { $0.url.path == photoPath }) {
            select(asset, switchToSingleView: viewMode == .single)
        }
    }

    /// Load project's source folders using bookmarks
    func loadProjectFolders(_ project: Project) async -> Bool {
        var didLoadAny = false
        for url in project.sourceFolders {
            if let bookmarkData = project.getBookmarkData(for: url) {
                // Try to restore from bookmark
                do {
                    var isStale = false
                    let resolvedURL = try URL(
                        resolvingBookmarkData: bookmarkData,
                        options: .withSecurityScope,
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale
                    )

                    guard resolvedURL.startAccessingSecurityScopedResource() else {
                        print("Failed to access security-scoped resource for: \(url.path)")
                        continue
                    }
                    defer {
                        resolvedURL.stopAccessingSecurityScopedResource()
                    }

                    // Load the folder using existing method
                    if await openFolderFromPath(resolvedURL.path, registerInFolderHistory: false) {
                        didLoadAny = true
                    }

                    // If bookmark is stale, refresh it
                    if isStale {
                        print("Bookmark is stale for: \(url.path), consider refreshing")
                        // Could update project.folderBookmarks here
                    }
                } catch {
                    print("Failed to resolve bookmark for \(url.path): \(error)")
                }
            } else {
                // No bookmark, try direct path access (may fail in sandbox)
                if await openFolderFromPath(url.path, registerInFolderHistory: false) {
                    didLoadAny = true
                }
            }
        }
        return didLoadAny
    }

    /// Called on app launch to restore last project
    func restoreLastProject() async -> Bool {
        guard let catalog = catalog else { return false }

        // Migrate if needed
        if catalog.version < 2 {
            var mutableCatalog = catalog
            mutableCatalog.migrateToV2()
            self.catalog = mutableCatalog
            // Save migrated catalog
            // Note: CatalogService.save would be called by the service
        }

        // Restore last opened project
        guard let lastProjectId = catalog.lastOpenedProjectId,
              let project = catalog.getProject(lastProjectId) else {
            return false
        }

        // Load project folders
        let didLoadProjectFolders = await loadProjectFolders(project)
        guard didLoadProjectFolders else {
            return false
        }

        // Restore UI state
        restoreStateFromProject(project)

        // Set as selected project
        selectedProject = project

        // Restore selected photo after a small delay (assets need to load first)
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 second delay
            await MainActor.run {
                self.restoreLastSelectedPhoto(from: project)
            }
        }
        return true
    }
}

// Safe array access
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
