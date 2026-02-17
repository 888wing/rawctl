# rawctl Bug Fixes - Complete Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix all identified bugs and incomplete features in the rawctl macOS photo editor application.

**Architecture:** SwiftUI-based macOS app with MVVM pattern. AppState manages global state with @Published properties. Catalog system handles project/collection persistence via CatalogService actor.

**Tech Stack:** SwiftUI, Swift Concurrency (async/await), AppKit integration, JSON persistence

---

## Priority Overview

| Priority | Issue | Impact |
|----------|-------|--------|
| P0 | Multi-folder loading only loads first folder | Core functionality broken |
| P1 | Smart Collection Edit/Delete empty handlers | Feature incomplete |
| P2 | Update SmartCollection in catalog | Missing update method |

---

## Task 1: Fix Multi-Folder Loading in selectProject()

**Files:**
- Modify: `rawctl/rawctl/Models/AppState.swift:141-155`

**Context:** When a project has multiple source folders (supported via CreateProjectSheet multi-folder selection), only the first folder is loaded. Need to merge assets from all source folders.

**Step 1: Read current implementation**

Current code at line 141-155:
```swift
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
```

**Step 2: Implement multi-folder loading**

Replace `selectProject()` with:
```swift
/// Select a project and load assets from ALL source folders
func selectProject(_ project: Project) async {
    selectedProject = project
    activeSmartCollection = nil

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

        // Load all recipes
        await loadAllRecipes()

        // Select first asset
        if let first = assets.first {
            selectedAssetId = first.id
        }

        // Start thumbnail preloading
        preloadThumbnails()
    }

    // Update catalog's last opened
    if var cat = catalog {
        cat.lastOpenedProjectId = project.id
        catalog = cat
    }
}
```

**Step 3: Run build to verify compilation**

Run: `cd /Users/chuisiufai/Projects/rawctl && xcodebuild -project rawctl.xcodeproj -scheme rawctl -configuration Debug build 2>&1 | head -50`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add rawctl/rawctl/Models/AppState.swift
git commit -m "fix: load all source folders when selecting project

Previously only the first folder was loaded. Now iterates through
all sourceFolders and merges assets from each folder."
```

---

## Task 2: Add updateSmartCollection Method to Catalog

**Files:**
- Modify: `rawctl/rawctl/Models/Catalog.swift:174-184`

**Context:** Catalog has `addSmartCollection` and `removeSmartCollection` but no `updateSmartCollection` method. Need to add it for the Edit functionality.

**Step 1: Add updateSmartCollection method**

Add after `removeSmartCollection` (around line 185):
```swift
mutating func updateSmartCollection(_ collection: SmartCollection) {
    if let index = smartCollections.firstIndex(where: { $0.id == collection.id }) {
        // Only allow updating non-built-in collections
        if !smartCollections[index].isBuiltIn {
            smartCollections[index] = collection
            updatedAt = Date()
        }
    }
}
```

**Step 2: Run build to verify compilation**

Run: `cd /Users/chuisiufai/Projects/rawctl && xcodebuild -project rawctl.xcodeproj -scheme rawctl -configuration Debug build 2>&1 | head -50`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add rawctl/rawctl/Models/Catalog.swift
git commit -m "feat(catalog): add updateSmartCollection method

Allows updating non-built-in smart collections. Built-in collections
are protected from modification."
```

---

## Task 3: Implement Smart Collection Edit/Delete Handlers

**Files:**
- Modify: `rawctl/rawctl/Components/Sidebar/SmartCollectionsSection.swift:71-132`

**Context:** The SmartCollectionRow has empty Edit and Delete button handlers in the context menu. Need to implement actual functionality.

**Step 1: Add state variables and callbacks to SmartCollectionRow**

Update SmartCollectionRow struct to include callbacks:
```swift
/// Single smart collection row
struct SmartCollectionRow: View {
    let collection: SmartCollection
    let count: Int
    let isSelected: Bool
    let onSelect: () -> Void
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        Button(action: onSelect) {
            // ... existing HStack content unchanged ...
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !collection.isBuiltIn {
                Button("Edit Collection...") {
                    onEdit?()
                }

                Divider()

                Button("Delete Collection", role: .destructive) {
                    onDelete?()
                }
            }
        }
    }

    // ... iconColor unchanged ...
}
```

**Step 2: Add state and handlers to SmartCollectionsSection**

Update SmartCollectionsSection to manage edit/delete:
```swift
struct SmartCollectionsSection: View {
    @ObservedObject var appState: AppState
    @State private var isExpanded = true
    @State private var showCreateCollection = false
    @State private var collectionToEdit: SmartCollection?
    @State private var showDeleteConfirmation = false
    @State private var collectionToDelete: SmartCollection?

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
                        },
                        onEdit: {
                            collectionToEdit = collection
                        },
                        onDelete: {
                            collectionToDelete = collection
                            showDeleteConfirmation = true
                        }
                    )
                }

                // Create Smart Collection button - unchanged
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
        .sheet(item: $collectionToEdit) { collection in
            EditSmartCollectionSheet(appState: appState, collection: collection)
        }
        .alert("Delete Collection", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteCollection()
            }
        } message: {
            if let collection = collectionToDelete {
                Text("Are you sure you want to delete \"\(collection.name)\"? This cannot be undone.")
            }
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

    private func deleteCollection() {
        guard let collection = collectionToDelete else { return }

        // Clear active collection if it's being deleted
        if appState.activeSmartCollection?.id == collection.id {
            appState.applySmartCollection(nil)
        }

        // Remove from catalog
        if var catalog = appState.catalog {
            catalog.removeSmartCollection(collection.id)
            appState.catalog = catalog

            // Save catalog
            Task {
                do {
                    let service = CatalogService(catalogPath: CatalogService.defaultCatalogPath)
                    try await service.save(catalog)
                } catch {
                    print("[SmartCollectionsSection] Failed to save catalog: \(error)")
                }
            }
        }

        collectionToDelete = nil
    }
}
```

**Step 3: Run build to verify compilation**

Run: `cd /Users/chuisiufai/Projects/rawctl && xcodebuild -project rawctl.xcodeproj -scheme rawctl -configuration Debug build 2>&1 | head -50`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add rawctl/rawctl/Components/Sidebar/SmartCollectionsSection.swift
git commit -m "feat: implement Smart Collection Edit and Delete functionality

- Add onEdit and onDelete callbacks to SmartCollectionRow
- Add collectionToEdit state for edit sheet
- Add delete confirmation alert
- Implement deleteCollection() with catalog persistence"
```

---

## Task 4: Create EditSmartCollectionSheet

**Files:**
- Create: `rawctl/rawctl/Views/EditSmartCollectionSheet.swift`

**Context:** Need a sheet for editing existing smart collections. Similar to CreateSmartCollectionSheet but pre-populated with existing values.

**Step 1: Create EditSmartCollectionSheet.swift**

```swift
//
//  EditSmartCollectionSheet.swift
//  rawctl
//
//  Sheet for editing an existing smart collection
//

import SwiftUI

/// Sheet for editing a smart collection
struct EditSmartCollectionSheet: View {
    @ObservedObject var appState: AppState
    let collection: SmartCollection
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var icon: String = "folder.badge.gearshape"
    @State private var minRating: Int = 0
    @State private var colorLabel: ColorLabel?
    @State private var flag: Flag?
    @State private var hasEdits: Bool?
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""

    private let icons = [
        "folder.badge.gearshape",
        "star.fill",
        "heart.fill",
        "flag.fill",
        "tag.fill",
        "camera.fill",
        "photo.fill",
        "sparkles"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Smart Collection")
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
                Section("Collection Details") {
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)

                    Picker("Icon", selection: $icon) {
                        ForEach(icons, id: \.self) { iconName in
                            Label(iconName, systemImage: iconName)
                                .tag(iconName)
                        }
                    }
                }

                Section("Filter Criteria") {
                    Picker("Minimum Rating", selection: $minRating) {
                        Text("Any Rating").tag(0)
                        ForEach(1...5, id: \.self) { rating in
                            HStack {
                                ForEach(0..<rating, id: \.self) { _ in
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                }
                            }
                            .tag(rating)
                        }
                    }

                    Picker("Color Label", selection: $colorLabel) {
                        Text("Any Color").tag(nil as ColorLabel?)
                        ForEach(ColorLabel.allCases) { color in
                            HStack {
                                Circle()
                                    .fill(Color(red: color.rgb.r, green: color.rgb.g, blue: color.rgb.b))
                                    .frame(width: 12, height: 12)
                                Text(color.name)
                            }
                            .tag(color as ColorLabel?)
                        }
                    }

                    Picker("Flag", selection: $flag) {
                        Text("Any Flag").tag(nil as Flag?)
                        ForEach(Flag.allCases) { f in
                            Label(f.name, systemImage: f.icon)
                                .tag(f as Flag?)
                        }
                    }

                    Picker("Edit Status", selection: $hasEdits) {
                        Text("Any").tag(nil as Bool?)
                        Text("Edited Only").tag(true as Bool?)
                        Text("Unedited Only").tag(false as Bool?)
                    }
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

                Button("Save Changes") {
                    saveCollection()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
                .keyboardShortcut(.return)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 400, height: 420)
        .alert("Save Error", isPresented: $showSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveErrorMessage)
        }
        .onAppear {
            // Pre-populate with existing values
            name = collection.name
            icon = collection.icon
            minRating = collection.minRating ?? 0
            colorLabel = collection.colorLabel
            flag = collection.flag
            hasEdits = collection.hasEdits
        }
    }

    private func saveCollection() {
        var updatedCollection = collection
        updatedCollection.name = name
        updatedCollection.icon = icon
        updatedCollection.minRating = minRating > 0 ? minRating : nil
        updatedCollection.colorLabel = colorLabel
        updatedCollection.flag = flag
        updatedCollection.hasEdits = hasEdits

        // Update in catalog
        if var catalog = appState.catalog {
            catalog.updateSmartCollection(updatedCollection)
            appState.catalog = catalog

            // Update active collection if it's the one being edited
            if appState.activeSmartCollection?.id == collection.id {
                appState.activeSmartCollection = updatedCollection
            }

            // Save catalog
            Task {
                do {
                    let service = CatalogService(catalogPath: CatalogService.defaultCatalogPath)
                    try await service.save(catalog)
                } catch {
                    await MainActor.run {
                        saveErrorMessage = "Failed to save catalog: \(error.localizedDescription)"
                        showSaveError = true
                    }
                    return
                }
            }
        }

        dismiss()
    }
}

#Preview {
    EditSmartCollectionSheet(
        appState: AppState(),
        collection: SmartCollection(
            name: "Test Collection",
            icon: "star.fill",
            minRating: 3,
            colorLabel: nil,
            flag: .pick,
            hasEdits: nil
        )
    )
    .preferredColorScheme(.dark)
}
```

**Step 2: Run build to verify compilation**

Run: `cd /Users/chuisiufai/Projects/rawctl && xcodebuild -project rawctl.xcodeproj -scheme rawctl -configuration Debug build 2>&1 | head -50`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add rawctl/rawctl/Views/EditSmartCollectionSheet.swift
git commit -m "feat: add EditSmartCollectionSheet for editing smart collections

Pre-populates form with existing collection values and saves changes
to catalog. Updates activeSmartCollection if the edited collection
is currently selected."
```

---

## Task 5: Verify All Fixes Work Together

**Step 1: Full build verification**

Run: `cd /Users/chuisiufai/Projects/rawctl && xcodebuild -project rawctl.xcodeproj -scheme rawctl -configuration Debug build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 2: Manual testing checklist**

Test the following scenarios:
- [ ] Create project with multiple folders - all folders' photos should appear
- [ ] Select existing project - should load all source folders
- [ ] Create new smart collection - sheet appears and saves
- [ ] Edit smart collection (right-click) - edit sheet appears with pre-filled values
- [ ] Delete smart collection (right-click) - confirmation appears and collection is removed
- [ ] Built-in collections should NOT show Edit/Delete options

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat: complete bug fixes for multi-folder loading and smart collections

Summary of fixes:
- Multi-folder projects now load assets from all source folders
- Smart Collection Edit functionality implemented
- Smart Collection Delete with confirmation implemented
- Added updateSmartCollection method to Catalog"
```

---

## Summary of Changes

| File | Change |
|------|--------|
| `AppState.swift` | Rewrite `selectProject()` to load all source folders |
| `Catalog.swift` | Add `updateSmartCollection()` method |
| `SmartCollectionsSection.swift` | Implement Edit/Delete handlers with callbacks |
| `EditSmartCollectionSheet.swift` | New file for editing smart collections |

## Future Improvements (Lower Priority)

These items were identified but are not critical for MVP:

1. **Google Sign In** - Alternative auth method (Apple Sign In works)
2. **Recent Imports** - Track recently imported photos
3. **Devices/Memory Card** - Auto-detect and import from memory cards
4. **Project Management Panel** - Enhanced project overview UI
