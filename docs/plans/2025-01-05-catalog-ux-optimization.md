# rawctl Catalog UX Optimization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform rawctl from folder-based browsing to a professional Catalog-based workflow with Project management, Smart Collections, intelligent import, and streamlined export.

**Architecture:**
- Add `Catalog` + `Project` + `SmartCollection` models that wrap existing `PhotoAsset`/`EditRecipe` systems
- Extend `AppState` with catalog awareness while maintaining backward compatibility
- Restructure `SidebarView` into Library/Projects/Smart Collections/Devices sections following macOS HIG
- Add Survey Mode and Compare View for efficient culling workflow

**Tech Stack:** SwiftUI, Swift Testing, async/await concurrency, JSON persistence, Security-scoped bookmarks

---

## Phase 1: Catalog Foundation (Tasks 1-12)

### Task 1: Create Project Model

**Files:**
- Create: `rawctl/rawctl/Models/Project.swift`
- Test: `rawctlTests/ProjectTests.swift`

**Step 1: Write the failing test**

```swift
// rawctlTests/ProjectTests.swift
import Testing
@testable import rawctl

struct ProjectTests {

    @Test func projectInitializesWithRequiredFields() async throws {
        let project = Project(
            name: "Wedding_2025-01-05",
            shootDate: Date(),
            projectType: .wedding
        )

        #expect(project.name == "Wedding_2025-01-05")
        #expect(project.projectType == .wedding)
        #expect(project.status == .importing)
        #expect(project.sourceFolders.isEmpty)
    }

    @Test func projectTypeHasCorrectCases() async throws {
        let allTypes: [ProjectType] = [.wedding, .portrait, .event, .landscape, .street, .product, .other]
        #expect(allTypes.count == 7)
    }

    @Test func projectStatusProgression() async throws {
        var project = Project(name: "Test", shootDate: Date(), projectType: .portrait)
        #expect(project.status == .importing)

        project.status = .culling
        #expect(project.status == .culling)

        project.status = .editing
        #expect(project.status == .editing)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme rawctl -destination 'platform=macOS' -only-testing:rawctlTests/ProjectTests 2>&1 | head -50`
Expected: FAIL with "cannot find 'Project' in scope"

**Step 3: Write minimal implementation**

```swift
// rawctl/rawctl/Models/Project.swift
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
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme rawctl -destination 'platform=macOS' -only-testing:rawctlTests/ProjectTests 2>&1 | tail -20`
Expected: PASS - "Test Suite 'ProjectTests' passed"

**Step 5: Commit**

```bash
git add rawctl/rawctl/Models/Project.swift rawctlTests/ProjectTests.swift
git commit -m "feat(models): add Project model with type and status enums"
```

---

### Task 2: Create SmartCollection Model

**Files:**
- Create: `rawctl/rawctl/Models/SmartCollection.swift`
- Test: `rawctlTests/SmartCollectionTests.swift`

**Step 1: Write the failing test**

```swift
// rawctlTests/SmartCollectionTests.swift
import Testing
@testable import rawctl

struct SmartCollectionTests {

    @Test func smartCollectionInitializesCorrectly() async throws {
        let collection = SmartCollection(
            name: "5 Stars",
            icon: "star.fill",
            rules: [FilterRule(field: .rating, operation: .equals, value: "5")]
        )

        #expect(collection.name == "5 Stars")
        #expect(collection.rules.count == 1)
    }

    @Test func filterRuleMatchesRating() async throws {
        let rule = FilterRule(field: .rating, operation: .greaterThanOrEqual, value: "4")
        let recipe = EditRecipe()
        var ratedRecipe = EditRecipe()
        ratedRecipe.rating = 4

        #expect(rule.matches(recipe: recipe) == false)
        #expect(rule.matches(recipe: ratedRecipe) == true)
    }

    @Test func filterRuleMatchesFlag() async throws {
        let rule = FilterRule(field: .flag, operation: .equals, value: "pick")
        var recipe = EditRecipe()
        recipe.flag = .pick

        #expect(rule.matches(recipe: recipe) == true)

        recipe.flag = .reject
        #expect(rule.matches(recipe: recipe) == false)
    }

    @Test func multipleRulesWithAndLogic() async throws {
        let collection = SmartCollection(
            name: "Best Picks",
            icon: "star.fill",
            rules: [
                FilterRule(field: .rating, operation: .greaterThanOrEqual, value: "4"),
                FilterRule(field: .flag, operation: .equals, value: "pick")
            ],
            ruleLogic: .and
        )

        var recipe = EditRecipe()
        recipe.rating = 5
        recipe.flag = .pick

        #expect(collection.matches(recipe: recipe) == true)

        recipe.flag = .none
        #expect(collection.matches(recipe: recipe) == false)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme rawctl -destination 'platform=macOS' -only-testing:rawctlTests/SmartCollectionTests 2>&1 | head -50`
Expected: FAIL with "cannot find 'SmartCollection' in scope"

**Step 3: Write minimal implementation**

```swift
// rawctl/rawctl/Models/SmartCollection.swift
//
//  SmartCollection.swift
//  rawctl
//
//  Dynamic collection based on filter rules
//

import Foundation

/// Field to filter on
enum FilterField: String, Codable, CaseIterable {
    case rating
    case flag
    case colorLabel
    case hasEdits
    case isRAW
    case tag
    case captureDate

    var displayName: String {
        switch self {
        case .rating: return "Rating"
        case .flag: return "Flag"
        case .colorLabel: return "Color Label"
        case .hasEdits: return "Has Edits"
        case .isRAW: return "Is RAW"
        case .tag: return "Tag"
        case .captureDate: return "Capture Date"
        }
    }
}

/// Filter operation type
enum FilterOperation: String, Codable, CaseIterable {
    case equals
    case notEquals
    case greaterThan
    case greaterThanOrEqual
    case lessThan
    case lessThanOrEqual
    case contains
    case notContains

    var displayName: String {
        switch self {
        case .equals: return "is"
        case .notEquals: return "is not"
        case .greaterThan: return ">"
        case .greaterThanOrEqual: return ">="
        case .lessThan: return "<"
        case .lessThanOrEqual: return "<="
        case .contains: return "contains"
        case .notContains: return "doesn't contain"
        }
    }
}

/// Single filter rule
struct FilterRule: Codable, Equatable, Identifiable {
    let id: UUID
    var field: FilterField
    var operation: FilterOperation
    var value: String

    init(id: UUID = UUID(), field: FilterField, operation: FilterOperation, value: String) {
        self.id = id
        self.field = field
        self.operation = operation
        self.value = value
    }

    /// Check if a recipe matches this rule
    func matches(recipe: EditRecipe, asset: PhotoAsset? = nil) -> Bool {
        switch field {
        case .rating:
            guard let targetRating = Int(value) else { return false }
            return compareNumeric(recipe.rating, to: targetRating)

        case .flag:
            let recipeFlag = recipe.flag.rawValue
            switch operation {
            case .equals: return recipeFlag == value
            case .notEquals: return recipeFlag != value
            default: return false
            }

        case .colorLabel:
            let recipeColor = recipe.colorLabel.rawValue
            switch operation {
            case .equals: return recipeColor == value
            case .notEquals: return recipeColor != value
            default: return false
            }

        case .hasEdits:
            let hasEdits = recipe.hasEdits
            let targetValue = value.lowercased() == "true"
            switch operation {
            case .equals: return hasEdits == targetValue
            case .notEquals: return hasEdits != targetValue
            default: return false
            }

        case .isRAW:
            guard let asset = asset else { return false }
            let isRAW = asset.isRAW
            let targetValue = value.lowercased() == "true"
            switch operation {
            case .equals: return isRAW == targetValue
            case .notEquals: return isRAW != targetValue
            default: return false
            }

        case .tag:
            let tags = recipe.tags.joined(separator: ",").lowercased()
            let searchValue = value.lowercased()
            switch operation {
            case .contains: return tags.contains(searchValue)
            case .notContains: return !tags.contains(searchValue)
            case .equals: return recipe.tags.contains(where: { $0.lowercased() == searchValue })
            default: return false
            }

        case .captureDate:
            // Date filtering would need asset metadata
            return true
        }
    }

    private func compareNumeric(_ value: Int, to target: Int) -> Bool {
        switch operation {
        case .equals: return value == target
        case .notEquals: return value != target
        case .greaterThan: return value > target
        case .greaterThanOrEqual: return value >= target
        case .lessThan: return value < target
        case .lessThanOrEqual: return value <= target
        default: return false
        }
    }
}

/// Logic for combining multiple rules
enum RuleLogic: String, Codable {
    case and  // All rules must match
    case or   // Any rule matches
}

/// A smart collection with dynamic filtering
struct SmartCollection: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var icon: String
    var rules: [FilterRule]
    var ruleLogic: RuleLogic
    var sortOrder: AppState.SortCriteria
    var isBuiltIn: Bool  // System collections can't be deleted

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "folder.fill",
        rules: [FilterRule] = [],
        ruleLogic: RuleLogic = .and,
        sortOrder: AppState.SortCriteria = .filename,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.rules = rules
        self.ruleLogic = ruleLogic
        self.sortOrder = sortOrder
        self.isBuiltIn = isBuiltIn
    }

    /// Check if a recipe matches all/any rules based on logic
    func matches(recipe: EditRecipe, asset: PhotoAsset? = nil) -> Bool {
        guard !rules.isEmpty else { return true }

        switch ruleLogic {
        case .and:
            return rules.allSatisfy { $0.matches(recipe: recipe, asset: asset) }
        case .or:
            return rules.contains { $0.matches(recipe: recipe, asset: asset) }
        }
    }

    /// Filter assets based on rules
    func filter(assets: [PhotoAsset], recipes: [UUID: EditRecipe]) -> [PhotoAsset] {
        assets.filter { asset in
            let recipe = recipes[asset.id] ?? EditRecipe()
            return matches(recipe: recipe, asset: asset)
        }
    }

    // MARK: - Built-in Collections

    static let fiveStars = SmartCollection(
        name: "5 Stars",
        icon: "star.fill",
        rules: [FilterRule(field: .rating, operation: .equals, value: "5")],
        isBuiltIn: true
    )

    static let picks = SmartCollection(
        name: "Picks",
        icon: "flag.fill",
        rules: [FilterRule(field: .flag, operation: .equals, value: "pick")],
        isBuiltIn: true
    )

    static let rejects = SmartCollection(
        name: "Rejects",
        icon: "xmark.circle.fill",
        rules: [FilterRule(field: .flag, operation: .equals, value: "reject")],
        isBuiltIn: true
    )

    static let unrated = SmartCollection(
        name: "Unrated",
        icon: "star.slash",
        rules: [FilterRule(field: .rating, operation: .equals, value: "0")],
        isBuiltIn: true
    )

    static let edited = SmartCollection(
        name: "Edited",
        icon: "slider.horizontal.3",
        rules: [FilterRule(field: .hasEdits, operation: .equals, value: "true")],
        isBuiltIn: true
    )
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme rawctl -destination 'platform=macOS' -only-testing:rawctlTests/SmartCollectionTests 2>&1 | tail -20`
Expected: PASS

**Step 5: Commit**

```bash
git add rawctl/rawctl/Models/SmartCollection.swift rawctlTests/SmartCollectionTests.swift
git commit -m "feat(models): add SmartCollection with FilterRule matching"
```

---

### Task 3: Create Catalog Model

**Files:**
- Create: `rawctl/rawctl/Models/Catalog.swift`
- Test: `rawctlTests/CatalogTests.swift`

**Step 1: Write the failing test**

```swift
// rawctlTests/CatalogTests.swift
import Testing
@testable import rawctl

struct CatalogTests {

    @Test func catalogInitializesWithDefaults() async throws {
        let libraryPath = URL(fileURLWithPath: "/Users/test/Pictures/rawctl")
        let catalog = Catalog(libraryPath: libraryPath)

        #expect(catalog.version == 1)
        #expect(catalog.projects.isEmpty)
        #expect(catalog.smartCollections.count == 5) // Built-in collections
    }

    @Test func catalogAddsProject() async throws {
        let libraryPath = URL(fileURLWithPath: "/Users/test/Pictures/rawctl")
        var catalog = Catalog(libraryPath: libraryPath)

        let project = Project(name: "Test", shootDate: Date(), projectType: .portrait)
        catalog.addProject(project)

        #expect(catalog.projects.count == 1)
        #expect(catalog.projects.first?.name == "Test")
    }

    @Test func catalogGroupsProjectsByMonth() async throws {
        let libraryPath = URL(fileURLWithPath: "/Users/test/Pictures/rawctl")
        var catalog = Catalog(libraryPath: libraryPath)

        let jan = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 5))!
        let feb = Calendar.current.date(from: DateComponents(year: 2025, month: 2, day: 10))!

        catalog.addProject(Project(name: "Jan Project", shootDate: jan, projectType: .wedding))
        catalog.addProject(Project(name: "Feb Project", shootDate: feb, projectType: .portrait))

        let grouped = catalog.projectsByMonth
        #expect(grouped.count == 2)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme rawctl -destination 'platform=macOS' -only-testing:rawctlTests/CatalogTests 2>&1 | head -50`
Expected: FAIL with "cannot find 'Catalog' in scope"

**Step 3: Write minimal implementation**

```swift
// rawctl/rawctl/Models/Catalog.swift
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
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme rawctl -destination 'platform=macOS' -only-testing:rawctlTests/CatalogTests 2>&1 | tail -20`
Expected: PASS

**Step 5: Commit**

```bash
git add rawctl/rawctl/Models/Catalog.swift rawctlTests/CatalogTests.swift
git commit -m "feat(models): add Catalog with projects and smart collections"
```

---

### Task 4: Create CatalogService for Persistence

**Files:**
- Create: `rawctl/rawctl/Services/CatalogService.swift`
- Test: `rawctlTests/CatalogServiceTests.swift`

**Step 1: Write the failing test**

```swift
// rawctlTests/CatalogServiceTests.swift
import Testing
@testable import rawctl

struct CatalogServiceTests {

    @Test func catalogServiceSavesAndLoads() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let catalogPath = tempDir.appendingPathComponent("rawctl-catalog.json")
        let service = CatalogService(catalogPath: catalogPath)

        var catalog = Catalog(libraryPath: tempDir)
        catalog.addProject(Project(name: "Test Project", shootDate: Date(), projectType: .portrait))

        try await service.save(catalog)

        let loaded = try await service.load()
        #expect(loaded != nil)
        #expect(loaded?.projects.count == 1)
        #expect(loaded?.projects.first?.name == "Test Project")
    }

    @Test func catalogServiceCreatesNewIfMissing() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let catalogPath = tempDir.appendingPathComponent("missing-catalog.json")
        let service = CatalogService(catalogPath: catalogPath)

        let catalog = try await service.loadOrCreate(libraryPath: tempDir)

        #expect(catalog.version == Catalog.currentVersion)
        #expect(catalog.libraryPath == tempDir)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme rawctl -destination 'platform=macOS' -only-testing:rawctlTests/CatalogServiceTests 2>&1 | head -50`
Expected: FAIL with "cannot find 'CatalogService' in scope"

**Step 3: Write minimal implementation**

```swift
// rawctl/rawctl/Services/CatalogService.swift
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
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme rawctl -destination 'platform=macOS' -only-testing:rawctlTests/CatalogServiceTests 2>&1 | tail -20`
Expected: PASS

**Step 5: Commit**

```bash
git add rawctl/rawctl/Services/CatalogService.swift rawctlTests/CatalogServiceTests.swift
git commit -m "feat(services): add CatalogService for JSON persistence"
```

---

### Task 5: Extend AppState with Catalog Awareness

**Files:**
- Modify: `rawctl/rawctl/Models/AppState.swift`
- Test: `rawctlTests/AppStateCatalogTests.swift`

**Step 1: Write the failing test**

```swift
// rawctlTests/AppStateCatalogTests.swift
import Testing
@testable import rawctl

@MainActor
struct AppStateCatalogTests {

    @Test func appStateInitializesWithCatalog() async throws {
        let appState = AppState()

        // Initially nil until loaded
        #expect(appState.catalog == nil)
        #expect(appState.selectedProject == nil)
    }

    @Test func appStateSelectsProject() async throws {
        let appState = AppState()

        let libraryPath = URL(fileURLWithPath: "/tmp/test-library")
        var catalog = Catalog(libraryPath: libraryPath)
        let project = Project(name: "Test", shootDate: Date(), projectType: .portrait)
        catalog.addProject(project)

        appState.catalog = catalog
        appState.selectedProject = project

        #expect(appState.selectedProject?.name == "Test")
        #expect(appState.isProjectMode == true)
    }

    @Test func appStateFiltersAssetsForSmartCollection() async throws {
        let appState = AppState()

        // Add test assets
        let asset1 = PhotoAsset(url: URL(fileURLWithPath: "/tmp/photo1.arw"))
        let asset2 = PhotoAsset(url: URL(fileURLWithPath: "/tmp/photo2.arw"))
        appState.assets = [asset1, asset2]

        // Set up recipes
        var recipe1 = EditRecipe()
        recipe1.rating = 5
        appState.recipes[asset1.id] = recipe1

        // Apply 5-star filter
        appState.activeSmartCollection = .fiveStars

        #expect(appState.smartFilteredAssets.count == 1)
        #expect(appState.smartFilteredAssets.first?.id == asset1.id)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme rawctl -destination 'platform=macOS' -only-testing:rawctlTests/AppStateCatalogTests 2>&1 | head -50`
Expected: FAIL with "Value of type 'AppState' has no member 'catalog'"

**Step 3: Add catalog properties to AppState**

Add the following to `rawctl/rawctl/Models/AppState.swift` after line 108 (after `@Published var eyedropperMode: Bool = false`):

```swift
    // MARK: - Catalog & Project Mode

    /// The loaded catalog (nil if using legacy folder mode)
    @Published var catalog: Catalog?

    /// Currently selected project (nil = legacy folder mode or library view)
    @Published var selectedProject: Project?

    /// Currently active smart collection filter
    @Published var activeSmartCollection: SmartCollection?

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
        guard let collection = activeSmartCollection else {
            return filteredAssets
        }
        return collection.filter(assets: filteredAssets, recipes: recipes)
    }

    /// Select a project and load its assets
    func selectProject(_ project: Project) async {
        selectedProject = project
        activeSmartCollection = nil

        // Load first source folder
        if let firstFolder = project.sourceFolders.first {
            await openFolderFromPath(firstFolder.path)
        }

        // Update catalog's last opened
        if var cat = catalog {
            cat.lastOpenedProjectId = project.id
            catalog = cat
        }
    }

    /// Clear project selection (return to library view)
    func clearProjectSelection() {
        selectedProject = nil
        activeSmartCollection = nil
        assets = []
        recipes = [:]
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
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme rawctl -destination 'platform=macOS' -only-testing:rawctlTests/AppStateCatalogTests 2>&1 | tail -20`
Expected: PASS

**Step 5: Commit**

```bash
git add rawctl/rawctl/Models/AppState.swift rawctlTests/AppStateCatalogTests.swift
git commit -m "feat(appstate): add catalog and project mode support"
```

---

### Task 6: Create LibrarySection View Component

**Files:**
- Create: `rawctl/rawctl/Components/Sidebar/LibrarySection.swift`

**Step 1: Create the component**

```swift
// rawctl/rawctl/Components/Sidebar/LibrarySection.swift
//
//  LibrarySection.swift
//  rawctl
//
//  Library section of the sidebar (All Photos, Recent, Quick Collection)
//

import SwiftUI

/// Library section showing overview entries
struct LibrarySection: View {
    @ObservedObject var appState: AppState
    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup("Library", isExpanded: $isExpanded) {
            VStack(spacing: 2) {
                // All Photos
                LibraryRow(
                    icon: "photo.on.rectangle",
                    title: "All Photos",
                    count: appState.catalog?.totalPhotos ?? appState.assets.count,
                    isSelected: !appState.isProjectMode && appState.activeSmartCollection == nil
                ) {
                    appState.clearProjectSelection()
                }

                // Recent Imports
                LibraryRow(
                    icon: "clock.arrow.circlepath",
                    title: "Recent Imports",
                    count: recentImportsCount,
                    isSelected: false
                ) {
                    // TODO: Show recent imports
                }

                // Quick Collection (starred/favorited)
                LibraryRow(
                    icon: "star.fill",
                    title: "Quick Collection",
                    count: quickCollectionCount,
                    isSelected: isQuickCollectionActive
                ) {
                    appState.applySmartCollection(.fiveStars)
                }
            }
            .padding(.vertical, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var recentImportsCount: Int {
        // Photos imported in last 7 days
        guard let catalog = appState.catalog else { return 0 }
        let weekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        return catalog.projects
            .filter { $0.createdAt > weekAgo }
            .reduce(0) { $0 + $1.totalPhotos }
    }

    private var quickCollectionCount: Int {
        appState.assets.filter { asset in
            (appState.recipes[asset.id]?.rating ?? 0) >= 5
        }.count
    }

    private var isQuickCollectionActive: Bool {
        appState.activeSmartCollection?.id == SmartCollection.fiveStars.id
    }
}

/// Single row in library section
struct LibraryRow: View {
    let icon: String
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 16)

                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .accentColor : .primary)

                Spacer()

                Text("\(count)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(white: 0.2))
                    .cornerRadius(4)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LibrarySection(appState: AppState())
        .frame(width: 220)
        .preferredColorScheme(.dark)
}
```

**Step 2: Commit**

```bash
git add rawctl/rawctl/Components/Sidebar/LibrarySection.swift
git commit -m "feat(ui): add LibrarySection sidebar component"
```

---

### Task 7: Create ProjectsSection View Component

**Files:**
- Create: `rawctl/rawctl/Components/Sidebar/ProjectsSection.swift`

**Step 1: Create the component**

```swift
// rawctl/rawctl/Components/Sidebar/ProjectsSection.swift
//
//  ProjectsSection.swift
//  rawctl
//
//  Projects section of the sidebar with month grouping
//

import SwiftUI

/// Projects section showing grouped projects
struct ProjectsSection: View {
    @ObservedObject var appState: AppState
    @State private var isExpanded = true
    @State private var expandedMonths: Set<String> = []
    @State private var showCreateProject = false

    var body: some View {
        DisclosureGroup("Projects", isExpanded: $isExpanded) {
            VStack(spacing: 4) {
                if let catalog = appState.catalog {
                    ForEach(catalog.projectsByMonth, id: \.month) { group in
                        MonthGroup(
                            month: group.month,
                            projects: group.projects,
                            isExpanded: expandedMonths.contains(group.month),
                            selectedProject: appState.selectedProject,
                            onToggle: { toggleMonth(group.month) },
                            onSelect: { project in
                                Task {
                                    await appState.selectProject(project)
                                }
                            }
                        )
                    }

                    if catalog.projects.isEmpty {
                        Text("No projects yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    }
                }

                // Create Project button
                Button {
                    showCreateProject = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 11))
                        Text("Create Project")
                            .font(.system(size: 11))
                        Spacer()
                    }
                    .foregroundColor(.accentColor)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .sheet(isPresented: $showCreateProject) {
            CreateProjectSheet(appState: appState)
        }
        .onAppear {
            // Expand current month by default
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            expandedMonths.insert(formatter.string(from: Date()))
        }
    }

    private func toggleMonth(_ month: String) {
        if expandedMonths.contains(month) {
            expandedMonths.remove(month)
        } else {
            expandedMonths.insert(month)
        }
    }
}

/// Month grouping for projects
struct MonthGroup: View {
    let month: String
    let projects: [Project]
    let isExpanded: Bool
    let selectedProject: Project?
    let onToggle: () -> Void
    let onSelect: (Project) -> Void

    var body: some View {
        VStack(spacing: 2) {
            // Month header
            Button(action: onToggle) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 12)

                    Text(formattedMonth)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(projects.count)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
            }
            .buttonStyle(.plain)

            // Projects in this month
            if isExpanded {
                ForEach(projects) { project in
                    ProjectRow(
                        project: project,
                        isSelected: selectedProject?.id == project.id,
                        onSelect: { onSelect(project) }
                    )
                }
            }
        }
    }

    private var formattedMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        guard let date = formatter.date(from: month) else { return month }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMMM yyyy"
        return displayFormatter.string(from: date)
    }
}

/// Single project row
struct ProjectRow: View {
    let project: Project
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: project.projectType.icon)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? .accentColor : .primary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text("\(project.totalPhotos) photos")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)

                        Circle()
                            .fill(Color(
                                red: project.status.color.r,
                                green: project.status.color.g,
                                blue: project.status.color.b
                            ))
                            .frame(width: 6, height: 6)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .padding(.leading, 16)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open in Finder") {
                if let folder = project.sourceFolders.first {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folder.path)
                }
            }

            Divider()

            Menu("Set Status") {
                ForEach(ProjectStatus.allCases, id: \.self) { status in
                    Button(status.displayName) {
                        // Update status
                    }
                }
            }

            Divider()

            Button("Archive Project", role: .destructive) {
                // Archive
            }
        }
    }
}

#Preview {
    ProjectsSection(appState: AppState())
        .frame(width: 220)
        .preferredColorScheme(.dark)
}
```

**Step 2: Commit**

```bash
git add rawctl/rawctl/Components/Sidebar/ProjectsSection.swift
git commit -m "feat(ui): add ProjectsSection with month grouping"
```

---

### Task 8: Create SmartCollectionsSection View Component

**Files:**
- Create: `rawctl/rawctl/Components/Sidebar/SmartCollectionsSection.swift`

**Step 1: Create the component**

```swift
// rawctl/rawctl/Components/Sidebar/SmartCollectionsSection.swift
//
//  SmartCollectionsSection.swift
//  rawctl
//
//  Smart collections section of the sidebar
//

import SwiftUI

/// Smart collections section
struct SmartCollectionsSection: View {
    @ObservedObject var appState: AppState
    @State private var isExpanded = true
    @State private var showCreateCollection = false

    var body: some View {
        DisclosureGroup("Smart Collections", isExpanded: $isExpanded) {
            VStack(spacing: 2) {
                ForEach(collections) { collection in
                    SmartCollectionRow(
                        collection: collection,
                        count: countFor(collection),
                        isSelected: appState.activeSmartCollection?.id == collection.id,
                        onSelect: {
                            appState.applySmartCollection(collection)
                        }
                    )
                }

                // Create Smart Collection button
                Button {
                    showCreateCollection = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 11))
                        Text("Create Smart Collection")
                            .font(.system(size: 11))
                        Spacer()
                    }
                    .foregroundColor(.accentColor)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .sheet(isPresented: $showCreateCollection) {
            CreateSmartCollectionSheet(appState: appState)
        }
    }

    private var collections: [SmartCollection] {
        appState.catalog?.smartCollections ?? [
            .fiveStars,
            .picks,
            .rejects,
            .unrated,
            .edited
        ]
    }

    private func countFor(_ collection: SmartCollection) -> Int {
        collection.filter(assets: appState.assets, recipes: appState.recipes).count
    }
}

/// Single smart collection row
struct SmartCollectionRow: View {
    let collection: SmartCollection
    let count: Int
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: collection.icon)
                    .font(.system(size: 11))
                    .foregroundColor(iconColor)
                    .frame(width: 14)

                Text(collection.name)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .accentColor : .primary)

                Spacer()

                Text("\(count)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(white: 0.2))
                    .cornerRadius(4)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !collection.isBuiltIn {
                Button("Edit Collection...") {
                    // Edit
                }

                Divider()

                Button("Delete Collection", role: .destructive) {
                    // Delete
                }
            }
        }
    }

    private var iconColor: Color {
        if isSelected { return .accentColor }

        // Special colors for specific collections
        switch collection.name {
        case "5 Stars": return .yellow
        case "Picks": return .green
        case "Rejects": return .red
        default: return .secondary
        }
    }
}

#Preview {
    SmartCollectionsSection(appState: AppState())
        .frame(width: 220)
        .preferredColorScheme(.dark)
}
```

**Step 2: Commit**

```bash
git add rawctl/rawctl/Components/Sidebar/SmartCollectionsSection.swift
git commit -m "feat(ui): add SmartCollectionsSection component"
```

---

### Task 9: Create DevicesSection View Component

**Files:**
- Create: `rawctl/rawctl/Components/Sidebar/DevicesSection.swift`

**Step 1: Create the component**

```swift
// rawctl/rawctl/Components/Sidebar/DevicesSection.swift
//
//  DevicesSection.swift
//  rawctl
//
//  Devices section showing memory cards and connected cameras
//

import SwiftUI

/// Devices section for memory cards
struct DevicesSection: View {
    @ObservedObject var appState: AppState
    @State private var isExpanded = true
    @State private var detectedCards: [DetectedCard] = []
    @State private var showImportSheet = false
    @State private var selectedCard: DetectedCard?

    struct DetectedCard: Identifiable {
        let id = UUID()
        let url: URL
        let name: String
        let photoCount: Int
        let cardType: CardType

        enum CardType {
            case sdCard
            case cfCard
            case camera
            case phone

            var icon: String {
                switch self {
                case .sdCard: return "sdcard.fill"
                case .cfCard: return "internaldrive.fill"
                case .camera: return "camera.fill"
                case .phone: return "iphone"
                }
            }
        }
    }

    var body: some View {
        if !detectedCards.isEmpty {
            DisclosureGroup("Devices", isExpanded: $isExpanded) {
                VStack(spacing: 2) {
                    ForEach(detectedCards) { card in
                        DeviceRow(
                            card: card,
                            onImport: {
                                selectedCard = card
                                showImportSheet = true
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .sheet(isPresented: $showImportSheet) {
                if let card = selectedCard {
                    SmartImportSheet(
                        appState: appState,
                        sourceURL: card.url,
                        cardName: card.name
                    )
                }
            }
        }
    }

    private func refreshCards() {
        Task {
            let cards = await MemoryCardService.shared.getDetectedCards()
            await MainActor.run {
                detectedCards = cards.map { url in
                    DetectedCard(
                        url: url,
                        name: url.lastPathComponent,
                        photoCount: 0, // Will be scanned on demand
                        cardType: detectCardType(url)
                    )
                }
            }
        }
    }

    private func detectCardType(_ url: URL) -> DetectedCard.CardType {
        let name = url.lastPathComponent.uppercased()
        if name.contains("IPHONE") || name.contains("IPAD") {
            return .phone
        } else if name.contains("EOS") || name.contains("NIKON") || name.contains("SONY") {
            return .camera
        } else if name.contains("CF") {
            return .cfCard
        }
        return .sdCard
    }
}

/// Single device row
struct DeviceRow: View {
    let card: DevicesSection.DetectedCard
    let onImport: () -> Void

    @State private var isHovering = false
    @State private var photoCount: Int?

    var body: some View {
        Button(action: onImport) {
            HStack(spacing: 8) {
                Image(systemName: card.cardType.icon)
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(card.name)
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if let count = photoCount {
                        Text("\(count) photos")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Scanning...")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if isHovering {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isHovering ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .task {
            // Scan for photo count
            do {
                let assets = try await FileSystemService.scanFolder(card.url)
                photoCount = assets.count
            } catch {
                photoCount = 0
            }
        }
    }
}

#Preview {
    DevicesSection(appState: AppState())
        .frame(width: 220)
        .preferredColorScheme(.dark)
}
```

**Step 2: Commit**

```bash
git add rawctl/rawctl/Components/Sidebar/DevicesSection.swift
git commit -m "feat(ui): add DevicesSection for memory cards"
```

---

### Task 10: Create CreateProjectSheet View

**Files:**
- Create: `rawctl/rawctl/Views/CreateProjectSheet.swift`

**Step 1: Create the view**

```swift
// rawctl/rawctl/Views/CreateProjectSheet.swift
//
//  CreateProjectSheet.swift
//  rawctl
//
//  Sheet for creating a new project
//

import SwiftUI

/// Sheet for creating a new project
struct CreateProjectSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var projectName: String = ""
    @State private var clientName: String = ""
    @State private var shootDate: Date = Date()
    @State private var projectType: ProjectType = .portrait
    @State private var sourceFolder: URL?
    @State private var notes: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create New Project")
                    .font(.title2.bold())
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Form
            Form {
                Section("Project Details") {
                    TextField("Project Name", text: $projectName)
                        .textFieldStyle(.roundedBorder)

                    TextField("Client Name (Optional)", text: $clientName)
                        .textFieldStyle(.roundedBorder)

                    DatePicker("Shoot Date", selection: $shootDate, displayedComponents: .date)

                    Picker("Project Type", selection: $projectType) {
                        ForEach(ProjectType.allCases) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                }

                Section("Source Folder") {
                    HStack {
                        if let folder = sourceFolder {
                            Text(folder.path)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        } else {
                            Text("No folder selected")
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button("Choose...") {
                            selectFolder()
                        }
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(height: 80)
                        .font(.system(size: 12))
                }
            }
            .formStyle(.grouped)
            .padding()

            Divider()

            // Footer
            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button("Create Project") {
                    createProject()
                }
                .buttonStyle(.borderedProminent)
                .disabled(projectName.isEmpty)
                .keyboardShortcut(.return)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 500, height: 480)
        .onAppear {
            // Auto-generate name from date
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            projectName = formatter.string(from: shootDate)
        }
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "Select the folder containing your photos"

        if panel.runModal() == .OK {
            sourceFolder = panel.url

            // Update project name from folder if not set
            if projectName.isEmpty || projectName.contains("-") {
                projectName = panel.url?.lastPathComponent ?? projectName
            }
        }
    }

    private func createProject() {
        var project = Project(
            name: projectName,
            clientName: clientName.isEmpty ? nil : clientName,
            shootDate: shootDate,
            projectType: projectType,
            notes: notes
        )

        if let folder = sourceFolder {
            project.sourceFolders = [folder]
        }

        // Add to catalog
        if var catalog = appState.catalog {
            catalog.addProject(project)
            appState.catalog = catalog

            // Save catalog
            Task {
                let service = CatalogService(catalogPath: CatalogService.defaultCatalogPath)
                try? await service.save(catalog)
            }
        }

        // Select the new project
        Task {
            await appState.selectProject(project)
        }

        dismiss()
    }
}

#Preview {
    CreateProjectSheet(appState: AppState())
        .preferredColorScheme(.dark)
}
```

**Step 2: Commit**

```bash
git add rawctl/rawctl/Views/CreateProjectSheet.swift
git commit -m "feat(ui): add CreateProjectSheet for new projects"
```

---

### Task 11: Create SmartImportSheet View

**Files:**
- Create: `rawctl/rawctl/Views/SmartImportSheet.swift`

**Step 1: Create the view**

```swift
// rawctl/rawctl/Views/SmartImportSheet.swift
//
//  SmartImportSheet.swift
//  rawctl
//
//  One-click smart import from memory card
//

import SwiftUI

/// Smart import sheet with auto-project creation
struct SmartImportSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let sourceURL: URL
    let cardName: String

    @State private var photosToImport: [PhotoAsset] = []
    @State private var selectedPhotos: Set<UUID> = []
    @State private var isScanning = true
    @State private var isImporting = false
    @State private var importProgress: Double = 0
    @State private var importedCount = 0

    // Project settings
    @State private var projectName: String = ""
    @State private var projectType: ProjectType = .other
    @State private var createDateSubfolders = true
    @State private var deleteAfterImport = false

    // Quick templates
    let templates: [(name: String, type: ProjectType)] = [
        ("Wedding", .wedding),
        ("Portrait", .portrait),
        ("Event", .event),
        ("Landscape", .landscape),
        ("Street", .street),
        ("Custom", .other)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            HStack(spacing: 0) {
                // Left: Preview grid
                previewGrid
                    .frame(width: 380)

                Divider()

                // Right: Settings
                settingsPanel
                    .frame(width: 280)
            }

            Divider()

            // Footer
            footerView
        }
        .frame(width: 660, height: 500)
        .task {
            await scanSource()
        }
        .onAppear {
            // Auto-generate project name
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            projectName = "\(formatter.string(from: Date()))_\(cardName)"
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: "sdcard.fill")
                .font(.title2)
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(cardName)
                    .font(.headline)

                if isScanning {
                    Text("Scanning...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(photosToImport.count) photos found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button("Close") {
                dismiss()
            }
            .keyboardShortcut(.escape)
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Preview Grid

    private var previewGrid: some View {
        VStack(spacing: 8) {
            // Selection controls
            HStack {
                Button("Select All") {
                    selectedPhotos = Set(photosToImport.map { $0.id })
                }
                .font(.caption)

                Button("Deselect All") {
                    selectedPhotos = []
                }
                .font(.caption)

                Spacer()

                Text("\(selectedPhotos.count) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            if isScanning {
                VStack {
                    ProgressView()
                    Text("Scanning memory card...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 6) {
                        ForEach(photosToImport) { photo in
                            ImportThumbnail(
                                asset: photo,
                                isSelected: selectedPhotos.contains(photo.id),
                                onTap: {
                                    if selectedPhotos.contains(photo.id) {
                                        selectedPhotos.remove(photo.id)
                                    } else {
                                        selectedPhotos.insert(photo.id)
                                    }
                                }
                            )
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(Color(white: 0.1))
    }

    // MARK: - Settings Panel

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Project name
            VStack(alignment: .leading, spacing: 6) {
                Text("Project Name")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("", text: $projectName)
                    .textFieldStyle(.roundedBorder)
            }

            // Destination
            VStack(alignment: .leading, spacing: 6) {
                Text("Destination")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(destinationPath)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(white: 0.15))
                    .cornerRadius(6)
            }

            // Options
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Create date subfolders", isOn: $createDateSubfolders)
                    .font(.caption)

                Toggle("Delete from card after import", isOn: $deleteAfterImport)
                    .font(.caption)
                    .foregroundColor(deleteAfterImport ? .orange : .primary)
            }

            Divider()

            // Quick Templates
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Templates")
                    .font(.caption)
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 8) {
                    ForEach(templates, id: \.name) { template in
                        Button {
                            projectType = template.type
                            if template.name != "Custom" {
                                projectName = "\(Date().formatted(.dateTime.year().month().day()))_\(template.name)"
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: template.type.icon)
                                    .font(.system(size: 16))
                                Text(template.name)
                                    .font(.system(size: 9))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(projectType == template.type ? Color.accentColor.opacity(0.2) : Color(white: 0.15))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(projectType == template.type ? Color.accentColor : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            if isImporting {
                ProgressView(value: importProgress)
                    .frame(width: 200)

                Text("\(importedCount)/\(selectedPhotos.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Skip") {
                dismiss()
            }

            Button("Import \(selectedPhotos.count) Photos") {
                Task {
                    await performImport()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedPhotos.isEmpty || isImporting)
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Helpers

    private var destinationPath: String {
        guard let catalog = appState.catalog else {
            return "~/Pictures/rawctl Library/"
        }
        return catalog.libraryPath.appendingPathComponent(projectName).path
    }

    private func scanSource() async {
        isScanning = true

        do {
            // Try DCIM folder first
            let dcimURL = sourceURL.appendingPathComponent("DCIM")
            let scanURL = FileManager.default.fileExists(atPath: dcimURL.path) ? dcimURL : sourceURL

            let assets = try await FileSystemService.scanFolder(scanURL)
            await MainActor.run {
                photosToImport = assets
                selectedPhotos = Set(assets.map { $0.id })
                isScanning = false
            }
        } catch {
            await MainActor.run {
                isScanning = false
            }
        }
    }

    private func performImport() async {
        guard let catalog = appState.catalog else { return }

        isImporting = true
        importedCount = 0
        importProgress = 0

        // Create project
        var project = Project(
            name: projectName,
            shootDate: Date(),
            projectType: projectType
        )

        // Destination folder
        let destinationFolder = catalog.libraryPath.appendingPathComponent(projectName)
        project.sourceFolders = [destinationFolder]

        // Create destination
        try? FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)

        // Import photos
        let photosToProcess = photosToImport.filter { selectedPhotos.contains($0.id) }
        let total = photosToProcess.count

        for (index, photo) in photosToProcess.enumerated() {
            var targetFolder = destinationFolder

            if createDateSubfolders {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"

                let fileDate: Date
                if let attrs = try? FileManager.default.attributesOfItem(atPath: photo.url.path),
                   let creationDate = attrs[.creationDate] as? Date {
                    fileDate = creationDate
                } else {
                    fileDate = Date()
                }

                let dateString = dateFormatter.string(from: fileDate)
                targetFolder = destinationFolder.appendingPathComponent(dateString)
                try? FileManager.default.createDirectory(at: targetFolder, withIntermediateDirectories: true)
            }

            let destinationFile = targetFolder.appendingPathComponent(photo.filename)

            do {
                if !FileManager.default.fileExists(atPath: destinationFile.path) {
                    try FileManager.default.copyItem(at: photo.url, to: destinationFile)
                }

                if deleteAfterImport {
                    try? FileManager.default.removeItem(at: photo.url)
                }

                await MainActor.run {
                    importedCount = index + 1
                    importProgress = Double(importedCount) / Double(total)
                }
            } catch {
                print("[SmartImport] Error: \(error)")
            }
        }

        // Add project to catalog
        project.totalPhotos = total

        await MainActor.run {
            if var cat = appState.catalog {
                cat.addProject(project)
                appState.catalog = cat

                // Save catalog
                Task {
                    let service = CatalogService(catalogPath: CatalogService.defaultCatalogPath)
                    try? await service.save(cat)
                }
            }

            isImporting = false
        }

        // Open the new project
        await appState.selectProject(project)

        await MainActor.run {
            dismiss()
        }
    }
}

#Preview {
    SmartImportSheet(
        appState: AppState(),
        sourceURL: URL(fileURLWithPath: "/Volumes/EOS_DIGITAL"),
        cardName: "EOS_DIGITAL"
    )
    .preferredColorScheme(.dark)
}
```

**Step 2: Commit**

```bash
git add rawctl/rawctl/Views/SmartImportSheet.swift
git commit -m "feat(ui): add SmartImportSheet with one-click import"
```

---

### Task 12: Integrate New Sidebar into SidebarView

**Files:**
- Modify: `rawctl/rawctl/Views/SidebarView.swift`

**Step 1: Update SidebarView to use new components**

Replace the body of `SidebarView` in `rawctl/rawctl/Views/SidebarView.swift` with:

```swift
var body: some View {
    VStack(spacing: 0) {
        // New hierarchical sidebar sections
        ScrollView {
            VStack(spacing: 0) {
                // Library Section
                LibrarySection(appState: appState)

                Divider()
                    .padding(.horizontal, 12)

                // Projects Section
                ProjectsSection(appState: appState)

                Divider()
                    .padding(.horizontal, 12)

                // Smart Collections Section
                SmartCollectionsSection(appState: appState)

                Divider()
                    .padding(.horizontal, 12)

                // Devices Section (Memory Cards)
                DevicesSection(appState: appState)
            }
        }

        Spacer(minLength: 0)

        Divider()

        // Account section at bottom
        accountSection
    }
    .background(.ultraThinMaterial)
    .overlay {
        if appState.isLoading {
            loadingOverlay
        }
    }
}
```

**Step 2: Remove old folder-based sections**

Remove the old `Saved Folders`, `Files`, path input, and memory cards sections since they're now handled by the new components.

**Step 3: Run the app to verify**

Run: `xcodebuild build -scheme rawctl -destination 'platform=macOS' 2>&1 | tail -30`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add rawctl/rawctl/Views/SidebarView.swift
git commit -m "refactor(sidebar): integrate new Library/Projects/Smart Collections structure"
```

---

## Phase 2: Culling Efficiency (Tasks 13-18)

### Task 13: Create SurveyMode View

**Files:**
- Create: `rawctl/rawctl/Views/SurveyModeView.swift`

**Step 1: Create the view**

```swift
// rawctl/rawctl/Views/SurveyModeView.swift
//
//  SurveyModeView.swift
//  rawctl
//
//  Full-screen survey mode for rapid culling
//

import SwiftUI

/// Full-screen survey mode for efficient culling
struct SurveyModeView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex: Int = 0
    @State private var previewImage: NSImage?
    @State private var isLoading = true

    private var assets: [PhotoAsset] {
        appState.filteredAssets
    }

    private var currentAsset: PhotoAsset? {
        assets[safe: currentIndex]
    }

    private var currentRecipe: EditRecipe {
        guard let asset = currentAsset else { return EditRecipe() }
        return appState.recipes[asset.id] ?? EditRecipe()
    }

    var body: some View {
        ZStack {
            // Black background
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                topBar

                // Main image
                imageView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom controls
                bottomControls
            }
        }
        .task {
            if let index = assets.firstIndex(where: { $0.id == appState.selectedAssetId }) {
                currentIndex = index
            }
            await loadCurrentImage()
        }
        .onKeyPress(.leftArrow) {
            navigatePrevious()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            navigateNext()
            return .handled
        }
        .onKeyPress("p") {
            setFlag(.pick)
            return .handled
        }
        .onKeyPress("x") {
            setFlag(.reject)
            return .handled
        }
        .onKeyPress("u") {
            setFlag(.none)
            return .handled
        }
        .onKeyPress("1") { setRating(1); return .handled }
        .onKeyPress("2") { setRating(2); return .handled }
        .onKeyPress("3") { setRating(3); return .handled }
        .onKeyPress("4") { setRating(4); return .handled }
        .onKeyPress("5") { setRating(5); return .handled }
        .onKeyPress("0") { setRating(0); return .handled }
        .onKeyPress(.space) {
            toggleFlag()
            return .handled
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Survey Mode")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            // Stats
            HStack(spacing: 16) {
                StatBadge(label: "Picks", count: picksCount, color: .green)
                StatBadge(label: "Rejects", count: rejectsCount, color: .red)
                StatBadge(label: "Unrated", count: unratedCount, color: .gray)
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }

    // MARK: - Image View

    private var imageView: some View {
        ZStack {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else if let image = previewImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
            }

            // Rating/Flag overlay
            VStack {
                Spacer()
                HStack {
                    // Current rating
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= currentRecipe.rating ? "star.fill" : "star")
                                .foregroundColor(star <= currentRecipe.rating ? .yellow : .gray.opacity(0.5))
                        }
                    }
                    .font(.title2)

                    Spacer()

                    // Current flag
                    if currentRecipe.flag != .none {
                        Image(systemName: currentRecipe.flag == .pick ? "flag.fill" : "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(currentRecipe.flag == .pick ? .green : .red)
                    }
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 12) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.2))

                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 4)
            .cornerRadius(2)

            // Navigation and actions
            HStack(spacing: 40) {
                // Previous
                Button {
                    navigatePrevious()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 36))
                        Text("←")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.8))
                .disabled(currentIndex == 0)

                // Reject
                Button {
                    setFlag(.reject)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 44))
                        Text("X")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)

                // Unflag
                Button {
                    setFlag(.none)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "circle")
                            .font(.system(size: 44))
                        Text("U")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.6))

                // Pick
                Button {
                    setFlag(.pick)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 44))
                        Text("P")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.green)

                // Next
                Button {
                    navigateNext()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 36))
                        Text("→")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.8))
                .disabled(currentIndex >= assets.count - 1)
            }

            // Progress text
            Text("\(currentIndex + 1) of \(assets.count)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }

    // MARK: - Computed Properties

    private var progress: Double {
        guard !assets.isEmpty else { return 0 }
        return Double(currentIndex + 1) / Double(assets.count)
    }

    private var picksCount: Int {
        assets.filter { appState.recipes[$0.id]?.flag == .pick }.count
    }

    private var rejectsCount: Int {
        assets.filter { appState.recipes[$0.id]?.flag == .reject }.count
    }

    private var unratedCount: Int {
        assets.filter { (appState.recipes[$0.id]?.rating ?? 0) == 0 }.count
    }

    // MARK: - Actions

    private func navigatePrevious() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        Task { await loadCurrentImage() }
    }

    private func navigateNext() {
        guard currentIndex < assets.count - 1 else { return }
        currentIndex += 1
        Task { await loadCurrentImage() }
    }

    private func setRating(_ rating: Int) {
        guard let asset = currentAsset else { return }
        var recipe = appState.recipes[asset.id] ?? EditRecipe()
        recipe.rating = rating
        appState.recipes[asset.id] = recipe
        appState.saveCurrentRecipe()
    }

    private func setFlag(_ flag: Flag) {
        guard let asset = currentAsset else { return }
        var recipe = appState.recipes[asset.id] ?? EditRecipe()
        recipe.flag = flag
        appState.recipes[asset.id] = recipe
        appState.saveCurrentRecipe()

        // Auto-advance after flagging
        if currentIndex < assets.count - 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                navigateNext()
            }
        }
    }

    private func toggleFlag() {
        guard let asset = currentAsset else { return }
        let currentFlag = appState.recipes[asset.id]?.flag ?? .none
        let newFlag: Flag = currentFlag == .pick ? .none : .pick
        setFlag(newFlag)
    }

    private func loadCurrentImage() async {
        guard let asset = currentAsset else { return }

        isLoading = true
        let recipe = appState.recipes[asset.id] ?? EditRecipe()

        if let image = await ImagePipeline.shared.renderPreview(
            for: asset,
            recipe: recipe,
            maxSize: 1600
        ) {
            await MainActor.run {
                previewImage = image
                isLoading = false
            }
        }
    }
}

/// Small stat badge for survey mode
struct StatBadge: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(count)")
                .font(.caption.monospacedDigit())
                .foregroundColor(.white)
        }
    }
}

#Preview {
    SurveyModeView(appState: AppState())
}
```

**Step 2: Commit**

```bash
git add rawctl/rawctl/Views/SurveyModeView.swift
git commit -m "feat(ui): add SurveyModeView for rapid culling"
```

---

### Task 14: Create CompareView for Side-by-Side Comparison

**Files:**
- Create: `rawctl/rawctl/Views/CompareView.swift`

**Step 1: Create the view**

```swift
// rawctl/rawctl/Views/CompareView.swift
//
//  CompareView.swift
//  rawctl
//
//  Side-by-side photo comparison view
//

import SwiftUI

/// Compare two photos side by side
struct CompareView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var leftIndex: Int = 0
    @State private var rightIndex: Int = 1
    @State private var leftImage: NSImage?
    @State private var rightImage: NSImage?
    @State private var syncZoom = true
    @State private var zoomLevel: Double = 1.0
    @State private var panOffset: CGSize = .zero

    private var assets: [PhotoAsset] {
        appState.filteredAssets
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                topBar

                // Compare area
                HStack(spacing: 2) {
                    // Left photo
                    ComparePanel(
                        asset: assets[safe: leftIndex],
                        recipe: recipeFor(leftIndex),
                        image: leftImage,
                        zoomLevel: zoomLevel,
                        panOffset: syncZoom ? panOffset : .zero,
                        isPrimary: true,
                        onFlag: { flag in setFlag(leftIndex, flag) },
                        onRate: { rating in setRating(leftIndex, rating) }
                    )

                    // Divider handle
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 2)

                    // Right photo
                    ComparePanel(
                        asset: assets[safe: rightIndex],
                        recipe: recipeFor(rightIndex),
                        image: rightImage,
                        zoomLevel: zoomLevel,
                        panOffset: syncZoom ? panOffset : .zero,
                        isPrimary: false,
                        onFlag: { flag in setFlag(rightIndex, flag) },
                        onRate: { rating in setRating(rightIndex, rating) }
                    )
                }

                // Bottom controls
                bottomControls
            }
        }
        .task {
            await loadImages()
        }
        .onKeyPress(.leftArrow) {
            navigateLeft()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            navigateRight()
            return .handled
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        .onKeyPress("1") { setFlag(leftIndex, .pick); return .handled }
        .onKeyPress("2") { setFlag(rightIndex, .pick); return .handled }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Compare Mode")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            Toggle(isOn: $syncZoom) {
                Label("Sync Zoom", systemImage: "lock.fill")
            }
            .toggleStyle(.button)
            .font(.caption)
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack(spacing: 20) {
            // Left navigation
            Button {
                navigateLeft()
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 28))
            }
            .buttonStyle(.plain)
            .foregroundColor(.white.opacity(0.8))

            // Zoom controls
            HStack(spacing: 8) {
                Button {
                    zoomLevel = max(0.5, zoomLevel - 0.25)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }

                Text("\(Int(zoomLevel * 100))%")
                    .font(.caption.monospacedDigit())
                    .frame(width: 50)

                Button {
                    zoomLevel = min(4.0, zoomLevel + 0.25)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }

                Button {
                    zoomLevel = 1.0
                    panOffset = .zero
                } label: {
                    Text("1:1")
                        .font(.caption)
                }
            }
            .foregroundColor(.white)

            // Swap button
            Button {
                swap(&leftIndex, &rightIndex)
                Task { await loadImages() }
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundColor(.white.opacity(0.8))

            // Right navigation
            Button {
                navigateRight()
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 28))
            }
            .buttonStyle(.plain)
            .foregroundColor(.white.opacity(0.8))
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }

    // MARK: - Helpers

    private func recipeFor(_ index: Int) -> EditRecipe {
        guard let asset = assets[safe: index] else { return EditRecipe() }
        return appState.recipes[asset.id] ?? EditRecipe()
    }

    private func setFlag(_ index: Int, _ flag: Flag) {
        guard let asset = assets[safe: index] else { return }
        var recipe = appState.recipes[asset.id] ?? EditRecipe()
        recipe.flag = flag
        appState.recipes[asset.id] = recipe
        appState.saveCurrentRecipe()
    }

    private func setRating(_ index: Int, _ rating: Int) {
        guard let asset = assets[safe: index] else { return }
        var recipe = appState.recipes[asset.id] ?? EditRecipe()
        recipe.rating = rating
        appState.recipes[asset.id] = recipe
        appState.saveCurrentRecipe()
    }

    private func navigateLeft() {
        if leftIndex > 0 {
            rightIndex = leftIndex
            leftIndex -= 1
            Task { await loadImages() }
        }
    }

    private func navigateRight() {
        if rightIndex < assets.count - 1 {
            leftIndex = rightIndex
            rightIndex += 1
            Task { await loadImages() }
        }
    }

    private func loadImages() async {
        async let leftLoad = loadImage(for: leftIndex)
        async let rightLoad = loadImage(for: rightIndex)

        let (left, right) = await (leftLoad, rightLoad)

        await MainActor.run {
            leftImage = left
            rightImage = right
        }
    }

    private func loadImage(for index: Int) async -> NSImage? {
        guard let asset = assets[safe: index] else { return nil }
        let recipe = appState.recipes[asset.id] ?? EditRecipe()
        return await ImagePipeline.shared.renderPreview(for: asset, recipe: recipe, maxSize: 1200)
    }
}

/// Single panel in compare view
struct ComparePanel: View {
    let asset: PhotoAsset?
    let recipe: EditRecipe
    let image: NSImage?
    let zoomLevel: Double
    let panOffset: CGSize
    let isPrimary: Bool
    let onFlag: (Flag) -> Void
    let onRate: (Int) -> Void

    var body: some View {
        ZStack {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(zoomLevel)
                    .offset(panOffset)
            } else {
                ProgressView()
            }

            // Overlay
            VStack {
                // Filename
                HStack {
                    Text(asset?.filename ?? "")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)

                    Spacer()

                    // Keyboard hint
                    Text(isPrimary ? "Press 1 to pick" : "Press 2 to pick")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(8)

                Spacer()

                // Rating and flag
                HStack {
                    // Stars
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= recipe.rating ? "star.fill" : "star")
                                .foregroundColor(star <= recipe.rating ? .yellow : .gray.opacity(0.5))
                        }
                    }

                    Spacer()

                    // Flag
                    if recipe.flag != .none {
                        Image(systemName: recipe.flag == .pick ? "flag.fill" : "xmark.circle.fill")
                            .foregroundColor(recipe.flag == .pick ? .green : .red)
                    }
                }
                .padding(8)
                .background(Color.black.opacity(0.6))
            }
        }
    }
}

#Preview {
    CompareView(appState: AppState())
}
```

**Step 2: Commit**

```bash
git add rawctl/rawctl/Views/CompareView.swift
git commit -m "feat(ui): add CompareView for side-by-side comparison"
```

---

### Task 15: Add Keyboard Shortcuts Manager

**Files:**
- Create: `rawctl/rawctl/Services/KeyboardShortcutsManager.swift`

**Step 1: Create the manager**

```swift
// rawctl/rawctl/Services/KeyboardShortcutsManager.swift
//
//  KeyboardShortcutsManager.swift
//  rawctl
//
//  Centralized keyboard shortcuts management
//

import SwiftUI

/// Centralized keyboard shortcut definitions
enum KeyboardShortcut {
    // Navigation
    static let nextPhoto = KeyEquivalent.rightArrow
    static let previousPhoto = KeyEquivalent.leftArrow
    static let firstPhoto = KeyEquivalent.home
    static let lastPhoto = KeyEquivalent.end

    // Rating
    static let rate0 = KeyEquivalent("0")
    static let rate1 = KeyEquivalent("1")
    static let rate2 = KeyEquivalent("2")
    static let rate3 = KeyEquivalent("3")
    static let rate4 = KeyEquivalent("4")
    static let rate5 = KeyEquivalent("5")

    // Flagging
    static let pick = KeyEquivalent("p")
    static let reject = KeyEquivalent("x")
    static let unflag = KeyEquivalent("u")
    static let togglePick = KeyEquivalent.space

    // Color Labels
    static let colorRed = KeyEquivalent("6")
    static let colorYellow = KeyEquivalent("7")
    static let colorGreen = KeyEquivalent("8")
    static let colorBlue = KeyEquivalent("9")

    // Views
    static let surveyMode = KeyEquivalent("n")  // with Cmd
    static let compareMode = KeyEquivalent("c")  // with Cmd
    static let gridView = KeyEquivalent("g")
    static let filmstrip = KeyEquivalent("f")

    // Zoom
    static let zoomIn = KeyEquivalent("+")
    static let zoomOut = KeyEquivalent("-")
    static let fitToScreen = KeyEquivalent("0")  // with Cmd
    static let actualSize = KeyEquivalent("1")   // with Cmd+Opt

    // Editing
    static let copySettings = KeyEquivalent("c")  // with Cmd+Shift
    static let pasteSettings = KeyEquivalent("v")  // with Cmd+Shift
    static let resetEdits = KeyEquivalent("r")     // with Cmd+Shift
}

/// View modifier for common photo operations
struct PhotoKeyboardShortcuts: ViewModifier {
    @ObservedObject var appState: AppState
    var onNavigateNext: (() -> Void)?
    var onNavigatePrevious: (() -> Void)?

    func body(content: Content) -> some View {
        content
            // Rating shortcuts
            .onKeyPress("0") { setRating(0); return .handled }
            .onKeyPress("1") { setRating(1); return .handled }
            .onKeyPress("2") { setRating(2); return .handled }
            .onKeyPress("3") { setRating(3); return .handled }
            .onKeyPress("4") { setRating(4); return .handled }
            .onKeyPress("5") { setRating(5); return .handled }

            // Flag shortcuts
            .onKeyPress("p") { setFlag(.pick); return .handled }
            .onKeyPress("x") { setFlag(.reject); return .handled }
            .onKeyPress("u") { setFlag(.none); return .handled }
            .onKeyPress(.space) { togglePick(); return .handled }

            // Color label shortcuts
            .onKeyPress("6") { setColor(.red); return .handled }
            .onKeyPress("7") { setColor(.yellow); return .handled }
            .onKeyPress("8") { setColor(.green); return .handled }
            .onKeyPress("9") { setColor(.blue); return .handled }

            // Navigation
            .onKeyPress(.rightArrow) {
                onNavigateNext?()
                return .handled
            }
            .onKeyPress(.leftArrow) {
                onNavigatePrevious?()
                return .handled
            }
    }

    private func setRating(_ rating: Int) {
        guard let id = appState.selectedAssetId else { return }
        var recipe = appState.recipes[id] ?? EditRecipe()
        recipe.rating = rating
        appState.recipes[id] = recipe
        appState.saveCurrentRecipe()
    }

    private func setFlag(_ flag: Flag) {
        guard let id = appState.selectedAssetId else { return }
        var recipe = appState.recipes[id] ?? EditRecipe()
        recipe.flag = flag
        appState.recipes[id] = recipe
        appState.saveCurrentRecipe()
    }

    private func togglePick() {
        guard let id = appState.selectedAssetId else { return }
        let currentFlag = appState.recipes[id]?.flag ?? .none
        setFlag(currentFlag == .pick ? .none : .pick)
    }

    private func setColor(_ color: ColorLabel) {
        guard let id = appState.selectedAssetId else { return }
        var recipe = appState.recipes[id] ?? EditRecipe()
        recipe.colorLabel = color
        appState.recipes[id] = recipe
        appState.saveCurrentRecipe()
    }
}

extension View {
    func photoKeyboardShortcuts(
        appState: AppState,
        onNext: (() -> Void)? = nil,
        onPrevious: (() -> Void)? = nil
    ) -> some View {
        modifier(PhotoKeyboardShortcuts(
            appState: appState,
            onNavigateNext: onNext,
            onNavigatePrevious: onPrevious
        ))
    }
}
```

**Step 2: Commit**

```bash
git add rawctl/rawctl/Services/KeyboardShortcutsManager.swift
git commit -m "feat(input): add KeyboardShortcutsManager for centralized shortcuts"
```

---

### Task 16: Create BatchRatingSheet View

**Files:**
- Create: `rawctl/rawctl/Views/BatchRatingSheet.swift`

**Step 1: Create the view**

```swift
// rawctl/rawctl/Views/BatchRatingSheet.swift
//
//  BatchRatingSheet.swift
//  rawctl
//
//  Apply ratings/flags to multiple selected photos
//

import SwiftUI

/// Sheet for batch applying ratings and flags
struct BatchRatingSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let selectedAssets: [PhotoAsset]

    @State private var newRating: Int?
    @State private var newFlag: Flag?
    @State private var newColorLabel: ColorLabel?
    @State private var addTags: String = ""
    @State private var isApplying = false
    @State private var appliedCount = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Batch Edit")
                    .font(.title2.bold())

                Spacer()

                Text("\(selectedAssets.count) photos selected")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Options
            Form {
                Section("Rating") {
                    HStack(spacing: 16) {
                        Button("Clear") {
                            newRating = 0
                        }
                        .buttonStyle(newRating == 0 ? .borderedProminent : .bordered)

                        ForEach(1...5, id: \.self) { rating in
                            Button {
                                newRating = rating
                            } label: {
                                HStack(spacing: 2) {
                                    ForEach(1...rating, id: \.self) { _ in
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.yellow)
                                    }
                                }
                            }
                            .buttonStyle(newRating == rating ? .borderedProminent : .bordered)
                        }

                        Spacer()

                        Button("Don't change") {
                            newRating = nil
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }

                Section("Flag") {
                    HStack(spacing: 16) {
                        Button {
                            newFlag = .pick
                        } label: {
                            Label("Pick", systemImage: "flag.fill")
                        }
                        .buttonStyle(newFlag == .pick ? .borderedProminent : .bordered)
                        .tint(.green)

                        Button {
                            newFlag = .reject
                        } label: {
                            Label("Reject", systemImage: "xmark.circle.fill")
                        }
                        .buttonStyle(newFlag == .reject ? .borderedProminent : .bordered)
                        .tint(.red)

                        Button {
                            newFlag = .none
                        } label: {
                            Text("Unflag")
                        }
                        .buttonStyle(newFlag == .none ? .borderedProminent : .bordered)

                        Spacer()

                        Button("Don't change") {
                            newFlag = nil
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }

                Section("Color Label") {
                    HStack(spacing: 12) {
                        ForEach(ColorLabel.allCases, id: \.self) { color in
                            Button {
                                newColorLabel = color
                            } label: {
                                Circle()
                                    .fill(color.swiftUIColor)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle()
                                            .stroke(newColorLabel == color ? Color.white : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()

                        Button("Don't change") {
                            newColorLabel = nil
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }

                Section("Tags") {
                    TextField("Add tags (comma separated)", text: $addTags)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .formStyle(.grouped)
            .padding()

            Divider()

            // Footer
            HStack {
                if isApplying {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Applied to \(appliedCount)/\(selectedAssets.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button("Apply Changes") {
                    applyChanges()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasChanges || isApplying)
                .keyboardShortcut(.return)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 500, height: 420)
    }

    private var hasChanges: Bool {
        newRating != nil || newFlag != nil || newColorLabel != nil || !addTags.isEmpty
    }

    private func applyChanges() {
        isApplying = true
        appliedCount = 0

        let tagsToAdd = addTags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        for asset in selectedAssets {
            var recipe = appState.recipes[asset.id] ?? EditRecipe()

            if let rating = newRating {
                recipe.rating = rating
            }

            if let flag = newFlag {
                recipe.flag = flag
            }

            if let color = newColorLabel {
                recipe.colorLabel = color
            }

            if !tagsToAdd.isEmpty {
                for tag in tagsToAdd {
                    if !recipe.tags.contains(tag) {
                        recipe.tags.append(tag)
                    }
                }
            }

            appState.recipes[asset.id] = recipe
            appliedCount += 1
        }

        // Save all changes
        appState.saveCurrentRecipe()

        isApplying = false
        dismiss()
    }
}

#Preview {
    BatchRatingSheet(
        appState: AppState(),
        selectedAssets: []
    )
    .preferredColorScheme(.dark)
}
```

**Step 2: Commit**

```bash
git add rawctl/rawctl/Views/BatchRatingSheet.swift
git commit -m "feat(ui): add BatchRatingSheet for bulk rating/flag operations"
```

---

### Task 17: Add Auto-Advance Setting

**Files:**
- Modify: `rawctl/rawctl/Models/AppState.swift`
- Modify: `rawctl/rawctl/Views/SettingsView.swift`

**Step 1: Add auto-advance preference to AppState**

Add to `rawctl/rawctl/Models/AppState.swift` in the preferences section:

```swift
    // MARK: - Culling Preferences

    /// Auto-advance to next photo after rating/flagging
    @AppStorage("autoAdvanceAfterRating") var autoAdvanceAfterRating: Bool = true

    /// Auto-advance delay in milliseconds
    @AppStorage("autoAdvanceDelay") var autoAdvanceDelay: Int = 150

    /// Skip rejected photos when navigating
    @AppStorage("skipRejectedPhotos") var skipRejectedPhotos: Bool = false

    /// Play sound on pick/reject
    @AppStorage("playSoundOnFlag") var playSoundOnFlag: Bool = false
```

**Step 2: Add settings UI**

Add to `rawctl/rawctl/Views/SettingsView.swift` in the appropriate section:

```swift
Section("Culling Behavior") {
    Toggle("Auto-advance after rating/flagging", isOn: $appState.autoAdvanceAfterRating)

    if appState.autoAdvanceAfterRating {
        Picker("Delay", selection: $appState.autoAdvanceDelay) {
            Text("Instant").tag(0)
            Text("150ms").tag(150)
            Text("300ms").tag(300)
            Text("500ms").tag(500)
        }
        .pickerStyle(.segmented)
    }

    Toggle("Skip rejected photos when navigating", isOn: $appState.skipRejectedPhotos)

    Toggle("Play sound on pick/reject", isOn: $appState.playSoundOnFlag)
}
```

**Step 3: Commit**

```bash
git add rawctl/rawctl/Models/AppState.swift rawctl/rawctl/Views/SettingsView.swift
git commit -m "feat(settings): add auto-advance and culling preferences"
```

---

### Task 18: Create PhotoGridToolbar with View Mode Switcher

**Files:**
- Create: `rawctl/rawctl/Components/PhotoGridToolbar.swift`

**Step 1: Create the toolbar component**

```swift
// rawctl/rawctl/Components/PhotoGridToolbar.swift
//
//  PhotoGridToolbar.swift
//  rawctl
//
//  Toolbar for photo grid with view modes and actions
//

import SwiftUI

/// View mode for photo grid
enum PhotoGridViewMode: String, CaseIterable {
    case grid = "Grid"
    case filmstrip = "Filmstrip"
    case loupe = "Loupe"

    var icon: String {
        switch self {
        case .grid: return "square.grid.3x3"
        case .filmstrip: return "film"
        case .loupe: return "photo"
        }
    }
}

/// Toolbar for photo grid operations
struct PhotoGridToolbar: View {
    @ObservedObject var appState: AppState

    @Binding var viewMode: PhotoGridViewMode
    @Binding var thumbnailSize: Double
    @Binding var showFilenames: Bool

    var onSurveyMode: () -> Void
    var onCompareMode: () -> Void
    var onBatchEdit: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // View mode picker
            Picker("View", selection: $viewMode) {
                ForEach(PhotoGridViewMode.allCases, id: \.self) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            Divider()
                .frame(height: 20)

            // Thumbnail size slider
            HStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(value: $thumbnailSize, in: 80...300, step: 20)
                    .frame(width: 100)

                Image(systemName: "photo.fill")
                    .foregroundColor(.secondary)
            }

            Toggle(isOn: $showFilenames) {
                Image(systemName: "textformat")
            }
            .toggleStyle(.button)
            .help("Show filenames")

            Spacer()

            // Quick actions
            HStack(spacing: 8) {
                Button {
                    onSurveyMode()
                } label: {
                    Label("Survey", systemImage: "rectangle.on.rectangle")
                }
                .keyboardShortcut("n", modifiers: .command)
                .help("Survey Mode (⌘N)")

                Button {
                    onCompareMode()
                } label: {
                    Label("Compare", systemImage: "square.split.2x1")
                }
                .keyboardShortcut("c", modifiers: .command)
                .help("Compare Mode (⌘C)")

                if !appState.selectedAssetIds.isEmpty {
                    Button {
                        onBatchEdit()
                    } label: {
                        Label("Batch Edit", systemImage: "slider.horizontal.3")
                    }
                    .help("Edit \(appState.selectedAssetIds.count) selected photos")
                }
            }

            Divider()
                .frame(height: 20)

            // Filter summary
            HStack(spacing: 6) {
                if appState.filterRating > 0 {
                    FilterBadge(
                        icon: "star.fill",
                        text: "≥\(appState.filterRating)",
                        color: .yellow
                    ) {
                        appState.filterRating = 0
                    }
                }

                if appState.filterFlag != nil {
                    FilterBadge(
                        icon: appState.filterFlag == .pick ? "flag.fill" : "xmark.circle.fill",
                        text: appState.filterFlag == .pick ? "Picks" : "Rejects",
                        color: appState.filterFlag == .pick ? .green : .red
                    ) {
                        appState.filterFlag = nil
                    }
                }

                if appState.activeSmartCollection != nil {
                    FilterBadge(
                        icon: "gearshape.fill",
                        text: appState.activeSmartCollection!.name,
                        color: .blue
                    ) {
                        appState.applySmartCollection(nil)
                    }
                }
            }

            // Count
            Text("\(appState.filteredAssets.count) photos")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

/// Small dismissible filter badge
struct FilterBadge: View {
    let icon: String
    let text: String
    let color: Color
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(color)

            Text(text)
                .font(.system(size: 10))

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(white: 0.2))
        .cornerRadius(10)
    }
}

#Preview {
    PhotoGridToolbar(
        appState: AppState(),
        viewMode: .constant(.grid),
        thumbnailSize: .constant(150),
        showFilenames: .constant(true),
        onSurveyMode: {},
        onCompareMode: {},
        onBatchEdit: {}
    )
    .preferredColorScheme(.dark)
}
```

**Step 2: Commit**

```bash
git add rawctl/rawctl/Components/PhotoGridToolbar.swift
git commit -m "feat(ui): add PhotoGridToolbar with view modes and filters"
```

---

## Phase 3: Export Automation (Tasks 19-24)

### Task 19: Create ExportPresetEditor View

**Files:**
- Create: `rawctl/rawctl/Views/ExportPresetEditor.swift`

**Step 1: Create the view**

```swift
// rawctl/rawctl/Views/ExportPresetEditor.swift
//
//  ExportPresetEditor.swift
//  rawctl
//
//  Editor for creating/modifying export presets
//

import SwiftUI

/// Editor for export presets
struct ExportPresetEditor: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var existingPreset: ExportPreset?
    var onSave: (ExportPreset) -> Void

    @State private var name: String = ""
    @State private var icon: String = "square.and.arrow.up"
    @State private var maxSize: Int? = nil
    @State private var quality: Int = 90
    @State private var format: ExportFormat = .jpeg
    @State private var colorSpace: String = "sRGB"
    @State private var addWatermark: Bool = false
    @State private var watermarkText: String = ""
    @State private var watermarkPosition: WatermarkPosition = .bottomRight
    @State private var renamePattern: String = "{original}"

    enum ExportFormat: String, CaseIterable {
        case jpeg = "JPEG"
        case tiff = "TIFF"
        case png = "PNG"
        case heic = "HEIC"
    }

    enum WatermarkPosition: String, CaseIterable {
        case topLeft = "Top Left"
        case topRight = "Top Right"
        case bottomLeft = "Bottom Left"
        case bottomRight = "Bottom Right"
        case center = "Center"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(existingPreset == nil ? "New Export Preset" : "Edit Preset")
                    .font(.title2.bold())
                Spacer()
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Form
            Form {
                Section("Basic") {
                    TextField("Preset Name", text: $name)
                        .textFieldStyle(.roundedBorder)

                    Picker("Format", selection: $format) {
                        ForEach(ExportFormat.allCases, id: \.self) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }

                    if format == .jpeg {
                        HStack {
                            Text("Quality")
                            Slider(value: Binding(
                                get: { Double(quality) },
                                set: { quality = Int($0) }
                            ), in: 60...100, step: 5)
                            Text("\(quality)%")
                                .frame(width: 40)
                        }
                    }
                }

                Section("Size") {
                    Picker("Max Size", selection: $maxSize) {
                        Text("Original").tag(nil as Int?)
                        Text("4K (3840px)").tag(3840 as Int?)
                        Text("1080p (1920px)").tag(1920 as Int?)
                        Text("Web (1200px)").tag(1200 as Int?)
                        Text("Social (1080px)").tag(1080 as Int?)
                        Text("Thumbnail (600px)").tag(600 as Int?)
                    }

                    Picker("Color Space", selection: $colorSpace) {
                        Text("sRGB").tag("sRGB")
                        Text("Adobe RGB").tag("AdobeRGB")
                        Text("Display P3").tag("DisplayP3")
                    }
                }

                Section("Watermark") {
                    Toggle("Add Watermark", isOn: $addWatermark)

                    if addWatermark {
                        TextField("Watermark Text", text: $watermarkText)
                            .textFieldStyle(.roundedBorder)

                        Picker("Position", selection: $watermarkPosition) {
                            ForEach(WatermarkPosition.allCases, id: \.self) { pos in
                                Text(pos.rawValue).tag(pos)
                            }
                        }
                    }
                }

                Section("File Naming") {
                    TextField("Pattern", text: $renamePattern)
                        .textFieldStyle(.roundedBorder)

                    Text("Available: {original}, {date}, {time}, {counter}, {rating}")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
            .padding()

            Divider()

            // Footer
            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button("Save Preset") {
                    savePreset()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
                .keyboardShortcut(.return)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 450, height: 520)
        .onAppear {
            if let preset = existingPreset {
                name = preset.name
                icon = preset.icon
                maxSize = preset.maxSize
                quality = preset.quality
                addWatermark = preset.addWatermark
            }
        }
    }

    private func savePreset() {
        let preset = ExportPreset(
            id: existingPreset?.id ?? UUID(),
            name: name,
            icon: icon,
            maxSize: maxSize,
            quality: quality,
            colorSpace: colorSpace,
            addWatermark: addWatermark,
            isBuiltIn: false
        )

        onSave(preset)
        dismiss()
    }
}

#Preview {
    ExportPresetEditor(
        appState: AppState(),
        onSave: { _ in }
    )
    .preferredColorScheme(.dark)
}
```

**Step 2: Commit**

```bash
git add rawctl/rawctl/Views/ExportPresetEditor.swift
git commit -m "feat(export): add ExportPresetEditor for custom presets"
```

---

### Task 20: Create SmartExportSheet View

**Files:**
- Create: `rawctl/rawctl/Views/SmartExportSheet.swift`

**Step 1: Create the view**

```swift
// rawctl/rawctl/Views/SmartExportSheet.swift
//
//  SmartExportSheet.swift
//  rawctl
//
//  Smart export with preset selection and auto-categorization
//

import SwiftUI

/// Smart export with presets and organization
struct SmartExportSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let assetsToExport: [PhotoAsset]

    @State private var selectedPreset: ExportPreset?
    @State private var destinationFolder: URL?
    @State private var organizationMode: OrganizationMode = .byRating
    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    @State private var exportedCount = 0
    @State private var showPresetEditor = false

    enum OrganizationMode: String, CaseIterable {
        case flat = "Flat (No folders)"
        case byRating = "By Rating (5★, 4★, etc.)"
        case byDate = "By Date (YYYY-MM-DD)"
        case byColor = "By Color Label"
        case byFlag = "Picks / Rejects"
    }

    private var presets: [ExportPreset] {
        appState.catalog?.exportPresets ?? [
            .clientPreview,
            .webGallery,
            .fullQuality,
            .socialMedia
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            HStack(spacing: 0) {
                // Left: Preset selection
                presetList
                    .frame(width: 200)

                Divider()

                // Right: Settings
                settingsPanel
            }

            Divider()

            // Footer
            footerView
        }
        .frame(width: 600, height: 450)
        .sheet(isPresented: $showPresetEditor) {
            ExportPresetEditor(appState: appState) { preset in
                if var catalog = appState.catalog {
                    catalog.addExportPreset(preset)
                    appState.catalog = catalog
                }
                selectedPreset = preset
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: "square.and.arrow.up")
                .font(.title2)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Export Photos")
                    .font(.headline)

                Text("\(assetsToExport.count) photos selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Close") {
                dismiss()
            }
            .keyboardShortcut(.escape)
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Preset List

    private var presetList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Presets")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 12)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(presets) { preset in
                        Button {
                            selectedPreset = preset
                        } label: {
                            HStack {
                                Image(systemName: preset.icon)
                                    .frame(width: 20)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.name)
                                        .font(.system(size: 12))

                                    Text(presetDescription(preset))
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if selectedPreset?.id == preset.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedPreset?.id == preset.id ? Color.accentColor.opacity(0.15) : Color.clear)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
            }

            Divider()
                .padding(.horizontal, 12)

            Button {
                showPresetEditor = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Create Preset")
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .padding(12)
        }
        .background(Color(white: 0.1))
    }

    // MARK: - Settings Panel

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Destination
            VStack(alignment: .leading, spacing: 6) {
                Text("Destination")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    if let folder = destinationFolder {
                        Text(folder.path)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("No folder selected")
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("Choose...") {
                        selectDestination()
                    }
                }
            }

            // Organization
            VStack(alignment: .leading, spacing: 6) {
                Text("Organization")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("", selection: $organizationMode) {
                    ForEach(OrganizationMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .labelsHidden()
            }

            // Preview
            if let preset = selectedPreset {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Export Settings")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Size:")
                            Spacer()
                            Text(preset.maxSize.map { "\($0)px" } ?? "Original")
                        }
                        HStack {
                            Text("Quality:")
                            Spacer()
                            Text("\(preset.quality)%")
                        }
                        HStack {
                            Text("Color Space:")
                            Spacer()
                            Text(preset.colorSpace)
                        }
                        HStack {
                            Text("Watermark:")
                            Spacer()
                            Text(preset.addWatermark ? "Yes" : "No")
                        }
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(12)
                    .background(Color(white: 0.15))
                    .cornerRadius(8)
                }
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            if isExporting {
                ProgressView(value: exportProgress)
                    .frame(width: 200)

                Text("\(exportedCount)/\(assetsToExport.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Cancel") {
                dismiss()
            }

            Button("Export \(assetsToExport.count) Photos") {
                Task {
                    await performExport()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedPreset == nil || destinationFolder == nil || isExporting)
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Helpers

    private func presetDescription(_ preset: ExportPreset) -> String {
        var parts: [String] = []
        if let size = preset.maxSize {
            parts.append("\(size)px")
        } else {
            parts.append("Original")
        }
        parts.append("\(preset.quality)%")
        return parts.joined(separator: " • ")
    }

    private func selectDestination() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "Select export destination"

        if panel.runModal() == .OK {
            destinationFolder = panel.url
        }
    }

    private func performExport() async {
        guard let preset = selectedPreset, let destination = destinationFolder else { return }

        isExporting = true
        exportedCount = 0
        exportProgress = 0

        let total = assetsToExport.count

        for (index, asset) in assetsToExport.enumerated() {
            let recipe = appState.recipes[asset.id] ?? EditRecipe()

            // Determine subfolder based on organization mode
            let subfolder = getSubfolder(for: asset, recipe: recipe)
            let targetFolder = subfolder.isEmpty ? destination : destination.appendingPathComponent(subfolder)

            // Create folder if needed
            try? FileManager.default.createDirectory(at: targetFolder, withIntermediateDirectories: true)

            // Export the photo
            let outputName = asset.url.deletingPathExtension().lastPathComponent + ".jpg"
            let outputURL = targetFolder.appendingPathComponent(outputName)

            if let image = await ImagePipeline.shared.renderPreview(
                for: asset,
                recipe: recipe,
                maxSize: preset.maxSize ?? 10000
            ) {
                if let tiff = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiff),
                   let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: Double(preset.quality) / 100.0]) {
                    try? jpeg.write(to: outputURL)
                }
            }

            await MainActor.run {
                exportedCount = index + 1
                exportProgress = Double(exportedCount) / Double(total)
            }
        }

        await MainActor.run {
            isExporting = false

            // Open destination folder
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: destination.path)

            dismiss()
        }
    }

    private func getSubfolder(for asset: PhotoAsset, recipe: EditRecipe) -> String {
        switch organizationMode {
        case .flat:
            return ""
        case .byRating:
            if recipe.rating >= 5 { return "5-Stars" }
            if recipe.rating >= 4 { return "4-Stars" }
            if recipe.rating >= 3 { return "3-Stars" }
            if recipe.rating >= 1 { return "Rated" }
            return "Unrated"
        case .byDate:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: asset.creationDate ?? Date())
        case .byColor:
            return recipe.colorLabel.displayName
        case .byFlag:
            switch recipe.flag {
            case .pick: return "Picks"
            case .reject: return "Rejects"
            case .none: return "Unflagged"
            }
        }
    }
}

#Preview {
    SmartExportSheet(
        appState: AppState(),
        assetsToExport: []
    )
    .preferredColorScheme(.dark)
}
```

**Step 2: Commit**

```bash
git add rawctl/rawctl/Views/SmartExportSheet.swift
git commit -m "feat(export): add SmartExportSheet with presets and auto-organization"
```

---

### Task 21: Create ExportService

**Files:**
- Create: `rawctl/rawctl/Services/ExportService.swift`
- Test: `rawctlTests/ExportServiceTests.swift`

**Step 1: Write the failing test**

```swift
// rawctlTests/ExportServiceTests.swift
import Testing
@testable import rawctl

struct ExportServiceTests {

    @Test func exportServiceCreatesCorrectFilename() async throws {
        let asset = PhotoAsset(url: URL(fileURLWithPath: "/tmp/IMG_001.ARW"))
        let pattern = "{date}_{original}"

        let result = ExportService.formatFilename(
            pattern: pattern,
            asset: asset,
            counter: 1,
            date: Date()
        )

        #expect(result.contains("IMG_001"))
    }

    @Test func exportServiceAppliesWatermark() async throws {
        // Create test image
        let image = NSImage(size: NSSize(width: 100, height: 100))

        let result = ExportService.applyWatermark(
            to: image,
            text: "© Test",
            position: .bottomRight
        )

        #expect(result != nil)
    }
}
```

**Step 2: Create the service**

```swift
// rawctl/rawctl/Services/ExportService.swift
//
//  ExportService.swift
//  rawctl
//
//  Service for exporting photos with presets
//

import Foundation
import AppKit

/// Service for exporting photos
actor ExportService {
    static let shared = ExportService()

    // MARK: - Export Operations

    /// Export a single photo with preset
    func export(
        asset: PhotoAsset,
        recipe: EditRecipe,
        preset: ExportPreset,
        to destination: URL
    ) async throws -> URL {
        // Render the image
        guard let image = await ImagePipeline.shared.renderPreview(
            for: asset,
            recipe: recipe,
            maxSize: preset.maxSize ?? 10000
        ) else {
            throw ExportError.renderFailed
        }

        // Apply watermark if needed
        var finalImage = image
        if preset.addWatermark {
            if let watermarked = Self.applyWatermark(
                to: image,
                text: "© \(Date().formatted(.dateTime.year()))",
                position: .bottomRight
            ) {
                finalImage = watermarked
            }
        }

        // Encode to format
        guard let data = encodeImage(finalImage, preset: preset) else {
            throw ExportError.encodingFailed
        }

        // Write file
        let outputURL = destination.appendingPathComponent(
            asset.url.deletingPathExtension().lastPathComponent + outputExtension(for: preset)
        )

        try data.write(to: outputURL)

        return outputURL
    }

    /// Batch export multiple photos
    func batchExport(
        assets: [PhotoAsset],
        recipes: [UUID: EditRecipe],
        preset: ExportPreset,
        to destination: URL,
        organization: OrganizationMode,
        progress: @escaping (Int, Int) -> Void
    ) async throws -> [URL] {
        var exportedURLs: [URL] = []

        for (index, asset) in assets.enumerated() {
            let recipe = recipes[asset.id] ?? EditRecipe()

            // Get subfolder
            let subfolder = getSubfolder(
                for: asset,
                recipe: recipe,
                mode: organization
            )

            let targetFolder = subfolder.isEmpty
                ? destination
                : destination.appendingPathComponent(subfolder)

            // Create folder
            try FileManager.default.createDirectory(
                at: targetFolder,
                withIntermediateDirectories: true
            )

            // Export
            let url = try await export(
                asset: asset,
                recipe: recipe,
                preset: preset,
                to: targetFolder
            )

            exportedURLs.append(url)
            progress(index + 1, assets.count)
        }

        return exportedURLs
    }

    // MARK: - Helpers

    static func formatFilename(
        pattern: String,
        asset: PhotoAsset,
        counter: Int,
        date: Date
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HHmmss"

        var result = pattern
        result = result.replacingOccurrences(of: "{original}", with: asset.url.deletingPathExtension().lastPathComponent)
        result = result.replacingOccurrences(of: "{date}", with: dateFormatter.string(from: date))
        result = result.replacingOccurrences(of: "{time}", with: timeFormatter.string(from: date))
        result = result.replacingOccurrences(of: "{counter}", with: String(format: "%04d", counter))

        return result
    }

    static func applyWatermark(
        to image: NSImage,
        text: String,
        position: WatermarkPosition
    ) -> NSImage? {
        let size = image.size
        let newImage = NSImage(size: size)

        newImage.lockFocus()

        // Draw original
        image.draw(in: NSRect(origin: .zero, size: size))

        // Draw watermark
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size.width * 0.03),
            .foregroundColor: NSColor.white.withAlphaComponent(0.7)
        ]

        let textSize = text.size(withAttributes: attributes)
        let padding: CGFloat = size.width * 0.02

        var point: NSPoint
        switch position {
        case .topLeft:
            point = NSPoint(x: padding, y: size.height - textSize.height - padding)
        case .topRight:
            point = NSPoint(x: size.width - textSize.width - padding, y: size.height - textSize.height - padding)
        case .bottomLeft:
            point = NSPoint(x: padding, y: padding)
        case .bottomRight:
            point = NSPoint(x: size.width - textSize.width - padding, y: padding)
        case .center:
            point = NSPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2)
        }

        text.draw(at: point, withAttributes: attributes)

        newImage.unlockFocus()

        return newImage
    }

    private func encodeImage(_ image: NSImage, preset: ExportPreset) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return nil
        }

        return bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: Double(preset.quality) / 100.0]
        )
    }

    private func outputExtension(for preset: ExportPreset) -> String {
        return ".jpg"
    }

    private func getSubfolder(
        for asset: PhotoAsset,
        recipe: EditRecipe,
        mode: OrganizationMode
    ) -> String {
        switch mode {
        case .flat:
            return ""
        case .byRating:
            if recipe.rating >= 5 { return "5-Stars" }
            if recipe.rating >= 4 { return "4-Stars" }
            if recipe.rating >= 3 { return "3-Stars" }
            if recipe.rating >= 1 { return "Rated" }
            return "Unrated"
        case .byDate:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: asset.creationDate ?? Date())
        case .byColor:
            return recipe.colorLabel.displayName
        case .byFlag:
            switch recipe.flag {
            case .pick: return "Picks"
            case .reject: return "Rejects"
            case .none: return "Unflagged"
            }
        }
    }

    enum OrganizationMode {
        case flat, byRating, byDate, byColor, byFlag
    }

    enum WatermarkPosition {
        case topLeft, topRight, bottomLeft, bottomRight, center
    }
}

enum ExportError: Error, LocalizedError {
    case renderFailed
    case encodingFailed
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .renderFailed: return "Failed to render image"
        case .encodingFailed: return "Failed to encode image"
        case .writeFailed: return "Failed to write file"
        }
    }
}
```

**Step 3: Commit**

```bash
git add rawctl/rawctl/Services/ExportService.swift rawctlTests/ExportServiceTests.swift
git commit -m "feat(export): add ExportService for photo export operations"
```

---

### Task 22-24: Export Queue and Background Processing

**Tasks 22-24 follow the same pattern, implementing:**
- Task 22: `ExportQueueManager` for background batch exports
- Task 23: `ExportProgressView` showing active exports
- Task 24: Integration with menu bar and notifications

---

## Phase 4: Advanced Features (Tasks 25-30)

### Task 25: Create ProjectDashboard View

**Files:**
- Create: `rawctl/rawctl/Views/ProjectDashboard.swift`

**Step 1: Create the view**

```swift
// rawctl/rawctl/Views/ProjectDashboard.swift
//
//  ProjectDashboard.swift
//  rawctl
//
//  Dashboard showing project progress and statistics
//

import SwiftUI

/// Dashboard view for project progress
struct ProjectDashboard: View {
    @ObservedObject var appState: AppState

    let project: Project

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with project info
                projectHeader

                // Progress stats
                progressCards

                // Quick actions
                quickActions

                // Recent activity
                recentActivity
            }
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header

    private var projectHeader: some View {
        HStack(spacing: 16) {
            // Project icon
            Image(systemName: project.projectType.icon)
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
                .frame(width: 60, height: 60)
                .background(Color.accentColor.opacity(0.15))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.title2.bold())

                HStack(spacing: 8) {
                    if let client = project.clientName {
                        Text(client)
                            .foregroundColor(.secondary)
                    }

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(project.shootDate.formatted(.dateTime.month().day().year()))
                        .foregroundColor(.secondary)
                }
                .font(.caption)
            }

            Spacer()

            // Status badge
            statusBadge
        }
        .padding()
        .background(Color(white: 0.1))
        .cornerRadius(12)
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(
                    red: project.status.color.r,
                    green: project.status.color.g,
                    blue: project.status.color.b
                ))
                .frame(width: 8, height: 8)

            Text(project.status.displayName)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(white: 0.15))
        .cornerRadius(12)
    }

    // MARK: - Progress Cards

    private var progressCards: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatCard(
                title: "Total",
                value: "\(project.totalPhotos)",
                icon: "photo.on.rectangle",
                color: .blue
            )

            StatCard(
                title: "Rated",
                value: "\(project.ratedPhotos)",
                icon: "star.fill",
                color: .yellow,
                progress: progressRated
            )

            StatCard(
                title: "Picks",
                value: "\(project.flaggedPhotos)",
                icon: "flag.fill",
                color: .green
            )

            StatCard(
                title: "Exported",
                value: "\(project.exportedPhotos)",
                icon: "arrow.up.doc",
                color: .purple,
                progress: progressExported
            )
        }
    }

    private var progressRated: Double {
        guard project.totalPhotos > 0 else { return 0 }
        return Double(project.ratedPhotos) / Double(project.totalPhotos)
    }

    private var progressExported: Double {
        guard project.totalPhotos > 0 else { return 0 }
        return Double(project.exportedPhotos) / Double(project.totalPhotos)
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 12) {
                ActionButton(
                    title: "Start Culling",
                    icon: "rectangle.on.rectangle",
                    color: .orange
                ) {
                    // Open survey mode
                }

                ActionButton(
                    title: "Export Picks",
                    icon: "square.and.arrow.up",
                    color: .green
                ) {
                    // Export picks
                }

                ActionButton(
                    title: "Open in Finder",
                    icon: "folder",
                    color: .blue
                ) {
                    if let folder = project.sourceFolders.first {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folder.path)
                    }
                }
            }
        }
        .padding()
        .background(Color(white: 0.1))
        .cornerRadius(12)
    }

    // MARK: - Recent Activity

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)

            VStack(spacing: 8) {
                ActivityRow(
                    icon: "photo",
                    text: "Project created",
                    date: project.createdAt
                )

                if let lastOpened = project.lastOpened {
                    ActivityRow(
                        icon: "eye",
                        text: "Last opened",
                        date: lastOpened
                    )
                }
            }
        }
        .padding()
        .background(Color(white: 0.1))
        .cornerRadius(12)
    }
}

/// Stat card component
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var progress: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.title.bold())

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            if let progress = progress {
                ProgressView(value: progress)
                    .tint(color)
            }
        }
        .padding()
        .background(Color(white: 0.1))
        .cornerRadius(12)
    }
}

/// Action button component
struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.15))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

/// Activity row component
struct ActivityRow: View {
    let icon: String
    let text: String
    let date: Date

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
            Text(text)
            Spacer()
            Text(date.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ProjectDashboard(
        appState: AppState(),
        project: Project(name: "Test Wedding", shootDate: Date(), projectType: .wedding)
    )
    .frame(width: 600, height: 500)
    .preferredColorScheme(.dark)
}
```

**Step 2: Commit**

```bash
git add rawctl/rawctl/Views/ProjectDashboard.swift
git commit -m "feat(ui): add ProjectDashboard with progress stats"
```

---

### Tasks 26-30: Advanced Features (Placeholders)

**Task 26**: Memory Card Auto-Detection Service
- Monitor `/Volumes` for new mounts
- Detect DCIM folder structure
- Auto-prompt import sheet

**Task 27**: Project Timeline View
- Visual timeline of project progression
- Activity log and milestones

**Task 28**: Batch Edit Presets
- Save/load edit settings as presets
- Apply to selection or smart collection

**Task 29**: Client Delivery Portal Integration
- Generate shareable links
- Track client selections

**Task 30**: Workflow Automation Rules
- Auto-apply ratings based on EXIF
- Auto-organize by camera/lens
- Scheduled exports

---

## Summary

| Phase | Tasks | Focus |
|-------|-------|-------|
| Phase 1 | 1-12 | Catalog foundation, new sidebar |
| Phase 2 | 13-18 | Survey mode, compare view, batch ops |
| Phase 3 | 19-24 | Export presets, smart export |
| Phase 4 | 25-30 | Dashboard, automation |

**Total Tasks:** 30 bite-sized tasks
**Estimated Implementation:** Follow TDD cycle per task
