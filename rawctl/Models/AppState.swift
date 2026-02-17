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
    
    @Published var selectedFolder: URL? {
        didSet {
            // Save to UserDefaults when folder changes
            if let folder = selectedFolder {
                UserDefaults.standard.set(folder.path, forKey: "lastOpenedFolder")
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
    private var recipeLoadTask: Task<Void, Never>?
    private var thumbnailPreloadTask: Task<Void, Never>?
    private var thumbnailAutoHideTask: Task<Void, Never>?
    private let thumbnailWarmupDelayNs: UInt64 = 120_000_000
    
    // MARK: - Default Folder
    
    /// User-configured default folder path
    @Published var defaultFolderPath: String {
        didSet {
            UserDefaults.standard.set(defaultFolderPath, forKey: "defaultFolderPath")
        }
    }
    
    /// Load last opened or default folder on startup
    func loadStartupFolder() async {
        // Try user-configured default first
        if !defaultFolderPath.isEmpty {
            await openFolderFromPath(defaultFolderPath)
            return
        }
        
        // Fall back to last opened folder
        if let lastPath = UserDefaults.standard.string(forKey: "lastOpenedFolder") {
            await openFolderFromPath(lastPath)
        }
    }
    
    init() {
        // Load saved default folder path
        self.defaultFolderPath = UserDefaults.standard.string(forKey: "defaultFolderPath") ?? ""
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
            await loadAllRecipes(expectedFolderPath: expectedFolderPath)
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

    private func resetE2EPhaseMetrics() {
        e2eScanPhaseMs = 0
        e2eSidecarLoadState = "idle"
        e2eSidecarLoadedCount = 0
        e2eSidecarLoadMs = 0
        e2eSidecarLoadUs = 0
        e2eThumbnailPreloadState = "idle"
        e2eThumbnailPreloadMs = 0
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
    @Published var e2eThumbnailPreloadState: String = "idle"
    @Published var e2eThumbnailPreloadMs: Int = 0

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
                selectedAssetId = first.id
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
        // Only clear project and smart collection selection
        // Keep assets and recipes if we're just switching views
        selectedProject = nil
        activeSmartCollection = nil
        // Note: Don't clear assets/recipes here - that should only happen
        // when opening a new folder or project
    }

    /// Apply a smart collection filter
    func applySmartCollection(_ collection: SmartCollection?) {
        activeSmartCollection = collection
        // Clear other filters when using smart collection
        if collection != nil {
            filterRating = 0
            filterColor = nil
            filterFlag = nil
            filterTag = ""
        }
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
        if selectedAssetIds.contains(assetId) {
            selectedAssetIds.remove(assetId)
            // Update primary selection to another selected item
            selectedAssetId = selectedAssetIds.first
        } else {
            selectedAssetIds.insert(assetId)
            selectedAssetId = assetId
        }
    }
    
    /// Extend selection to asset (Shift+click)
    func extendSelection(to assetId: UUID) {
        guard let currentId = selectedAssetId,
              let currentIndex = filteredAssets.firstIndex(where: { $0.id == currentId }),
              let targetIndex = filteredAssets.firstIndex(where: { $0.id == assetId }) else {
            // No current selection, just select this one
            selectedAssetId = assetId
            selectedAssetIds = [assetId]
            return
        }
        
        let start = min(currentIndex, targetIndex)
        let end = max(currentIndex, targetIndex)
        
        for i in start...end {
            selectedAssetIds.insert(filteredAssets[i].id)
        }
        selectedAssetId = assetId
    }
    
    /// Clear multi-selection
    func clearMultiSelection() {
        selectedAssetIds.removeAll()
    }
    
    /// Select all filtered assets
    func selectAll() {
        selectedAssetIds = Set(filteredAssets.map { $0.id })
        selectedAssetId = filteredAssets.first?.id
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

    /// Add a new local adjustment node for the current photo
    func addLocalNode(_ node: ColorNode) {
        guard let url = selectedAsset?.url else { return }
        var nodes = localNodes[url] ?? []
        nodes.append(node)
        localNodes[url] = nodes
    }

    /// Remove a local node by id for the current photo
    func removeLocalNode(id: UUID) {
        guard let url = selectedAsset?.url else { return }
        localNodes[url]?.removeAll { $0.id == id }
    }

    /// Update a local node's adjustments or mask
    func updateLocalNode(_ node: ColorNode) {
        guard let url = selectedAsset?.url else { return }
        guard let index = localNodes[url]?.firstIndex(where: { $0.id == node.id }) else { return }
        localNodes[url]?[index] = node
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
    }
    
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
            tag: filterTag
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

        // Apply active Smart Collection on top of control-based filters and sorting.
        if let collection = activeSmartCollection {
            return collection.filter(assets: sorted, recipes: recipes)
        }

        return sorted
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
        if selectedAssetId != nil {
            return true
        }

        if let first = filteredAssets.first ?? assets.first {
            selectedAssetId = first.id
            return true
        }

        return false
    }

    /// Switch to single view and auto-select the first available photo when needed.
    @discardableResult
    func switchToSingleViewIfPossible(showFeedback: Bool = true) -> Bool {
        guard ensurePrimarySelection() else {
            viewMode = .grid
            if showFeedback {
                showHUD("No photo selected")
            }
            return false
        }

        viewMode = .single
        return true
    }
    
    // MARK: - Actions
    
    func select(_ asset: PhotoAsset) {
        // Save current recipe before switching
        saveCurrentRecipe()

        selectedAssetId = asset.id

        // Load recipe from sidecar if not already in memory (may have been prefetched)
        if recipes[asset.id] == nil {
            Task {
                if let (recipe, snaps) = await SidecarService.shared.loadRecipeAndSnapshots(for: asset.url) {
                    await MainActor.run {
                        // Only update if still not set (avoid race condition with prefetch)
                        if self.recipes[asset.id] == nil {
                            self.recipes[asset.id] = recipe
                            self.snapshots[asset.id] = snaps
                            self.objectWillChange.send()
                        }
                    }
                }
            }
        }

        // Load localNodes for this photo (always refresh from sidecar on selection)
        Task {
            if let loaded = try? await SidecarService.shared.load(for: asset.url) {
                await MainActor.run {
                    self.localNodes[asset.url] = loaded.localNodes ?? []
                }
            }
        }

        // Switch view mode after recipe is set up
        // This ensures SingleView has data available immediately
        viewMode = .single
    }
    
    func updateRecipe(_ recipe: EditRecipe) {
        guard let id = selectedAssetId else { return }
        recipes[id] = recipe
        saveCurrentRecipe()
    }
    
    func saveCurrentRecipe() {
        guard let asset = selectedAsset else { return }
        let recipe = recipes[asset.id] ?? EditRecipe()
        let snapshots = snapshots[asset.id] ?? []
        let nodes = localNodes[asset.url]
        Task {
            // Use save(recipe:localNodes:for:) so localNodes are persisted alongside the recipe.
            // This method preserves existing sidecar fields (snapshots, AI edits) by reading
            // the current sidecar before writing. Falls back to the debounced path for snapshots.
            do {
                try await SidecarService.shared.save(recipe: recipe, localNodes: nodes, for: asset.url)
            } catch {
                // Fall back to debounced save (no localNodes) if the atomic write fails
                await SidecarService.shared.saveRecipe(recipe, snapshots: snapshots, for: asset.url)
            }
        }
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
        saveCurrentRecipe()
        selectedAssetId = nil
        viewMode = .grid
        comparisonMode = .none
        isZoomed = false
    }
    
    /// Load all recipes from sidecars for current folder (parallel with concurrency limit)
    func loadAllRecipes(expectedFolderPath: String? = nil) async {
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

        let assetsCopy = assets  // Capture for background processing
        guard !assetsCopy.isEmpty else {
            loadingMessage = ""
            return
        }

        let totalCount = assetsCopy.count
        var loadedCount = 0
        
        // Update loading message
        loadingMessage = "Loading edits..."
        
        // Parallel loading with concurrency limit
        await withTaskGroup(of: (UUID, EditRecipe?, [RecipeSnapshot]).self) { group in
            var pending = 0
            let maxConcurrent = assetsCopy.count > 200 ? 6 : 8
            
            for asset in assetsCopy {
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

                        if let recipe = result.1 {
                            recipes[result.0] = recipe
                        }
                        loadedCount += 1
                        e2eSidecarLoadedCount = loadedCount
                        pending -= 1
                    }
                }
                
                group.addTask { [url = asset.url, id = asset.id] in
                    guard !Task.isCancelled else { return (id, nil, []) }
                    if let (recipe, snapshots) = await SidecarService.shared.loadRecipeAndSnapshots(for: url) {
                        guard !Task.isCancelled else { return (id, nil, []) }
                        return (id, recipe, snapshots)
                    }
                    return (id, nil, [])
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

                    if let recipe = result.1 {
                        recipes[result.0] = recipe
                    }
                    loadedCount += 1
                    e2eSidecarLoadedCount = loadedCount
                    
                    // Update progress periodically (every 50 items)
                    if loadedCount % 50 == 0 {
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

                // Prefetch at low resolution for fast loading
                _ = await ImagePipeline.shared.renderPreview(
                    for: asset,
                    recipe: recipe,
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
        guard recipes[asset.id] == nil else { return }

        Task {
            if let (recipe, snaps) = await SidecarService.shared.loadRecipeAndSnapshots(for: asset.url) {
                await MainActor.run {
                    // Only set if still nil (avoid race conditions)
                    if self.recipes[asset.id] == nil {
                        self.recipes[asset.id] = recipe
                        self.snapshots[asset.id] = snaps
                    }
                }
            }
        }
    }
    
    /// Open folder from path string
    func openFolderFromPath(_ path: String) async {
        let url = URL(fileURLWithPath: path)
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
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            print("[AppState] Invalid path: \(path)")
            return
        }

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

            // Select the first asset immediately so view switching/shortcuts work while edits load.
            if let first = scannedAssets.first {
                selectedAssetId = first.id
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

            // Continue sidecar/thumbnails in cancellable background tasks.
            schedulePostScanBackgroundWork(expectedFolder: url)
        } catch {
            e2eScanPhaseMs = 0
            isLoading = false
            loadingMessage = ""
            print("[AppState] Error scanning: \(error)")
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
            
            // Remove deleted assets and their recipes
            let removedSet = Set(result.removed)
            assets.removeAll { removedSet.contains($0.fingerprint) }
            for fingerprint in result.removed {
                if let asset = assets.first(where: { $0.fingerprint == fingerprint }) {
                    recipes.removeValue(forKey: asset.id)
                }
            }
            
            // Add new assets
            assets.append(contentsOf: result.added)
            
            // Sort
            assets.sort { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }
            
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
        await withTaskGroup(of: (UUID, EditRecipe?).self) { group in
            for asset in assetsToLoad {
                group.addTask { [url = asset.url, id = asset.id] in
                    if let (recipe, _) = await SidecarService.shared.loadRecipeAndSnapshots(for: url) {
                        return (id, recipe)
                    }
                    return (id, nil)
                }
            }
            
            for await result in group {
                if let recipe = result.1 {
                    recipes[result.0] = recipe
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
        guard !assetsCopy.isEmpty else {
            thumbnailLoadingProgress = .idle
            e2eThumbnailPreloadState = "idle"
            e2eThumbnailPreloadMs = 0
            return
        }
        
        thumbnailLoadingProgress = .loading(loaded: 0, total: assetsCopy.count)
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
            let maxConcurrent = assetsCopy.count > 240 ? 5 : 6
            let progressStep = max(1, maxConcurrent)
            let preloadSize: CGFloat = 320  // Matches default grid request (160 * 2) to maximize cache reuse.

            await withTaskGroup(of: Void.self) { group in
                var nextIndex = 0
                var inFlight = 0

                func enqueueNext() {
                    guard nextIndex < assetsCopy.count else { return }
                    let asset = assetsCopy[nextIndex]
                    nextIndex += 1
                    inFlight += 1
                    group.addTask {
                        guard !Task.isCancelled else { return }
                        _ = await ThumbnailService.shared.thumbnail(for: asset, size: preloadSize)
                    }
                }

                let initial = min(maxConcurrent, assetsCopy.count)
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
                    if loaded == assetsCopy.count || loaded % progressStep == 0 {
                        self.thumbnailLoadingProgress = .loading(loaded: loaded, total: assetsCopy.count)
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
            selectedAssetId = asset.id
        }
    }

    /// Load project's source folders using bookmarks
    func loadProjectFolders(_ project: Project) async {
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

                    // Load the folder using existing method
                    await openFolderFromPath(resolvedURL.path)

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
                await openFolderFromPath(url.path)
            }
        }
    }

    /// Called on app launch to restore last project
    func restoreLastProject() async {
        guard let catalog = catalog else { return }

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
            return
        }

        // Load project folders
        await loadProjectFolders(project)

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
    }
}

// Safe array access
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
