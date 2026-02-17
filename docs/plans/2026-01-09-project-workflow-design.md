# Project 工作流程設計 v2

完整 Project 管理系統，支援多目錄、狀態恢復、.lrcat 匯入。

**v2 更新**：根據 Code Review 修正架構衝突，與現有代碼庫整合。

## 1. 需求摘要

| 功能 | 選擇 |
|------|------|
| Project 狀態 | 完整狀態（多目錄、篩選、排序、上次選中照片） |
| 管理 UI | 側邊欄 Projects 列表 |
| .lrcat 支援 | 完整匯入（路徑、元數據、編輯參數轉換） |
| 啟動行為 | 自動恢復上次 Project |

---

## 2. 資料模型設計

### 2.1 擴展現有 Project 結構（非替換）

**現有結構**（`/rawctl/Models/Project.swift`）：
```swift
struct Project: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var clientName: String?
    var shootDate: Date
    var projectType: ProjectType
    var sourceFolders: [URL]           // 保留現有類型
    var outputFolder: URL?
    var status: ProjectStatus
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    // statistics...
}
```

**新增欄位**（擴展而非替換）：
```swift
struct Project: Identifiable, Codable, Equatable {
    // === 現有欄位（保持不變） ===
    let id: UUID
    var name: String
    var clientName: String?
    var shootDate: Date
    var projectType: ProjectType
    var sourceFolders: [URL]           // 保留 [URL] 類型
    var outputFolder: URL?
    var status: ProjectStatus
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    var totalPhotos: Int
    var ratedPhotos: Int
    var flaggedPhotos: Int
    var exportedPhotos: Int

    // === 新增：狀態記憶（v2） ===
    var lastSelectedPhotoPath: String?          // URL path，避免 URL Codable 問題
    var savedFilterState: SavedFilterState?     // 篩選條件
    var sortCriteria: SortCriteria?             // 重用現有 enum
    var sortAscending: Bool?
    var savedViewMode: ViewMode?                // grid / single
    var gridZoomLevel: Double?

    // === 新增：Bookmark 數據（v2） ===
    var folderBookmarks: [String: Data]?        // path -> bookmark data

    // === 新增：匯入來源（v2） ===
    var importSource: ProjectImportSource?
}
```

### 2.2 SavedFilterState（新結構，避免衝突）

**重要**：現有 `AppState.FilterState` 是 UI 狀態，不 Codable。建立新的持久化結構：

```swift
/// 可持久化的篩選狀態（用於 Project 保存）
struct SavedFilterState: Codable, Equatable {
    var minRating: Int                      // 0 = no filter
    var flagFilter: Flag?                   // nil = no filter
    var colorLabel: ColorLabel?             // nil = no filter
    var tag: String                         // "" = no filter

    init() {
        self.minRating = 0
        self.flagFilter = nil
        self.colorLabel = nil
        self.tag = ""
    }

    /// 從 AppState 當前篩選狀態創建
    init(from appState: AppState) {
        self.minRating = appState.filterRating
        self.flagFilter = appState.filterFlag
        self.colorLabel = appState.filterColor
        self.tag = appState.filterTag
    }

    /// 應用到 AppState
    func apply(to appState: AppState) {
        appState.filterRating = minRating
        appState.filterFlag = flagFilter
        appState.filterColor = colorLabel
        appState.filterTag = tag
    }

    var hasActiveFilters: Bool {
        minRating > 0 || flagFilter != nil || colorLabel != nil || !tag.isEmpty
    }
}
```

### 2.3 ProjectImportSource（匯入來源追蹤）

```swift
enum ProjectImportSource: Codable, Equatable {
    case native                                         // rawctl 原生
    case lightroom(catalogPath: String, importedAt: Date, lastSyncVersion: Int64?)

    var isLightroomImport: Bool {
        if case .lightroom = self { return true }
        return false
    }
}
```

### 2.4 Catalog 結構更新

**修改現有 Catalog**（`/rawctl/Models/Catalog.swift`）：

```swift
struct Catalog: Codable, Equatable {
    static let currentVersion = 2          // 版本升級 1 → 2

    var version: Int
    var libraryPath: URL
    var projects: [Project]
    var smartCollections: [SmartCollection]   // 保持在 Catalog 層級（global）
    var importPreferences: ImportPreferences
    var exportPresets: [ExportPreset]
    var lastOpenedProjectId: UUID?
    var createdAt: Date
    var updatedAt: Date

    // === 新增：Project 專屬 Smart Collections（v2） ===
    var projectSmartCollections: [UUID: [SmartCollection]]  // projectId -> collections

    // MARK: - 版本遷移

    /// 從 v1 遷移到 v2
    mutating func migrateToV2() {
        guard version < 2 else { return }

        // 1. 初始化新欄位
        if projectSmartCollections == nil {
            projectSmartCollections = [:]
        }

        // 2. 為現有 projects 設置預設值（新欄位都是 optional，所以 decode 會成功）
        // 不需要特殊處理，Codable 會自動處理 nil

        // 3. 更新版本號
        version = 2
        updatedAt = Date()
    }
}
```

### 2.5 FolderManager 整合

**保留現有 FolderSource**（`/rawctl/Services/FolderManager.swift`）：
```swift
struct FolderSource: Identifiable, Codable {
    let id: UUID
    var url: URL
    var name: String
    var isDefault: Bool
    var isLoaded: Bool
    var assetCount: Int
    var lastOpened: Date?
    var bookmarkData: Data?
}
```

**Project 與 FolderSource 的關係**：
- `Project.sourceFolders: [URL]` 保持現有類型
- `Project.folderBookmarks: [String: Data]?` 新增 bookmark 映射
- 載入 Project 時，從 `folderBookmarks` 恢復 sandbox 權限

```swift
extension Project {
    /// 獲取帶 bookmark 的 FolderSource
    func getFolderSources() -> [FolderSource] {
        sourceFolders.map { url in
            var source = FolderSource(url: url)
            source.bookmarkData = folderBookmarks?[url.path]
            return source
        }
    }

    /// 保存當前 bookmark 數據
    mutating func saveBookmarks(from folderManager: FolderManager) {
        var bookmarks: [String: Data] = [:]
        for url in sourceFolders {
            if let source = folderManager.sources.first(where: { $0.url == url }),
               let data = source.bookmarkData {
                bookmarks[url.path] = data
            }
        }
        folderBookmarks = bookmarks.isEmpty ? nil : bookmarks
    }
}
```

### 2.6 Smart Collections 範圍設計

**設計決策**：

| 範圍 | 說明 | 位置 |
|------|------|------|
| **Global** | 內建 collections（5 Stars、Picks 等） | `Catalog.smartCollections` |
| **Per-Project** | 用戶為特定 project 創建的 collections | `Catalog.projectSmartCollections[projectId]` |

**載入邏輯**：
```swift
func getSmartCollections(for project: Project?) -> [SmartCollection] {
    var collections = catalog.smartCollections  // Global collections

    if let projectId = project?.id,
       let projectCollections = catalog.projectSmartCollections[projectId] {
        collections.append(contentsOf: projectCollections)
    }

    return collections
}
```

---

## 3. UI 設計

### 3.1 側邊欄 Projects 列表

```
┌─────────────────────────────────────────────────────────┐
│ rawctl                                                  │
├──────────────┬──────────────────────────────────────────┤
│ PROJECTS     │                                          │
│ ┌──────────┐ │                                          │
│ │+ New     │ │                                          │
│ └──────────┘ │                                          │
│              │                                          │
│ ★ Wedding    │              Grid View                   │
│   2026-01    │                                          │
│              │                                          │
│   Portrait   │                                          │
│   Studio     │                                          │
│              │                                          │
│ ─────────────│                                          │
│ SMART        │                                          │
│ ⭐ 5 Stars   │  (global)                                │
│ 🚩 Picks     │  (global)                                │
│ 🏷 Client A  │  (project-specific)                      │
│              │                                          │
├──────────────┼──────────────────────────────────────────┤
│ SOURCES      │                                          │
│ 📁 /Photos   │              Filmstrip                   │
│ 📁 /RAW      │                                          │
└──────────────┴──────────────────────────────────────────┘
```

### 3.2 Project 右鍵選單

```
├─ Open
├─ Rename...
├─ ──────────
├─ Add Folder...
├─ Import .lrcat...
├─ ──────────
├─ Create Smart Collection...
├─ ──────────
├─ Duplicate
├─ Delete
```

---

## 4. 啟動流程

### 4.1 App 啟動順序

```swift
// rawctlApp.swift 或 AppState.init
func onAppLaunch() async {
    // 1. 載入 Catalog
    catalog = catalogService.load()

    // 2. 遷移舊版資料
    if catalog.version < 2 {
        catalog.migrateToV2()
        catalogService.save(catalog)
    }

    // 3. 恢復上次 Project
    if let lastProjectId = catalog.lastOpenedProjectId,
       let project = catalog.projects.first(where: { $0.id == lastProjectId }) {
        await restoreProject(project)
    }
}

func restoreProject(_ project: Project) async {
    // 1. 恢復 sandbox 權限並載入目錄
    for url in project.sourceFolders {
        if let bookmarkData = project.folderBookmarks?[url.path] {
            await loadFolderFromBookmark(url: url, bookmarkData: bookmarkData)
        }
    }

    // 2. 恢復篩選狀態
    if let savedFilter = project.savedFilterState {
        savedFilter.apply(to: self)
    }

    // 3. 恢復排序
    if let criteria = project.sortCriteria {
        sortCriteria = criteria
    }
    if let ascending = project.sortAscending {
        sortAscending = ascending
    }

    // 4. 恢復視圖模式
    if let mode = project.savedViewMode {
        viewMode = mode
    }
    if let zoom = project.gridZoomLevel {
        gridZoomLevel = zoom
    }

    // 5. 恢復選中照片（延遲執行，等資產載入完成）
    if let photoPath = project.lastSelectedPhotoPath {
        await selectPhotoByPath(photoPath)
    }

    // 6. 更新 lastOpenedAt
    updateProjectLastOpened(project.id)
}
```

### 4.2 狀態保存時機

```swift
enum ProjectSaveTrigger {
    case folderAdded            // 新增目錄
    case folderRemoved          // 移除目錄
    case filterChanged          // 篩選條件變更（debounced 500ms）
    case sortChanged            // 排序變更
    case photoSelected          // 選中照片（debounced 2s）
    case viewModeChanged        // 視圖切換
    case appWillTerminate       // App 即將關閉
    case projectSwitched        // 切換 Project（保存舊 project 狀態）
}
```

### 4.3 狀態保存實現

```swift
extension AppState {
    /// 保存當前狀態到 Project
    func saveCurrentStateToProject() {
        guard var project = selectedProject else { return }

        // 保存篩選狀態
        project.savedFilterState = SavedFilterState(from: self)

        // 保存排序
        project.sortCriteria = sortCriteria
        project.sortAscending = sortAscending

        // 保存視圖
        project.savedViewMode = viewMode
        project.gridZoomLevel = gridZoomLevel

        // 保存選中照片
        if let selectedId = selectedAssetId,
           let asset = assets.first(where: { $0.id == selectedId }) {
            project.lastSelectedPhotoPath = asset.url.path
        }

        // 保存 bookmarks
        project.saveBookmarks(from: folderManager)

        // 更新 catalog
        catalog?.updateProject(project)
        selectedProject = project
    }
}
```

---

## 5. .lrcat 匯入設計

### 5.1 錯誤處理（Critical Fix）

```swift
enum LRCatImportError: Error, LocalizedError {
    case fileNotFound(path: String)
    case corruptDatabase(detail: String)
    case unsupportedVersion(detected: String, minimum: String)
    case pathResolutionFailed(originalPath: String, reason: String)
    case permissionDenied(path: String)
    case partialImportFailure(imported: Int, failed: Int, errors: [String])
    case cancelled

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Catalog file not found: \(path)"
        case .corruptDatabase(let detail):
            return "Catalog database is corrupted: \(detail)"
        case .unsupportedVersion(let detected, let minimum):
            return "Unsupported Lightroom version \(detected). Minimum required: \(minimum)"
        case .pathResolutionFailed(let path, let reason):
            return "Cannot resolve photo path '\(path)': \(reason)"
        case .permissionDenied(let path):
            return "Permission denied for folder: \(path)"
        case .partialImportFailure(let imported, let failed, _):
            return "Import partially completed: \(imported) imported, \(failed) failed"
        case .cancelled:
            return "Import was cancelled"
        }
    }
}
```

### 5.2 Lightroom Catalog 結構

`.lrcat` 是 SQLite 資料庫，關鍵表：

| 表名 | 用途 | 版本支援 |
|------|------|---------|
| `AgLibraryFile` | 檔案路徑 | All |
| `AgLibraryFolder` | 目錄結構 | All |
| `Adobe_images` | 照片主記錄 | All |
| `AgHarvestedExifMetadata` | EXIF 數據 | All |
| `AgLibraryKeyword` | 關鍵字/標籤 | All |
| `AgLibraryKeywordImage` | 照片-關鍵字關聯 | All |
| `Adobe_imageDevelopSettings` | 編輯參數 | LR 4+ |
| `AgInternedExifCameraModel` | 相機型號 | All |

### 5.3 匯入流程

```swift
class LRCatImporter {
    private let catalogPath: URL
    private var db: SQLiteConnection?
    private var progress: ImportProgress?

    struct ImportProgress {
        var phase: ImportPhase
        var current: Int
        var total: Int
        var errors: [String]

        enum ImportPhase {
            case connecting
            case readingFolders
            case readingPhotos
            case readingMetadata
            case convertingEdits
            case finalizing
        }
    }

    func import(
        from catalogPath: URL,
        progressHandler: @escaping (ImportProgress) -> Void
    ) async throws -> Project {

        // 1. 驗證檔案
        guard FileManager.default.fileExists(atPath: catalogPath.path) else {
            throw LRCatImportError.fileNotFound(path: catalogPath.path)
        }

        // 2. 連接資料庫
        progress = ImportProgress(phase: .connecting, current: 0, total: 0, errors: [])
        progressHandler(progress!)

        do {
            db = try SQLiteConnection(path: catalogPath)
        } catch {
            throw LRCatImportError.corruptDatabase(detail: error.localizedDescription)
        }

        // 3. 檢查版本
        let version = try checkLightroomVersion()
        guard version >= "4.0" else {
            throw LRCatImportError.unsupportedVersion(detected: version, minimum: "4.0")
        }

        // 4. 讀取目錄（with error collection）
        progress?.phase = .readingFolders
        let (folders, folderErrors) = try extractFoldersWithErrors()
        progress?.errors.append(contentsOf: folderErrors)

        // 5. 讀取照片
        progress?.phase = .readingPhotos
        let (photos, photoErrors) = try extractPhotosWithErrors()
        progress?.errors.append(contentsOf: photoErrors)

        // 6. 讀取元數據
        progress?.phase = .readingMetadata
        try await loadMetadataInBatches(photos: photos, batchSize: 500, progressHandler: progressHandler)

        // 7. 轉換編輯參數
        progress?.phase = .convertingEdits
        try await convertDevelopSettingsInBatches(photos: photos, batchSize: 100, progressHandler: progressHandler)

        // 8. 建立 Project
        progress?.phase = .finalizing
        let project = createProject(
            name: catalogPath.deletingPathExtension().lastPathComponent,
            folders: folders,
            photos: photos
        )

        // 9. 報告結果
        let successCount = photos.filter { $0.importStatus == .success }.count
        let failCount = photos.count - successCount

        if failCount > 0 && successCount > 0 {
            // Partial success - still return project but throw warning
            throw LRCatImportError.partialImportFailure(
                imported: successCount,
                failed: failCount,
                errors: progress?.errors ?? []
            )
        }

        return project
    }

    private func extractFoldersWithErrors() throws -> ([URL], [String]) {
        var folders: [URL] = []
        var errors: [String] = []

        let query = """
            SELECT pathFromRoot, absolutePath
            FROM AgLibraryFolder
            WHERE pathFromRoot IS NOT NULL
        """

        for row in try db!.query(query) {
            let path = row["absolutePath"] as? String ?? row["pathFromRoot"] as? String ?? ""
            let url = URL(fileURLWithPath: path)

            if FileManager.default.fileExists(atPath: url.path) {
                folders.append(url)
            } else {
                errors.append("Folder not found: \(path)")
            }
        }

        return (folders, errors)
    }
}
```

### 5.4 編輯參數轉換對照表

| Lightroom 參數 | rawctl 參數 | 轉換公式 |
|---------------|-------------|---------|
| `Exposure2012` | `exposure` | 直接對應 |
| `Contrast2012` | `contrast` | `value / 100` |
| `Highlights2012` | `highlights` | `value / 100` |
| `Shadows2012` | `shadows` | `value / 100` |
| `Whites2012` | `whites` | `value / 100` |
| `Blacks2012` | `blacks` | `value / 100` |
| `Temperature` | `whiteBalance.temperature` | Kelvin 直接對應 |
| `Tint` | `whiteBalance.tint` | 直接對應 |
| `Vibrance` | `vibrance` | `value / 100` |
| `Saturation` | `saturation` | `value / 100` |
| `CropTop/Left/Bottom/Right` | `crop` | 百分比轉換 |
| `StraightenAngle` | `crop.straightenAngle` | 直接對應 |

**無法轉換的參數**（記錄並略過）：
- 局部調整（Graduated Filter, Radial Filter, Adjustment Brush）
- 色調曲線細節點
- HSL 細節調整
- 鏡頭校正配置
- 降噪/銳化高級設定

### 5.5 匯入進度 UI

```
┌─────────────────────────────────────────────────────────┐
│ Import Lightroom Catalog                                │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ Catalog: /Photos/Lightroom Catalog.lrcat                │
│ Version: Lightroom Classic 12.4                         │
│                                                         │
│ Progress: Reading photos...                             │
│ ████████████░░░░░░░░░░░░░░░░░░░░░░░░░  847/1,247        │
│                                                         │
│ ⚠️ 3 warnings:                                          │
│   • Folder not found: /Volumes/External/2023           │
│   • Cannot convert local adjustments (15 photos)       │
│   • Missing keywords table (using fallback)            │
│                                                         │
│                    [Cancel]  [Continue Anyway]          │
└─────────────────────────────────────────────────────────┘
```

---

## 6. 實施計劃

### Phase 1：核心 Project 狀態系統（2-3 天）

| 任務 | 預估 | 說明 |
|------|------|------|
| 1.1 擴展 Project struct | 2h | 新增 optional 欄位，保持向後相容 |
| 1.2 創建 SavedFilterState | 1h | 新結構，避免與 AppState.FilterState 衝突 |
| 1.3 實作 Catalog v1→v2 遷移 | 1h | 簡單升級，新欄位都是 optional |
| 1.4 實作 Project 狀態保存 | 3h | saveCurrentStateToProject() |
| 1.5 實作 Project 狀態恢復 | 3h | restoreProject() |
| 1.6 整合啟動流程 | 2h | onAppLaunch() 調用 |
| 1.7 測試與除錯 | 2h | |

### Phase 2：側邊欄 UI（1-2 天）

| 任務 | 預估 |
|------|------|
| 2.1 建立 ProjectsSidebarView | 3h |
| 2.2 實作 Project 切換邏輯 | 2h |
| 2.3 新建/重命名/刪除 Project | 2h |
| 2.4 右鍵選單功能 | 1h |
| 2.5 測試與除錯 | 2h |

### Phase 3：.lrcat 匯入（3-4 天）

| 任務 | 預估 | 說明 |
|------|------|------|
| 3.1 研究 .lrcat SQLite 結構 | 3h | 增加緩衝時間 |
| 3.2 實作 LRCatImporter 基礎 + 錯誤處理 | 4h | 包含完整錯誤類型 |
| 3.3 實作元數據提取 | 2h | |
| 3.4 實作編輯參數轉換 | 4h | |
| 3.5 匯入進度 UI（含警告顯示） | 3h | |
| 3.6 測試各版本 Lightroom catalog | 3h | LR 2020-2024 |

### Phase 4：整合測試（1 天）

| 任務 | 預估 |
|------|------|
| 4.1 端到端測試 | 3h |
| 4.2 效能優化（大量照片） | 2h |
| 4.3 文檔更新 | 1h |

---

## 7. 技術考量

### 7.1 Security-Scoped Bookmarks

```swift
func loadFolderFromBookmark(url: URL, bookmarkData: Data) async throws {
    var isStale = false
    let resolvedURL = try URL(
        resolvingBookmarkData: bookmarkData,
        options: .withSecurityScope,
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
    )

    guard resolvedURL.startAccessingSecurityScopedResource() else {
        throw ProjectError.bookmarkAccessDenied(url: url)
    }

    // 如果 bookmark 已過期，重新創建
    if isStale {
        let newBookmarkData = try resolvedURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        // 更新 project 中的 bookmark
        updateProjectBookmark(url: url, data: newBookmarkData)
    }

    await loadFolder(resolvedURL)
}
```

### 7.2 大型 Catalog 效能

對於 >10,000 張照片的 .lrcat：
- 分批讀取，每批 500 張
- 顯示匯入進度
- 背景執行，不阻塞 UI
- 支援取消操作

### 7.3 向後相容

- Catalog v1 自動遷移為 v2
- 舊版 Project 保持正常運作（新欄位都是 optional）
- 舊版 sidecar JSON 保持相容
- 匯入的 .lrcat 不修改原檔案

---

## 8. 風險與緩解

| 風險 | 可能性 | 影響 | 緩解措施 |
|------|--------|------|---------|
| Lightroom catalog 格式變更 | 中 | 中 | 支援多版本、優雅降級、詳細錯誤訊息 |
| 大量照片效能問題 | 中 | 高 | 分頁載入、背景處理、進度顯示 |
| Bookmark 過期 | 低 | 中 | 自動檢測並提示用戶重新授權 |
| 編輯參數轉換不準確 | 高 | 低 | 明確告知限制、保留原始值、顯示警告 |
| 現有 Project 數據損壞 | 低 | 高 | v2 migration 保守處理、新欄位都 optional |

---

## 9. 成功標準

- [ ] 啟動自動恢復上次 Project 及完整狀態
- [ ] 現有 Projects 正常運作（向後相容）
- [ ] 可建立、切換、刪除多個 Projects
- [ ] 側邊欄顯示 Projects 列表和 Smart Collections
- [ ] 成功匯入 Lightroom Classic 2020+ 的 .lrcat
- [ ] 匯入元數據（rating, flag, color, keywords）準確率 >99%
- [ ] 基本編輯參數轉換可用（exposure, contrast, WB, crop）
- [ ] 匯入失敗時顯示詳細錯誤訊息和警告
- [ ] 匯入 5000 張照片 <30 秒（M1 Mac）

---

## 10. 與現有代碼的整合點

### 需要修改的檔案

| 檔案 | 修改類型 | 說明 |
|------|---------|------|
| `Models/Project.swift` | 擴展 | 新增 optional 欄位 |
| `Models/Catalog.swift` | 擴展 | version=2, projectSmartCollections |
| `Models/AppState.swift` | 新增方法 | saveCurrentStateToProject(), restoreProject() |
| `Services/CatalogService.swift` | 新增方法 | migrateToV2() 調用 |
| `Views/Sidebar/` | 新增 | ProjectsSidebarView |
| `Services/LRCatImporter.swift` | 新增 | 完整匯入邏輯 |

### 不需要修改的檔案

| 檔案 | 原因 |
|------|------|
| `Services/FolderManager.swift` | 保持現有 FolderSource 結構 |
| `Models/SmartCollection.swift` | 結構不變，只是放置位置有變 |
| `AppState.FilterState` | 保持為 UI 狀態，不改為 Codable |
| `AppState.SortCriteria` | 直接重用，不新建 |
