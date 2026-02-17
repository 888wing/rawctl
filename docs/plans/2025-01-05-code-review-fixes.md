# Code Review Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix all critical and major issues identified in the code review for rawctl UI/UX optimization.

**Architecture:** Replace legacy GCD patterns with Swift Concurrency, add proper error handling for all async operations, implement task cancellation for memory safety, and resolve code duplication.

**Tech Stack:** Swift 5.9+, SwiftUI, Swift Concurrency (async/await, Task, actors)

---

## Phase 1: Critical Issues - Concurrency Patterns (Tasks 1-4)

### Task 1: Fix DispatchQueue in SurveyModeView

**Files:**
- Modify: `rawctl/rawctl/Views/SurveyModeView.swift:326-329`

**Step 1: Replace DispatchQueue with Task.sleep**

Replace this code at line 326-329:
```swift
// OLD - problematic
DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
    navigateNext()
}
```

With:
```swift
// NEW - proper Swift Concurrency
Task { @MainActor in
    try? await Task.sleep(for: .milliseconds(150))
    navigateNext()
}
```

**Step 2: Build to verify**

Run: `xcodebuild -scheme rawctl -configuration Debug build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add rawctl/Views/SurveyModeView.swift
git commit -m "fix(concurrency): replace DispatchQueue with Task.sleep in SurveyModeView"
```

---

### Task 2: Fix DispatchQueue in CullingView (setRating)

**Files:**
- Modify: `rawctl/rawctl/Views/CullingView.swift:335-338`

**Step 1: Replace DispatchQueue with Task.sleep**

Replace at line 335-338:
```swift
// OLD
DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
    navigateNext()
}
```

With:
```swift
// NEW
Task { @MainActor in
    try? await Task.sleep(for: .milliseconds(300))
    navigateNext()
}
```

**Step 2: Build to verify**

Run: `xcodebuild -scheme rawctl -configuration Debug build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add rawctl/Views/CullingView.swift
git commit -m "fix(concurrency): replace DispatchQueue in CullingView.setRating"
```

---

### Task 3: Fix DispatchQueue in CullingView (setFlag)

**Files:**
- Modify: `rawctl/rawctl/Views/CullingView.swift:356-360`

**Step 1: Replace DispatchQueue with Task.sleep**

Replace at line 356-360:
```swift
// OLD
if autoAdvance && flag != .none {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        navigateNext()
    }
}
```

With:
```swift
// NEW
if autoAdvance && flag != .none {
    Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(300))
        navigateNext()
    }
}
```

**Step 2: Build to verify**

Run: `xcodebuild -scheme rawctl -configuration Debug build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add rawctl/Views/CullingView.swift
git commit -m "fix(concurrency): replace DispatchQueue in CullingView.setFlag"
```

---

### Task 4: Add Error Handling in CreateProjectSheet

**Files:**
- Modify: `rawctl/rawctl/Views/CreateProjectSheet.swift:152-156`

**Step 1: Add state for error alert**

Add at the top of CreateProjectSheet struct (after `@State private var notes`):
```swift
@State private var showSaveError = false
@State private var saveErrorMessage = ""
```

**Step 2: Replace fire-and-forget Task with error handling**

Replace at line 152-156:
```swift
// OLD
Task {
    let service = CatalogService(catalogPath: CatalogService.defaultCatalogPath)
    try? await service.save(catalog)
}
```

With:
```swift
// NEW
Task {
    do {
        let service = CatalogService(catalogPath: CatalogService.defaultCatalogPath)
        try await service.save(catalog)
    } catch {
        await MainActor.run {
            saveErrorMessage = "Failed to save catalog: \(error.localizedDescription)"
            showSaveError = true
        }
    }
}
```

**Step 3: Add alert modifier to view body**

Add at end of body (before closing brace):
```swift
.alert("Save Error", isPresented: $showSaveError) {
    Button("OK", role: .cancel) { }
} message: {
    Text(saveErrorMessage)
}
```

**Step 4: Build to verify**

Run: `xcodebuild -scheme rawctl -configuration Debug build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add rawctl/Views/CreateProjectSheet.swift
git commit -m "fix(error): add error handling for catalog save in CreateProjectSheet"
```

---

## Phase 2: Critical Issues - Error Handling (Tasks 5-8)

### Task 5: Add Error Handling in CreateSmartCollectionSheet

**Files:**
- Modify: `rawctl/rawctl/Views/CreateSmartCollectionSheet.swift:124-128`

**Step 1: Add state for error alert**

Add after existing @State properties:
```swift
@State private var showSaveError = false
@State private var saveErrorMessage = ""
```

**Step 2: Replace fire-and-forget Task**

Replace at line 124-128:
```swift
// OLD
Task {
    let service = CatalogService(catalogPath: CatalogService.defaultCatalogPath)
    try? await service.save(catalog)
}
```

With:
```swift
// NEW
Task {
    do {
        let service = CatalogService(catalogPath: CatalogService.defaultCatalogPath)
        try await service.save(catalog)
    } catch {
        await MainActor.run {
            saveErrorMessage = "Failed to save: \(error.localizedDescription)"
            showSaveError = true
        }
    }
}
```

**Step 3: Add alert modifier**

Add at end of body:
```swift
.alert("Save Error", isPresented: $showSaveError) {
    Button("OK", role: .cancel) { }
} message: {
    Text(saveErrorMessage)
}
```

**Step 4: Build and commit**

```bash
xcodebuild -scheme rawctl -configuration Debug build 2>&1 | tail -10
git add rawctl/Views/CreateSmartCollectionSheet.swift
git commit -m "fix(error): add error handling in CreateSmartCollectionSheet"
```

---

### Task 6: Add Error Handling in SmartExportSheet

**Files:**
- Modify: `rawctl/rawctl/Views/SmartExportSheet.swift:278-301`

**Step 1: Add state for tracking failures**

Add after existing @State properties:
```swift
@State private var failedExports: [String] = []
```

**Step 2: Replace try? with proper error tracking**

Replace the export loop (lines 278-302) with:
```swift
// Create folder if needed
do {
    try FileManager.default.createDirectory(
        at: targetFolder,
        withIntermediateDirectories: true
    )
} catch {
    await MainActor.run {
        failedExports.append("\(asset.url.lastPathComponent): folder creation failed")
    }
    continue
}

// Export the photo
let outputName = asset.url.deletingPathExtension().lastPathComponent + ".jpg"
let outputURL = targetFolder.appendingPathComponent(outputName)

// Render and save
let maxSizeValue = CGFloat(preset.maxSize ?? 4000)
if let image = await ImagePipeline.shared.renderPreview(
    for: asset,
    recipe: recipe,
    maxSize: maxSizeValue
) {
    if let tiffData = image.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiffData),
       let jpegData = bitmap.representation(
           using: NSBitmapImageRep.FileType.jpeg,
           properties: [NSBitmapImageRep.PropertyKey.compressionFactor: Double(preset.quality) / 100.0]
       ) {
        do {
            try jpegData.write(to: outputURL)
        } catch {
            await MainActor.run {
                failedExports.append("\(asset.url.lastPathComponent): write failed")
            }
        }
    }
}
```

**Step 3: Show failure summary after export**

After the export loop completes, before dismiss():
```swift
if !failedExports.isEmpty {
    // Log failures (or show alert)
    print("Export failures: \(failedExports.joined(separator: ", "))")
}
```

**Step 4: Build and commit**

```bash
xcodebuild -scheme rawctl -configuration Debug build 2>&1 | tail -10
git add rawctl/Views/SmartExportSheet.swift
git commit -m "fix(error): add error tracking in SmartExportSheet export"
```

---

### Task 7: Add Error Handling in ExportQueueManager

**Files:**
- Modify: `rawctl/rawctl/Views/ExportProgressView.swift:163-201`

**Step 1: Add error tracking to ExportQueueItem**

Modify ExportQueueItem struct (around line 98):
```swift
struct ExportQueueItem: Identifiable {
    let id: UUID = UUID()
    let assets: [PhotoAsset]
    let recipes: [UUID: EditRecipe]
    let preset: ExportPreset
    let destination: URL
    let organization: ExportOrganizationMode
    var status: QueueStatus = .pending
    var completedCount: Int = 0
    var failedCount: Int = 0  // ADD THIS
    var errorMessages: [String] = []  // ADD THIS

    // ... rest of struct
}
```

**Step 2: Update processItem to track errors**

Replace `try jpegData.write(to: outputURL)` with proper error handling that increments failedCount.

**Step 3: Build and commit**

```bash
xcodebuild -scheme rawctl -configuration Debug build 2>&1 | tail -10
git add rawctl/Views/ExportProgressView.swift
git commit -m "fix(error): add error tracking in ExportQueueManager"
```

---

### Task 8: Change Compare Mode Keyboard Shortcut

**Files:**
- Modify: `rawctl/rawctl/Components/PhotoGridToolbar.swift:88`

**Step 1: Change shortcut from Cmd+C to Cmd+Option+C**

Replace line 88:
```swift
// OLD
.keyboardShortcut("c", modifiers: .command)
.help("Compare Mode (Cmd+C)")
```

With:
```swift
// NEW
.keyboardShortcut("c", modifiers: [.command, .option])
.help("Compare Mode (Cmd+Option+C)")
```

**Step 2: Build and commit**

```bash
xcodebuild -scheme rawctl -configuration Debug build 2>&1 | tail -10
git add rawctl/Components/PhotoGridToolbar.swift
git commit -m "fix(ux): change Compare Mode shortcut to Cmd+Option+C to avoid conflict"
```

---

## Phase 3: Major Issues - Memory & Code Quality (Tasks 9-12)

### Task 9: Add Task Cancellation to SurveyModeView

**Files:**
- Modify: `rawctl/rawctl/Views/SurveyModeView.swift`

**Step 1: Add loadTask state**

Add after existing @State properties:
```swift
@State private var loadTask: Task<Void, Never>?
```

**Step 2: Cancel previous task before starting new load**

Modify `loadCurrentImage()` (around line 339):
```swift
private func loadCurrentImage() async {
    // Cancel any existing load task
    loadTask?.cancel()

    guard let asset = currentAsset else { return }

    loadTask = Task {
        isLoading = true
        let recipe = appState.recipes[asset.id] ?? EditRecipe()

        if let image = await ImagePipeline.shared.renderPreview(
            for: asset,
            recipe: recipe,
            maxSize: 1600
        ) {
            // Check for cancellation before updating UI
            guard !Task.isCancelled else { return }
            await MainActor.run {
                previewImage = image
                isLoading = false
            }
        }
    }
}
```

**Step 3: Cancel on disappear**

Add to body:
```swift
.onDisappear {
    loadTask?.cancel()
}
```

**Step 4: Build and commit**

```bash
xcodebuild -scheme rawctl -configuration Debug build 2>&1 | tail -10
git add rawctl/Views/SurveyModeView.swift
git commit -m "fix(memory): add task cancellation in SurveyModeView"
```

---

### Task 10: Extract Shared determineTargetFolder Utility

**Files:**
- Create: `rawctl/rawctl/Services/ExportUtilities.swift`
- Modify: `rawctl/rawctl/Views/SmartExportSheet.swift`
- Modify: `rawctl/rawctl/Views/ExportProgressView.swift`

**Step 1: Create shared utility file**

Create `rawctl/rawctl/Services/ExportUtilities.swift`:
```swift
//
//  ExportUtilities.swift
//  rawctl
//
//  Shared export utilities for folder organization
//

import Foundation

/// Shared export utilities
enum ExportUtilities {
    /// Determine target folder based on organization mode
    static func determineTargetFolder(
        for asset: PhotoAsset,
        recipe: EditRecipe,
        organization: ExportOrganizationMode,
        base: URL
    ) -> URL {
        switch organization {
        case .flat:
            return base

        case .byRating:
            let rating = recipe.rating
            let folderName = rating > 0 ? "\(rating)-stars" : "unrated"
            return base.appendingPathComponent(folderName)

        case .byDate:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let folderName = formatter.string(from: asset.creationDate ?? Date())
            return base.appendingPathComponent(folderName)

        case .byColor:
            return base.appendingPathComponent(recipe.colorLabel.displayName)

        case .byFlag:
            switch recipe.flag {
            case .pick: return base.appendingPathComponent("Picks")
            case .reject: return base.appendingPathComponent("Rejects")
            case .none: return base.appendingPathComponent("Unflagged")
            }
        }
    }
}
```

**Step 2: Update SmartExportSheet to use shared utility**

Replace `determineTargetFolder` function call with:
```swift
let targetFolder = ExportUtilities.determineTargetFolder(
    for: asset,
    recipe: recipe,
    organization: organizationMode,
    base: destination
)
```

Remove the local `determineTargetFolder` function.

**Step 3: Update ExportProgressView to use shared utility**

Same change - use `ExportUtilities.determineTargetFolder` and remove local function.

**Step 4: Build and commit**

```bash
xcodebuild -scheme rawctl -configuration Debug build 2>&1 | tail -10
git add rawctl/Services/ExportUtilities.swift rawctl/Views/SmartExportSheet.swift rawctl/Views/ExportProgressView.swift
git commit -m "refactor(dry): extract shared determineTargetFolder utility"
```

---

### Task 11: Implement Context Menu Actions in ProjectsSection

**Files:**
- Modify: `rawctl/rawctl/Components/Sidebar/ProjectsSection.swift:193-206`

**Step 1: Implement Set Status action**

Replace empty Button action at line 195-197:
```swift
ForEach(ProjectStatus.allCases, id: \.self) { status in
    Button(status.displayName) {
        updateProjectStatus(project, to: status)
    }
}
```

**Step 2: Add helper function**

Add after `projectContextMenu`:
```swift
private func updateProjectStatus(_ project: Project, to status: ProjectStatus) {
    guard var catalog = appState.catalog else { return }
    var updatedProject = project
    updatedProject.status = status
    catalog.updateProject(updatedProject)
    appState.catalog = catalog

    Task {
        let service = CatalogService(catalogPath: CatalogService.defaultCatalogPath)
        try? await service.save(catalog)
    }
}
```

**Step 3: Implement Archive action**

Replace empty archive button at line 203-205:
```swift
Button("Archive Project", role: .destructive) {
    updateProjectStatus(project, to: .archived)
}
```

**Step 4: Build and commit**

```bash
xcodebuild -scheme rawctl -configuration Debug build 2>&1 | tail -10
git add rawctl/Components/Sidebar/ProjectsSection.swift
git commit -m "feat(ui): implement context menu actions in ProjectsSection"
```

---

### Task 12: Wire Up ProjectDashboard Quick Actions

**Files:**
- Modify: `rawctl/rawctl/Views/ProjectDashboard.swift:145-175`

**Step 1: Add bindings for navigation**

Add to ProjectDashboard struct:
```swift
var onStartCulling: (() -> Void)?
var onExportPicks: (() -> Void)?
```

**Step 2: Wire up button actions**

Replace empty closures at lines 159-161 and 167-168:
```swift
DashboardActionButton(
    title: "Start Culling",
    icon: "rectangle.on.rectangle",
    color: .orange
) {
    onStartCulling?()
}

DashboardActionButton(
    title: "Export Picks",
    icon: "square.and.arrow.up",
    color: .green
) {
    onExportPicks?()
}
```

**Step 3: Update Preview**

Update #Preview to include closures:
```swift
#Preview {
    ProjectDashboard(
        appState: AppState(),
        project: Project(name: "Test Wedding", shootDate: Date(), projectType: .wedding),
        onStartCulling: { print("Start culling") },
        onExportPicks: { print("Export picks") }
    )
    .frame(width: 600, height: 500)
    .preferredColorScheme(.dark)
}
```

**Step 4: Build and commit**

```bash
xcodebuild -scheme rawctl -configuration Debug build 2>&1 | tail -10
git add rawctl/Views/ProjectDashboard.swift
git commit -m "feat(ui): wire up ProjectDashboard quick action buttons"
```

---

## Summary

| Phase | Tasks | Focus |
|-------|-------|-------|
| Phase 1 | 1-4 | Concurrency patterns (DispatchQueue → Task) |
| Phase 2 | 5-8 | Error handling (try? → proper error reporting) |
| Phase 3 | 9-12 | Memory safety & code quality |

**Total Tasks:** 12 bite-sized tasks
**Estimated Implementation:** ~1-2 hours following TDD cycle

---

## Verification Checklist

After all tasks complete:
- [ ] Run full build: `xcodebuild -scheme rawctl -configuration Debug build`
- [ ] Test Survey Mode auto-advance
- [ ] Test Culling View auto-advance
- [ ] Test Create Project with error scenario
- [ ] Test Smart Export with error scenario
- [ ] Verify Cmd+Option+C opens Compare Mode
- [ ] Verify context menu actions work in Projects sidebar
