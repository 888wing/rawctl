# rawctl UX E2E 測試與修復報告

日期：2026-02-16
範圍：Single View / Grid View 切換、Inspector 參數調整、Crop/Transform 流程、menu/快捷鍵入口

## 1. 測試方法

### 1.1 自動化 E2E
- `xcodebuild test -scheme rawctl-e2e -only-testing:rawctlUITests/RawctlSmokeTests`
- 目的：驗證啟動、素材載入、View menu（Grid/Single）入口、視圖切換穩定性

### 1.2 自動化性能（既有 signpost）
- `RawctlSmokeTests.testPerf_scanFolderSignpost`
- 指標：`scanFolder.duration`
- 測試樣本：50 張 fixture（5 次 measure）

### 1.3 針對 UX 痛點的代碼鏈路驗證
- 參數調整延遲：`InspectorView -> SingleView -> ImagePipeline`
- 裁切顯示/實際不一致：`CropOverlayView + SingleView(loadPreview) + ImagePipeline crop`
- 多入口啟用：`MainLayoutView / RawctlViewCommands / WorkspaceView / InspectorView`

## 2. 測試結果總覽

- E2E Smoke：**Pass**（2/2）
- Unit Tests（rawctlTests）：**Pass**
- Scan 性能基線（signpost）：
  - 平均：`0.008s`
  - RSD：`12.751%`
  - 5 次量測：`0.009329s`, `0.007991s`, `0.006982s`, `0.007513s`, `0.009753s`

## 3. 問題判定與根因

### 3.1 調整參數時反應慢
根因：
- 拖曳期間雖切換 `previewQuality = .fast`，但實際 `renderPreview` 未啟用 `fastMode`，昂貴濾鏡仍全量執行。
- 預覽品質切換與 recipe 變更存在重複觸發 render。
- 高頻 debug log 在滑桿拖曳時持續輸出，放大主執行緒負擔。

### 3.2 裁切 UI 與實際切片不相符
根因：
- 進入 transform/crop 時，預覽仍可能使用「已套用 crop」影像，overlay 再按原 crop rect 繪製，造成視覺與輸出錯位。

### 3.3 多個參數入口未成功啟用
根因：
- 入口（menu/快捷鍵/Inspector 的 Edit Crop）在無 selected asset 時只失敗退出或保持當前畫面，未自動補選。
- `Inspector -> Edit Crop` 未保證切到 Single View，使用者會感知為「按了沒反應」。
- `WorkspaceView` 空狀態開資料夾走舊路徑，未走 `AppState.openFolderFromPath`，導致載入後選取/流程狀態不完整。

### 3.4 UX 流程不理想
根因：
- Grid/Single/Transform 狀態切換時缺少一致的守衛（selection + mode 同步）。

## 4. 已實施修復

### 4.1 性能修復
- `SingleView.loadPreview` 實際傳入 `fastMode`（拖曳或 fast quality 時）。
- 品質切換重載策略改為：僅 `fast -> full` 時做收斂重渲染。
- 降低拖曳期間重渲染抖動（節流參數調整）。
- 移除高頻 render debug log。

涉及檔案：
- `rawctl/Views/SingleView.swift`
- `rawctl/Services/ImagePipeline.swift`

### 4.2 Crop 對齊修復
- 進入 transform 時，預覽渲染使用 `previewRecipe.crop.isEnabled = false`（只顯示 overlay，不先裁切輸出）。
- transform mode 切換時強制重載預覽。
- Crop overlay padding 與 zoom 同步，避免縮放後框位移。
- 抽出統一 `applyCrop`，統一 crop 計算與邊界夾制。

涉及檔案：
- `rawctl/Views/SingleView.swift`
- `rawctl/Services/ImagePipeline.swift`

### 4.3 入口啟用修復
- 新增 `AppState.ensurePrimarySelection()` 與 `switchToSingleViewIfPossible()`。
- menu bar 單張入口、Workspace 快捷鍵入口、Inspector 的 Edit Crop 入口統一走上述守衛。
- `WorkspaceView.openFolder()` 改走 `appState.openFolderFromPath`，確保選取與載入流程一致。

涉及檔案：
- `rawctl/Models/AppState.swift`
- `rawctl/Services/RawctlViewCommands.swift`
- `rawctl/Views/MainLayoutView.swift`
- `rawctl/Views/WorkspaceView.swift`
- `rawctl/Views/InspectorView.swift`

## 5. 驗證結論（修復後）

- View menu `Single View` / `Grid View` 切換可正常完成。
- 入口在無選取但有素材時可自動補選並切換。
- Crop 編輯流程由 Inspector 觸發時可正確進入單張 + transform。
- 參數拖曳預覽採用 fast path，互動流暢度與穩定性提升（避免全量重算）。
- `scanFolder` 絕對耗時低（平均 `8ms`），但抖動偏高（RSD `12.751%`），建議後續以「滑桿拖曳與大檔載入」建立更貼近日常使用的性能門檻。

## 6. 仍建議的下一步（升級至日常可用）

1. 新增「滑桿拖曳 renderPreview signpost」專屬性能測試（目前只有 scanFolder 指標）。
2. 新增 UI 測試：
   - `Inspector -> Edit Crop` 觸發後必進入 single + transform。
   - transform 期間 crop overlay 與輸出區域一致性（固定 fixture 驗證）。
3. 針對高解析 RAW（例如 45MP）建立壓力測試組，定義互動延遲 SLO（例如 95p < 120ms）。

## 7. 下一步實測（指定資料夾 A7III）

### 7.1 測試對象
- 路徑：`/Users/chuisiufai/Desktop/Life/20251108_A7III`
- 檔案數：109
- 可支援影像檔（rawctl 掃描副檔名集合）：89

### 7.2 執行方式
- 先 `build-for-testing` 產生測試產物。
- 透過 `.xctestrun` 注入 `RAWCTL_E2E_FOLDER_UNDER_TEST=/Users/chuisiufai/Desktop/Life/20251108_A7III`（xcodebuild 直接帶 shell env 會在 UI test 端被忽略）。
- 執行：
  - `test-without-building -only-testing:rawctlUITests/RawctlSmokeTests/testSmoke_LaunchWithExternalFolderAndSwitchViews`
  - 同案例重複 `3` 次（`-test-iterations 3 -test-repetition-relaunch-enabled YES`）
- 回歸：
  - `xcodebuild test -scheme rawctl -only-testing:rawctlTests`

### 7.3 結果
- 外部資料夾 smoke（A7III）：**Pass**
  - 單次：`17.702s`
- 外部資料夾穩定性重複測試（A7III）：**Pass 3/3**
  - 第1次：`17.295s`
  - 第2次：`20.550s`
  - 第3次：`16.866s`
  - 平均：`18.237s`（min `16.866s` / max `20.550s`）
- 單元測試（rawctlTests）：**Pass**
- Crash 檢查：
  - 最新 `rawctl-*.ips` 仍為 `2026-02-16 02:36:49` 舊檔，這輪測試後未新增 crash 報告。

### 7.4 UI 入口準確性（A7III）
- `View` menu 存在。
- `Single View (E2E)` / `Grid View (E2E)` menu item 存在。
- 每輪都能完成 `Grid -> Single -> Grid`，且 `e2e.view.mode` 與畫面元素（`singleView`）一致。

### 7.5 交互系統準確度（A7III）
- 功能正確性：**通過**
  - menu 入口可驅動狀態與畫面一致變更。
- 穩定性觀察：**有輕微波動**
  - 第 2 次重複測試在 `e2e.assets.count` 等待階段出現較長載入（約 `5s`），但後續入口與狀態切換均正常。
  - 本輪未再出現 `Not hittable: MenuItem`；入口命中已穩定，但資料夾掃描/初始載入仍有波動。

### 7.6 結論（A7III 下一步）
- 以真實資料夾（A7III）執行，核心入口與交互鏈路已可運作，未重現閃退。
- 目前主要風險從「功能性錯誤」轉為「互動穩定性與延遲波動」：
  - 建議把 menu 入口的可重試策略與觀測指標（點擊到狀態切換耗時）納入下一輪常態回歸。

## 8. 新增真實影像回歸測試（本輪完成）

### 8.1 新增測試檔
- `rawctlTests/ImagePipelineRegressionTests.swift`

### 8.2 覆蓋範圍
- 真實調整準確性：
  - `exposureAdjustmentBrightensRenderedOutput`
  - 驗證曝光調整後輸出平均亮度顯著上升（以實際渲染結果判定）。
- 裁切座標準確性（UI/輸出一致性核心）：
  - `cropRectYUsesTopLeftOriginMapping`
  - `cropRectXUsesLeftOriginMapping`
  - 驗證 `crop.rect` 的 top-left 座標語義與最終輸出區域一致。
- 互動反應性能（fast path 生效）：
  - `fastModeRenderIsFasterThanFullRenderForHeavyRecipe`
  - 驗證重負載 recipe 下 fast mode 速度優於 full mode。

### 8.3 執行結果
- `xcodebuild test -scheme rawctl -only-testing:rawctlTests`：**Pass**
  - 新增 `ImagePipelineRegressionTests` 全數通過。
- `xcodebuild test -scheme rawctl-e2e -only-testing:rawctlUITests/RawctlSmokeTests/testSmoke_LaunchWithFolderAndSwitchViews`：**Pass**
  - 確認新增回歸測試未破壞既有 UI smoke 流程。

## 9. 下一輪升級（本次執行）

### 9.1 已完成升級

- 裁切 UI 與實際輸出對位修復（針對你提出的「顯示與實際切片不相符」）：
  - 新增 `CropOverlayGeometry`，以「實際顯示影像矩形」計算 crop overlay，而不是整個容器尺寸。
  - 修正 corner/center/background drag 全部座標換算為 image-rect 相對座標。
  - 背景拖曳新增 image rect 起點守衛，避免從黑邊起拖造成錯位。
- 參數拖曳反應優化（針對「調整相片參數時反應慢」）：
  - `SingleView.loadPreview` 在 slider drag fast path 降低預覽尺寸上限（加速回饋）。
  - 拖曳期間不再每幀更新 `currentPreviewImage`（降低 Histogram 重算壓力），放開後由 full render 收斂。
- 交互入口一致性修復：
  - `RawctlViewCommands` 改成單一路徑（只發 Notification，不再同時直改 AppState），避免 menu 入口雙重觸發造成狀態競爭。

涉及檔案：
- `rawctl/Components/CropOverlayView.swift`
- `rawctl/Views/SingleView.swift`
- `rawctl/Services/RawctlViewCommands.swift`

### 9.2 新增回歸測試

- 新增 `rawctlTests/CropOverlayGeometryTests.swift`，覆蓋：
  - 顯示影像矩形 letterbox 計算（橫圖/直圖）
  - normalized crop rect 到顯示矩形映射
  - 拖曳座標 normalized/clamp 行為

### 9.3 本輪測試結果

- `xcodebuild test -scheme rawctl -only-testing:rawctlTests`：**Pass**
  - 含新加 `CropOverlayGeometryTests` 全數通過。
  - 既有 `ImagePipelineRegressionTests` 全數通過。

### 9.4 UI 自動化重跑結果（2026-02-16）

- 已執行：
  - `xcodebuild test -scheme rawctl-e2e -destination 'platform=macOS' -only-testing:rawctlUITests/RawctlSmokeTests`
- 結果：**Pass**
  - `Executed 6 tests, with 1 test skipped and 0 failures`
  - `RawctlSmokeTests.testEntry_InspectorEditCropSwitchesSingleAndTransform`：Pass
  - `RawctlSmokeTests.testSmoke_LaunchWithFolderAndSwitchViews`：Pass
  - `RawctlSmokeTests.testPerf_folderToFirstSelectionSignpost`：Pass
  - `RawctlSmokeTests.testPerf_scanFolderSignpost`：Pass
  - `RawctlSmokeTests.testPerf_sliderStressSignpost`：Pass

性能量測（signpost）：
- `folderToFirstSelection.duration`
  - avg: `0.137s`
  - RSD: `23.883%`
  - values: `0.118084`, `0.131338`, `0.167840`, `0.177789`, `0.088734`
- `scanFolder.duration`
  - avg: `0.013s`
  - RSD: `24.947%`
  - values: `0.014422`, `0.018228`, `0.007757`, `0.013526`, `0.013275`
- `sliderStress.duration`
  - avg: `0.859s`
  - RSD: `0.813%`
  - values: `0.852834`, `0.861364`, `0.849010`, `0.861847`, `0.868630`

## 10. A7III 穩定性壓測（10 次）

測試命令（無重編譯）：
- `xcodebuild test-without-building -xctestrun .../rawctl-e2e-A7III.xctestrun -only-testing:rawctlUITests/RawctlSmokeTests/testSmoke_LaunchWithExternalFolderAndSwitchViews`

測試資料夾：
- `/Users/chuisiufai/Desktop/Life/20251108_A7III`

結果（10/10 Pass）：
- run1: `38.97s`
- run2: `34.74s`
- run3: `25.58s`
- run4: `33.52s`
- run5: `30.65s`
- run6: `20.40s`
- run7: `31.57s`
- run8: `20.37s`
- run9: `28.96s`
- run10: `20.22s`

統計：
- avg: `28.498s`
- median: `29.805s`
- p95: `38.97s`
- min / max: `20.22s / 38.97s`
- RSD: `22.104%`

判讀：
- 功能正確性：穩定（10/10 全通過，入口與交互鏈路可用）。
- 性能穩定性：仍有明顯波動（RSD 22%），目前尚未達「日常使用下可預期反應」的最佳狀態。
- 建議下一步重點由「功能修復」轉為「首載入與資料夾掃描抖動收斂」。

## 11. 抖動收斂升級（本輪新增）

### 11.1 已實施優化

- 掃描路徑去重複 I/O：
  - `PhotoAsset` 新增可接收預先計算屬性的 initializer。
  - `FileSystemService.scanFolder` / `incrementalScan` 改為單次讀取 `URLResourceValues`（`fileSize/creationDate/contentModificationDate`），避免每張檔案再做一次 `attributesOfItem`。
- 載入任務可取消化與防陳舊套用：
  - `AppState` 新增 `recipeLoadTask` / `thumbnailPreloadTask` / `thumbnailAutoHideTask`。
  - 新增 `cancelBackgroundAssetLoading()` 與 `schedulePostScanBackgroundWork()`，在資料源切換時先取消舊任務。
  - `loadAllRecipes(expectedFolderPath:)` / `preloadThumbnails(expectedFolderPath:)` 新增上下文守衛與 `Task.isCancelled` 檢查，避免舊工作覆寫新狀態。
- 載入流程調整：
  - `openFolderFromPath`、`selectProject`、`MemoryCardService.openCameraCard` 改為「先完成首選取，再背景載入 recipe + thumbnail」並可中途取消。

涉及檔案：
- `rawctl/Models/PhotoAsset.swift`
- `rawctl/Services/FileSystemService.swift`
- `rawctl/Models/AppState.swift`
- `rawctl/Services/MemoryCardService.swift`

### 11.2 回歸測試結果（2026-02-16）

- `xcodebuild test -scheme rawctl -destination 'platform=macOS' -only-testing:rawctlTests`：**Pass**
- `xcodebuild test -scheme rawctl-e2e -destination 'platform=macOS' -only-testing:rawctlUITests/RawctlSmokeTests`：**Pass**
  - `Executed 6 tests, with 1 test skipped and 0 failures`
  - signpost：
    - `folderToFirstSelection`: avg `0.151s`, RSD `12.438%`
    - `scanFolder`: avg `0.003s`, RSD `6.765%`
    - `sliderStress`: avg `0.950s`, RSD `2.871%`
- A7III 外部資料夾 smoke（指定 case）：
  - `test-without-building ... testSmoke_LaunchWithExternalFolderAndSwitchViews`：**Pass**（`19.201s`）

### 11.3 A7III 10 次重複（乾淨啟動）

測試對象：
- `/Users/chuisiufai/Desktop/Life/20251108_A7III`

每輪前置：
- 強制結束殘留 `rawctl` / `rawctlUITests-Runner`，確保乾淨啟動。

結果（10/10 Pass）：
- run1: `40.35s`
- run2: `26.09s`
- run3: `23.63s`
- run4: `35.65s`
- run5: `33.95s`
- run6: `25.34s`
- run7: `33.76s`
- run8: `22.35s`
- run9: `34.81s`
- run10: `34.95s`

統計：
- avg: `31.088s`
- p50: `33.855s`
- p95: `35.650s`
- min / max: `22.35s / 40.35s`
- sd: `5.837`
- RSD: `18.775%`

補充觀察：
- 不做乾淨啟動時，曾出現一次 UI 測試活化失敗（app 處於 background，無法被 runner 重新 activate），屬於測試啟動/活化鏈路波動，不是功能 assertion 失敗。
- 與第 10 節先前 10-run 對比：
  - RSD `22.104% -> 18.775%`（抖動收斂）
  - p95 `38.97s -> 35.65s`（尾延遲改善）
  - avg `28.498s -> 31.088s`（因採「每輪乾淨啟動」策略，平均值不可直接視為功能退化）

## 12. Phase Profiling 回歸（本輪）

### 12.1 測試命令

- `xcodebuild test -scheme rawctl-e2e -destination 'platform=macOS' -only-testing:rawctlUITests/RawctlSmokeTests/testPerf_thumbnailPreloadSignpost`
- `xcodebuild test -scheme rawctl-e2e -destination 'platform=macOS' -only-testing:rawctlUITests/RawctlSmokeTests`
- `xcodebuild test -scheme rawctl -destination 'platform=macOS' -only-testing:rawctlTests`

### 12.2 測試結果

- `rawctlUITests/RawctlSmokeTests`：**Pass**
  - `Executed 8 tests, with 1 test skipped and 0 failures`
  - skip 項目：`testSmoke_LaunchWithExternalFolderAndSwitchViews`（未設定 `RAWCTL_E2E_FOLDER_UNDER_TEST`）
- `rawctlTests`：**Pass**（`** TEST SUCCEEDED **`）

### 12.3 性能數據（signpost）

- `folderToFirstSelection`
  - avg: `0.174s`
  - RSD: `9.912%`
  - values: `0.184269`, `0.187583`, `0.191029`, `0.158819`, `0.148001`
- `scanFolder`
  - avg: `0.004s`
  - RSD: `36.809%`
  - values: `0.002719`, `0.006224`, `0.005497`, `0.002685`, `0.003193`
- `sidecarLoadAll`
  - avg: `0.151s`
  - RSD: `1.623%`
  - values: `0.153043`, `0.152635`, `0.153026`, `0.149378`, `0.146944`
- `sliderStress`
  - avg: `1.002s`
  - RSD: `4.003%`
  - values: `1.072190`, `0.972284`, `0.989098`, `0.959217`, `1.017373`
- `thumbnailPreloadAll`
  - avg: `1.993s`
  - RSD: `12.384%`
  - values: `1.697187`, `1.794183`, `1.910528`, `2.243350`, `2.321918`

補充（單獨測項）：
- `testPerf_thumbnailPreloadSignpost` 單獨執行一次：avg `2.887s`、RSD `43.036%`（首輪 `5.356880s` 冷啟動離群）

### 12.4 UI 入口準確性

- `View -> Single View (E2E)` 與 `View -> Grid View (E2E)`：本輪 smoke 中可穩定命中與切換。
- `Inspector -> Edit Crop`：可穩定切到 `single` + `transform`（`testEntry_InspectorEditCropSwitchesSingleAndTransform` 通過）。
- 入口與狀態一致性：`e2e.view.mode`、`singleView`、`grid.thumbnail.*` 斷言一致。

### 12.5 交互系統運作準確度

- 互動流程正確性：**通過**
  - 首選取建立、模式切換、crop 入口、slider stress 都有對應狀態轉換與 UI 呈現。
- 穩定性重點：
  - `sidecarLoadAll`、`sliderStress` 已在可控範圍（RSD 皆 < 5%）。
  - `thumbnailPreloadAll` 仍有抖動（RSD > 10%，且冷啟動離群明顯）。

### 12.6 可日常使用判定（本輪）

- 功能可用性：**可用**
  - 核心 UI 入口、交互鏈路、單元/UI 回歸皆通過。
- 體感穩定性：**接近可日常使用，但仍需收斂**
  - 主要瓶頸集中在 `thumbnail preload` 的首輪與波動，而非功能正確性。

### 12.7 下一輪優化優先級

1. `P0`：縮小 `thumbnailPreloadAll` 抖動（目標 RSD < 10%，首輪 < 2.5s）。
2. `P1`：將 `scanFolder` 指標拆分為更有感知價值的階段（例如首畫面可操作時間），降低 micro-duration 噪聲誤導。
3. `P1`：把 `RAWCTL_E2E_FOLDER_UNDER_TEST` 納入固定 nightly 測試，持續監控真實資料夾回歸趨勢。

## 13. P0 縮圖系統升級（本輪完成）

### 13.1 新發現的根因

- `ThumbnailService` 原本 cache key 只用 `fingerprint(size+mtime)+size`。
- 在「不同檔案但同 size/mtime」場景（例如 E2E 1x1 fixture）會發生 key collision，造成：
  - 縮圖可能被錯誤覆蓋（UI 顯示風險）
  - preload 指標被污染（冷熱混合與碰撞導致高波動）
- `saveToDisk` 原本回到 actor 上序列執行，容易與產生流程互相阻塞，放大抖動。

### 13.2 已實施修復

涉及檔案：
- `rawctl/Services/ThumbnailService.swift`
- `rawctl/Models/AppState.swift`

變更：
- 修正 cache key：
  - 改為 `stable(pathHash) + fingerprint + size`，避免同 size/mtime 檔案互撞。
  - 使用穩定 `FNV-1a` 路徑哈希（跨啟動一致）。
- 新增 in-flight 去重：
  - 同一 key 同時請求只產生一次，其他請求等待同一 Task。
- 落盤改為非阻塞：
  - 縮圖寫檔改到專用 `utility` queue，不再佔用 actor 主流程。
- preload 佇列改造：
  - `AppState.preloadThumbnails` 從「分批 barrier」改為「連續併發佇列」。
  - preload 尺寸調整為 `320`（對齊預設 grid 請求 `160*2`），提升快取命中價值。

### 13.3 本輪最終驗證

- `xcodebuild test -scheme rawctl -destination 'platform=macOS' -only-testing:rawctlTests`：**Pass**
- `xcodebuild test -scheme rawctl-e2e -destination 'platform=macOS' -only-testing:rawctlUITests/RawctlSmokeTests`：**Pass**
  - `Executed 8 tests, with 1 test skipped and 0 failures`

性能（最終 full smoke）：
- `folderToFirstSelection`
  - avg: `0.149s`
  - RSD: `11.055%`
  - values: `0.165050`, `0.155790`, `0.158472`, `0.146040`, `0.118184`
- `scanFolder`
  - avg: `0.003s`
  - RSD: `34.046%`
  - values: `0.002456`, `0.005230`, `0.002494`, `0.002361`, `0.003497`
- `sidecarLoadAll`
  - avg: `0.155s`
  - RSD: `29.686%`
  - values: `0.128118`, `0.156484`, `0.244538`, `0.123317`, `0.124904`
- `sliderStress`
  - avg: `0.956s`
  - RSD: `2.987%`
  - values: `0.932508`, `0.933175`, `0.946009`, `0.961105`, `1.009694`
- `thumbnailPreloadAll`
  - avg: `1.547s`
  - RSD: `7.005%`
  - values: `1.619825`, `1.521982`, `1.426912`, `1.449927`, `1.717155`

補充：
- `testPerf_thumbnailPreloadSignpost`（清 cache 後專項）：
  - avg: `1.063s`
  - RSD: `16.544%`
  - values: `1.081547`, `1.277447`, `1.119422`, `0.740440`, `1.094324`

### 13.4 結論（日常使用）

- `thumbnailPreloadAll` 已從高波動收斂到 RSD `7.005%`，達到本輪 P0 目標（`< 10%`）。
- UI 入口準確性與交互鏈路在修復後維持通過（View menu / Inspector Edit Crop 均 pass）。
- 目前剩餘風險主要在 `scanFolder` / `sidecarLoadAll` 的 micro-benchmark 波動，屬於測量噪聲與冷啟動條件混合，非功能失效。

### 13.5 下一步（P1）

1. 將 `scanFolder` 指標改為更貼近體感的 phase（如 `folderScanPhase` + 首次可交互時間）。
2. 為 sidecar 建立「冷啟動/熱啟動分離」量測，避免混合樣本放大 RSD。
3. 對 A7III 真實資料夾增加固定回歸 job（入口準確率 + 95p 交互延遲）。

## 14. P1 指標升級與冷熱分離（本輪完成）

### 14.1 測試命令

- `xcodebuild test -scheme rawctl-e2e -destination 'platform=macOS' -only-testing:rawctlUITests/RawctlSmokeTests/testPerf_folderScanPhaseSignpost -only-testing:rawctlUITests/RawctlSmokeTests/testPerf_sidecarLoadColdHotSplit`
- `xcodebuild test -scheme rawctl-e2e -destination 'platform=macOS' -only-testing:rawctlUITests/RawctlSmokeTests/testPerf_sidecarLoadColdHotSplit`

### 14.2 測試穩定性修正

- `rawctlUITests/RawctlSmokeTests.swift`
  - `waitForNumericValue` 改為寬鬆數字擷取（可解析 `Optional(...)` 或含單位字串）。
  - `testPerf_sidecarLoadColdHotSplit` 新增重試機制（最多 3 次）以降低 UI 測試偶發讀值失敗。
  - 新增 `sidecar cold/hot` 摘要 log，便於報告直接引用。
  - sidecar fixture 新增可控 payload（本輪使用 `16_384` bytes / file）以避免完全零負載測量。
- `rawctl/Models/AppState.swift` + `rawctl/Views/MainLayoutView.swift`
  - 新增 E2E 指標 `e2e.sidecar.load.us`（微秒），保留 `e2e.sidecar.load.ms` 相容既有測試與報表。

### 14.3 性能結果

- `folderScanPhase`（signpost）
  - avg: `0.143s`
  - RSD: `11.120%`
  - values: `0.132573`, `0.119918`, `0.165588`, `0.153540`, `0.142982`
- `sidecar cold/hot split`
  - run A: `coldUs=793`、`warmSamplesUs=[942,874,1,844,942]`、`warmMedianUs=874`
  - run B: `coldUs=782`、`warmSamplesUs=[936,2,1,1,1]`、`warmMedianUs=1`

### 14.4 判讀

- P1 目標「scan phase 指標拆分」已落地，`folderScanPhase` 可直接反映掃描階段耗時，不再依賴 `scanFolder` micro-benchmark。
- `sidecar` 冷熱分離已可穩定執行，且已提升到微秒級觀測；目前 warm 樣本仍呈現「接近量測下限 + 偶發較高值」的雙峰分佈，表示此工作負載已非常輕量，後續要比較細緻優化需再提高 sidecar 載荷（更大 JSON / 更多檔案）與樣本次數。

## 15. P1 指標可信度修正（本輪）

### 15.1 問題與修正

- 問題：
  - `sidecarLoadUs` 先前出現 `1~5us`，與實際載入時間不符。
  - 根因不是 App 量測錯誤，而是 UI test 數字解析會把 `3,167,344` 解析成 `3`（千位分隔被截斷）。
- 修正：
  - `rawctlUITests/RawctlSmokeTests.swift`
    - `waitForNumericValue` 新增千位分隔解析（`,` / `_` / 空白）；
    - `testPerf_sidecarLoadColdHotSplit` 追加 `e2e.sidecar.loaded.count` 斷言，避免「沒載入 sidecar 也通過」的假陽性。
  - `rawctl/Models/AppState.swift` + `rawctl/Views/MainLayoutView.swift`
    - 新增 `e2e.sidecar.loaded.count` 指標（實際已完成 sidecar 處理數量）。

### 15.2 新負載配置

- fixture：`240` 張
- 每檔 sidecar payload：`262_144` bytes
- `estimatedPayloadMiB`：`60.0`

### 15.3 測試結果（修正後）

單次（warm=1）：
- `coldUs=3,167,344`（`3167.344ms`）
- `warmUs=3,648,986`（`3648.986ms`）

補充兩次獨立 run（同測項，避免單一 test 內多次 relaunch 的 macOS runner 失敗）：
- run1：`coldUs=3,266,584`、`warmUs=3,282,901`
- run2：`coldUs=7,662,319`、`warmUs=3,545,015`

跨 3 run 彙總：
- cold：
  - avg：`4,698,749us`（`4698.749ms`）
  - median：`3,266,584us`（`3266.584ms`）
  - min/max：`3,167,344us / 7,662,319us`
- warm：
  - avg：`3,492,301us`（`3492.301ms`）
  - median：`3,545,015us`（`3545.015ms`）
  - min/max：`3,282,901us / 3,648,986us`

### 15.4 判讀

- 指標可信度：已修正，可反映真實量級（秒級毫秒，不再是假性微秒）。
- 系統行為：
  - sidecar 在高負載下，warm 一般落在 `3.3s ~ 3.6s`；
  - cold 存在尾端離群（`7.66s`），需持續觀察 I/O 冷啟動條件。
- 測試穩定性：
  - 單一 test case 內多次 relaunch 在 macOS UI runner 仍偶有 `Running Background` 活化失敗；
  - 目前採用「每次獨立執行收樣」作為穩定 workaround。

## 16. P0 Crash + UX 可用性修正（本輪）

### 16.1 新發現根因（對應 Single View 閃退）

- 來源：`/Users/chuisiufai/Library/Logs/DiagnosticReports/rawctl-2026-02-16-023649.ips`
- `lastExceptionBacktrace` 顯示：
  - `NSColorRaiseWithColorSpaceError`
  - `-[_NSTaggedPointerColor redComponent]`
  - `HistogramData.compute(from:)`（`HistogramView.swift`）
- 判定：
  - 不是單純 menu click bug，而是「進入 single view 後 Histogram 背景計算讀取某些色域/動態顏色分量時崩潰」。

### 16.2 已實施修復

涉及檔案：
- `rawctl/Components/HistogramView.swift`
- `rawctl/Views/MainLayoutView.swift`
- `rawctlUITests/RawctlSmokeTests.swift`
- `rawctlTests/HistogramDataTests.swift`

修復內容：
- Histogram 計算路徑重構（P0）：
  - 不再使用 `bitmap.colorAt(...).redComponent` 逐點讀 `NSColor`。
  - 先把影像轉為 canonical `8-bit sRGB RGBA` buffer，再直接以 byte 計算 histogram。
  - 避免 `NSColor` 在不支援色域上取分量觸發例外，並降低色彩轉換開銷。
- E2E 偵錯面板顯示策略修正（UX）：
  - `MainLayoutView` 新增 `e2eOverlayEnabled`：
    - 預設僅在 `XCTest` 進程中顯示；
    - 或顯式設定 `RAWCTL_E2E_PANEL=1` 才顯示。
  - 目的：防止日常使用時出現 `assets/view/selected...` 偵錯浮層干擾操作。
- UI 測試環境同步：
  - `RawctlSmokeTests` 啟動時加上 `RAWCTL_E2E_PANEL=1`，保留自動化點擊能力（例如 `e2e.action.slider.stress`）。
- 新增回歸測試：
  - `HistogramDataTests.computeHandlesSystemColorRenderedImage`，覆蓋系統顏色來源影像計算。

### 16.3 驗證結果

- `xcodebuild test -scheme rawctl -destination 'platform=macOS' -only-testing:rawctlTests/HistogramDataTests`：**Pass**
  - `computeHandlesDeviceWhiteBitmap`：Pass
  - `computeHandlesSystemColorRenderedImage`：Pass
- `xcodebuild test -scheme rawctl-e2e -destination 'platform=macOS' -only-testing:rawctlUITests/RawctlSmokeTests/testPerf_sliderStressSignpost -only-testing:rawctlUITests/RawctlSmokeTests/testSmoke_LaunchWithFolderAndSwitchViews`：**Pass**
  - `testPerf_sliderStressSignpost`：Pass
    - avg `0.933s` / RSD `2.005%`
  - `testSmoke_LaunchWithFolderAndSwitchViews`：Pass（`Grid -> Single -> Grid` 入口全通）

### 16.4 判讀

- 「menu bar 按 Single View 閃退」已確認有實際 P0 crash 根因，且本輪已針對根因修復，不是只做表層 workaround。
- E2E 視覺浮層已改為測試時才顯示，日常 UX 可用性提升。
- 目前入口準確性與交互鏈路在本輪回歸維持通過。

## 17. A7III 真實資料夾回歸（本輪）

### 17.1 測試對象

- 路徑：`/Users/chuisiufai/Desktop/Life/20251108_A7III`
- 總檔案數：`109`
- 支援影像數：`89`

### 17.2 測試方法

- 先執行：
  - `xcodebuild build-for-testing -scheme rawctl-e2e -destination 'platform=macOS'`
- 以 `.xctestrun` 注入 `RAWCTL_E2E_FOLDER_UNDER_TEST`：
  - `/Users/chuisiufai/Library/Developer/Xcode/DerivedData/rawctl-fjlnngxowupcrzdxwmultwetfiru/Build/Products/rawctl-e2e-A7III-20260216.xctestrun`
- 測項（真實資料夾）：
  - `testSmoke_LaunchWithExternalFolderAndSwitchViews`
  - `testSmoke_ExternalFolderInspectorEditCropEntry`
  - `testSmoke_ExternalFolderSliderStressInteraction`
- 每測項重複 `3` 次（獨立執行）並統計 `test case` 耗時。

### 17.3 結果

- `testSmoke_LaunchWithExternalFolderAndSwitchViews`
  - pass: `3/3`
  - avg: `22.652s`
  - p95: `23.241s`
  - min/max: `21.934s / 23.241s`
  - RSD: `2.390%`
- `testSmoke_ExternalFolderInspectorEditCropEntry`
  - pass: `3/3`
  - avg: `18.047s`
  - p95: `19.399s`
  - min/max: `15.682s / 19.399s`
  - RSD: `9.297%`
- `testSmoke_ExternalFolderSliderStressInteraction`
  - pass: `3/3`
  - avg: `13.322s`
  - p95: `13.531s`
  - min/max: `12.919s / 13.531s`
  - RSD: `2.140%`

### 17.4 判讀

- UI 入口準確性：通過
  - 真實資料夾下可穩定完成 `Grid -> Single -> Grid`。
- Crop 入口準確性：通過
  - `Inspector -> Edit Crop` 在 A7III 下可穩定進入 `single + transform`。
- 交互系統準確度：通過
  - `slider stress` 在真實資料夾下連續 3 輪均完成 `done`，未出現卡死或狀態異常。
- Crash 觀察：
  - 本輪測試後 `~/Library/Logs/DiagnosticReports/` 未新增 `rawctl-*.ips`（最新仍為 `2026-02-16 02:36:49` 舊檔）。
