# AI 圖像生成/修復功能設計文件

**日期**: 2026-01-06
**狀態**: 已驗證，待實作

---

## 1. 整體架構

```
┌─────────────────────────────────────────────────────────────┐
│                      rawctl App                              │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   Editor    │  │  Inspector  │  │    AI Layers        │ │
│  │   Canvas    │←→│   Panel     │←→│    Manager          │ │
│  │             │  │             │  │                     │ │
│  │  ┌───────┐  │  │ ┌─────────┐ │  │ ┌─────────────────┐ │ │
│  │  │ Brush │  │  │ │ AI Gen  │ │  │ │ Layer Stack     │ │ │
│  │  │ Mask  │  │  │ │ Panel   │ │  │ │ - Original      │ │ │
│  │  └───────┘  │  │ └─────────┘ │  │ │ - AI Layer 1    │ │ │
│  │             │  │ ┌─────────┐ │  │ │ - AI Layer 2    │ │ │
│  │  ┌───────┐  │  │ │ Prompt  │ │  │ │ - ...           │ │ │
│  │  │ Layer │  │  │ │ Input   │ │  │ └─────────────────┘ │ │
│  │  │Preview│  │  │ └─────────┘ │  │                     │ │
│  └──┴───────┴──┘  └─────────────┘  └─────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│                    Services Layer                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │ AIGeneration│  │  Account    │  │   History           │ │
│  │   Service   │  │  Service    │  │   Manager           │ │
│  └──────┬──────┘  └──────┬──────┘  └─────────────────────┘ │
└─────────┼────────────────┼──────────────────────────────────┘
          │                │
          ▼                ▼
┌─────────────────────────────────────────────────────────────┐
│                     rawctl-api                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │ /ai/generate│  │ /ai/enhance │  │   /user/credits     │ │
│  │             │  │   -prompt   │  │                     │ │
│  └──────┬──────┘  └──────┬──────┘  └─────────────────────┘ │
└─────────┼────────────────┼──────────────────────────────────┘
          │                │
          ▼                ▼
┌─────────────────────────────────────────────────────────────┐
│                    Gemini API                                │
│  ┌────────────────────┐  ┌────────────────────────────────┐ │
│  │ gemini-2.5-flash   │  │ gemini-2.5-flash-image        │ │
│  │ (Prompt 潤飾)      │  │ gemini-3-pro-image-preview    │ │
│  │ thinkingBudget: 0  │  │ (圖像生成)                    │ │
│  └────────────────────┘  └────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. 資料模型

### AILayer 結構

```swift
struct AILayer: Identifiable, Codable {
    let id: UUID
    let type: AILayerType
    let prompt: String
    let originalPrompt: String  // 潤飾前的原始 prompt
    let maskData: Data?         // 筆刷遮罩（僅區域生成）
    let generatedImage: Data
    let preserveStrength: Double // 0-100%
    let resolution: AIResolution
    let creditsUsed: Int
    let createdAt: Date
    let parentLayerId: UUID?    // 用於版本追蹤

    var isVisible: Bool = true
    var opacity: Double = 1.0
    var blendMode: BlendMode = .normal
}
```

### AILayerType 枚舉

```swift
enum AILayerType: String, Codable {
    case inpaint      // 區域修復/生成
    case outpaint     // 擴展邊界
    case transform    // 場景轉換
    case style        // 風格轉換
    case enhance      // 品質增強
}
```

### AIEditHistory 結構

```swift
struct AIEditHistory: Identifiable, Codable {
    let id: UUID
    let documentId: UUID
    let layers: [AILayer]       // 線性歷史記錄
    let currentIndex: Int       // 當前檢視位置
    let createdAt: Date
    let lastModified: Date
}
```

### AIResolution 枚舉

```swift
enum AIResolution: String, Codable, CaseIterable {
    case standard = "1K"   // 1024px - 1 credit
    case high = "2K"       // 2048px - 3 credits
    case ultra = "4K"      // 4096px - 6 credits

    var credits: Int {
        switch self {
        case .standard: return 1
        case .high: return 3
        case .ultra: return 6
        }
    }

    var displayName: String {
        switch self {
        case .standard: return "1K (1 credit)"
        case .high: return "2K (3 credits)"
        case .ultra: return "4K (6 credits)"
        }
    }
}
```

---

## 3. AI 生成面板 UI

### 位置

Inspector 側邊欄（右側面板）

### 面板結構

```
┌─────────────────────────────────┐
│  AI Generation                 ▼│  ← 可折疊標題
├─────────────────────────────────┤
│                                 │
│  Mode: ○ Region  ● Full Image   │  ← 切換模式
│                                 │
├─────────────────────────────────┤
│  Type:                          │
│  ┌─────┐ ┌─────┐ ┌─────┐       │
│  │Scene│ │Style│ │Fix  │       │  ← 類型選擇
│  └─────┘ └─────┘ └─────┘       │
│                                 │
├─────────────────────────────────┤
│  Prompt:                        │
│  ┌─────────────────────────────┐│
│  │ 將場景改為夕陽海灘...       ││  ← 多行輸入
│  │                             ││
│  └─────────────────────────────┘│
│  [✨ 一鍵潤飾]                  │  ← 潤飾按鈕（免費）
│                                 │
├─────────────────────────────────┤
│  Preserve Original: ━━━━○━━ 70% │  ← 滑桿
│                                 │
├─────────────────────────────────┤
│  Resolution:                    │
│  ○ 1K (1 credit)               │
│  ● 2K (3 credits)              │  ← 解析度選擇
│  ○ 4K (6 credits)              │
│                                 │
├─────────────────────────────────┤
│  ┌─────────────────────────────┐│
│  │     🎨 Generate (3 ⭐)      ││  ← 生成按鈕
│  └─────────────────────────────┘│
│                                 │
│  Credits: 47 remaining          │  ← 餘額顯示
│                                 │
└─────────────────────────────────┘
```

### 區域模式額外 UI

當選擇 Region 模式時，Canvas 上啟用筆刷遮罩工具：

```
┌─────────────────────────────────┐
│  Brush Settings                 │
├─────────────────────────────────┤
│  Size: ━━━━━○━━━ 50px          │
│  Hardness: ━━○━━━━━ 30%        │
│  [Clear Mask] [Invert]          │
└─────────────────────────────────┘
```

---

## 4. AI 圖層管理面板

### 位置

Inspector 側邊欄下方，AI Generation 面板的可折疊區域

### 面板結構

```
┌─────────────────────────────────┐
│  AI Layers                     ▼│  ← 可折疊標題
├─────────────────────────────────┤
│                                 │
│  ┌─────────────────────────────┐│
│  │ 👁 Layer 3 - Style         ││  ← 最新在上
│  │    "水彩畫風格"              ││
│  │    2K • 3 credits • 2min ago││
│  │    [⬇] [🗑]                 ││
│  └─────────────────────────────┘│
│                                 │
│  ┌─────────────────────────────┐│
│  │ 👁 Layer 2 - Scene         ││
│  │    "夕陽海灘場景"            ││
│  │    1K • 1 credit • 5min ago ││
│  │    [⬇] [🗑]                 ││
│  └─────────────────────────────┘│
│                                 │
│  ┌─────────────────────────────┐│
│  │ 👁 Layer 1 - Inpaint       ││
│  │    "移除背景人物"            ││
│  │    1K • 1 credit • 10min ago││
│  │    [⬇] [🗑]                 ││
│  └─────────────────────────────┘│
│                                 │
│  ┌─────────────────────────────┐│
│  │ 🔒 Original Image           ││  ← 原始圖層（不可刪除）
│  └─────────────────────────────┘│
│                                 │
├─────────────────────────────────┤
│  [Flatten All] [Export Current] │  ← 操作按鈕
└─────────────────────────────────┘
```

### 圖層操作功能

| 操作 | 說明 |
|------|------|
| 👁 | 切換圖層可見性 |
| ⬇ | 下載該圖層的獨立圖像 |
| 🗑 | 刪除圖層（需確認） |
| Flatten All | 合併所有圖層為單一圖像 |
| Export Current | 匯出當前可見狀態 |

### 圖層選擇行為

- 點擊圖層：選中該圖層，顯示其遮罩範圍（如適用）
- 雙擊圖層：進入重新編輯模式（載入原始 prompt）
- 拖曳圖層：重新排序圖層順序

---

## 5. Prompt 潤飾系統

### 設計目標

- 將用戶簡短輸入轉換為詳細、專業的 AI prompt
- 保持原始意圖，增加技術細節
- 完全免費（不消耗 credits）

### UI 流程

```
用戶輸入: "把背景改成海邊"
           ↓
      [✨ 一鍵潤飾]
           ↓
┌─────────────────────────────────┐
│  💫 潤飾中...                   │
│  ━━━━━━━━━━━○━━━━━━━━━━        │
└─────────────────────────────────┘
           ↓
潤飾結果: "Transform the background into a serene
         beach scene with golden sand, gentle
         turquoise waves, and a clear blue sky
         with soft white clouds. Maintain natural
         lighting consistent with the subject..."
           ↓
┌─────────────────────────────────┐
│  [✓ 使用潤飾版本]  [✗ 保留原始] │
└─────────────────────────────────┘
```

### 潤飾 API 規格

**模型**: `gemini-2.5-flash`
**費用**: 免費（不扣 credits）
**參數**: `thinkingBudget: 0`（快速回應）

**System Prompt**:
```
You are a professional AI image generation prompt optimizer.

Your task is to enhance user prompts for better AI image generation results.

Guidelines:
1. Preserve the user's original intent completely
2. Add technical details (lighting, composition, style)
3. Include quality modifiers (high quality, detailed, professional)
4. Keep the enhanced prompt concise but comprehensive
5. Match the language of the user's input

Output only the enhanced prompt, nothing else.
```

---

## 6. API 整合架構

### 模型選擇策略

| 功能 | 模型 | Credits | 說明 |
|------|------|---------|------|
| Prompt 潤飾 | `gemini-2.5-flash` | 免費 | 文字模型，thinkingBudget: 0 |
| 1K 圖像生成 | `gemini-2.5-flash-image` | 1 | 快速生成 |
| 2K 圖像生成 | `gemini-3-pro-image-preview` | 3 | 高品質 |
| 4K 圖像生成 | `gemini-3-pro-image-preview` | 6 | 專業級 |

### API 端點設計

#### POST /ai/enhance-prompt

```typescript
// Request
{
  "prompt": string,
  "language": "zh-TW" | "en" | "system"
}

// Response
{
  "success": true,
  "data": {
    "enhancedPrompt": string,
    "originalPrompt": string
  }
}
```

#### POST /ai/generate

```typescript
// Request
{
  "image": string,           // base64
  "mask": string | null,     // base64 (區域生成時)
  "prompt": string,
  "type": "inpaint" | "outpaint" | "transform" | "style" | "enhance",
  "preserveStrength": number, // 0-100
  "resolution": "1K" | "2K" | "4K"
}

// Response
{
  "success": true,
  "data": {
    "generatedImage": string,  // base64
    "creditsUsed": number,
    "creditsRemaining": number,
    "thoughtSignature": string // 用於多輪編輯
  }
}
```

### Credits 扣款流程

```
1. 用戶點擊 Generate
2. 前端檢查餘額 >= 所需 credits
3. 發送請求到 /ai/generate
4. 後端再次驗證餘額
5. 調用 Gemini API
6. 成功後扣除 credits
7. 返回生成結果 + 新餘額
8. 前端更新 UI
```

### 錯誤處理

| 錯誤碼 | 說明 | 前端處理 |
|--------|------|----------|
| INSUFFICIENT_CREDITS | 餘額不足 | 顯示購買 credits 提示 |
| GENERATION_FAILED | AI 生成失敗 | 顯示重試按鈕，不扣 credits |
| INVALID_IMAGE | 圖像格式錯誤 | 提示支援的格式 |
| RATE_LIMITED | 請求過於頻繁 | 顯示倒數計時 |

---

## 7. 實作優先順序

### Phase 1: 基礎架構
1. AILayer 資料模型
2. AIGenerationService 骨架
3. API 端點實作（/ai/enhance-prompt, /ai/generate）

### Phase 2: 核心功能
4. AI Generation Panel UI
5. Prompt 潤飾功能
6. 全圖生成功能（transform, style）

### Phase 3: 進階功能
7. 筆刷遮罩工具
8. 區域生成功能（inpaint）
9. AI Layers Manager UI

### Phase 4: 完善
10. 圖層操作（顯示/隱藏、刪除、匯出）
11. 歷史記錄與版本控制
12. 錯誤處理與 UX 優化

---

## 8. 技術規格

### 支援格式
- 輸入：JPEG, PNG, HEIC, RAW (經轉換)
- 輸出：PNG (with alpha), JPEG

### 圖像大小限制
- 最大輸入：20MB
- 最大輸出解析度：4096x4096

### 效能目標
- Prompt 潤飾：< 2 秒
- 1K 圖像生成：< 10 秒
- 2K/4K 圖像生成：< 30 秒

### 本地化
- 跟隨系統語言設定
- 支援：繁體中文、英文
