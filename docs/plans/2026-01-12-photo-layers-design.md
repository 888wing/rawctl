# Photo Layers Feature Design

**Date**: 2026-01-12
**Version**: 1.0
**Status**: Approved

## Overview

為 content creator 設計的相片圖層功能，支援即時預覽合成、批次套用模板，快速製作 timeline photo。

### MVP 範圍

- 文字圖層 (TextLayer)
- 形狀/底色圖層 (ShapeLayer)
- 塗鴉圖層 (DrawingLayer)
- 圖層模板系統（含自訂變數）
- 工具列模式 UI

### 不在 MVP 範圍

- 圖片/Logo 圖層（未來版本）
- 進階筆刷（壓力感應、紋理）

---

## 1. Architecture

### 1.1 Data Flow

```
EditRecipe
    └── layers: LayerStack
            └── items: [Layer]
                    ├── .text(TextLayer)
                    ├── .shape(ShapeLayer)
                    └── .drawing(DrawingLayer)
```

### 1.2 Core Structures

```swift
// MARK: - Layer Stack

struct LayerStack: Codable, Equatable {
    var items: [Layer] = []
    var isVisible: Bool = true

    var hasLayers: Bool { !items.isEmpty }
}

enum Layer: Codable, Equatable, Identifiable {
    case text(TextLayer)
    case shape(ShapeLayer)
    case drawing(DrawingLayer)

    var id: UUID {
        switch self {
        case .text(let l): return l.id
        case .shape(let l): return l.id
        case .drawing(let l): return l.id
        }
    }

    var transform: LayerTransform {
        get {
            switch self {
            case .text(let l): return l.transform
            case .shape(let l): return l.transform
            case .drawing(let l): return l.transform
            }
        }
        set {
            switch self {
            case .text(var l): l.transform = newValue; self = .text(l)
            case .shape(var l): l.transform = newValue; self = .shape(l)
            case .drawing(var l): l.transform = newValue; self = .drawing(l)
            }
        }
    }
}
```

### 1.3 Non-Destructive Philosophy

- 圖層資料儲存於 `.rawctlrecipe` sidecar 檔案
- 原始 RAW 檔案不被修改
- 渲染時即時合成，匯出時才寫入最終圖片

---

## 2. Layer Types

### 2.1 TextLayer

```swift
struct TextLayer: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String = "Text"

    // Content (supports variables like {filename}, {date})
    var content: String

    // Typography
    var font: String = "Helvetica Neue"
    var fontSize: Double = 48
    var color: CodableColor = .white
    var isBold: Bool = false
    var isItalic: Bool = false
    var alignment: TextAlignment = .center
    var lineSpacing: Double = 1.2

    // Background
    var hasBackground: Bool = false
    var backgroundColor: CodableColor = CodableColor(r: 0, g: 0, b: 0, a: 0.5)
    var backgroundPadding: Double = 8
    var backgroundCornerRadius: Double = 4

    // Transform
    var transform: LayerTransform

    enum TextAlignment: String, Codable, CaseIterable {
        case left, center, right
    }
}
```

### 2.2 ShapeLayer

```swift
struct ShapeLayer: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String = "Shape"

    var shapeType: ShapeType = .rectangle
    var fillColor: CodableColor = CodableColor(r: 0, g: 0, b: 0, a: 0.5)
    var strokeColor: CodableColor? = nil
    var strokeWidth: Double = 0
    var cornerRadius: Double = 0

    var transform: LayerTransform

    enum ShapeType: String, Codable, CaseIterable {
        case rectangle
        case ellipse
        case roundedRect
    }
}
```

### 2.3 DrawingLayer

```swift
struct DrawingLayer: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String = "Drawing"

    var strokes: [Stroke] = []
    var transform: LayerTransform
}

struct Stroke: Codable, Equatable {
    var points: [CGPoint]
    var color: CodableColor
    var width: Double
    var opacity: Double = 1.0
}
```

### 2.4 LayerTransform (Shared)

```swift
struct LayerTransform: Codable, Equatable {
    // Normalized coordinates (0-1 range)
    var position: CGPoint = CGPoint(x: 0.5, y: 0.5)  // Center anchor
    var size: CGSize = CGSize(width: 0.3, height: 0.1)
    var rotation: Double = 0  // Degrees
    var opacity: Double = 100  // 0-100

    var isVisible: Bool = true
    var isLocked: Bool = false
}
```

### 2.5 CodableColor

```swift
struct CodableColor: Codable, Equatable {
    var r: Double  // 0-1
    var g: Double
    var b: Double
    var a: Double = 1.0

    static let white = CodableColor(r: 1, g: 1, b: 1, a: 1)
    static let black = CodableColor(r: 0, g: 0, b: 0, a: 1)

    func opacity(_ value: Double) -> CodableColor {
        CodableColor(r: r, g: g, b: b, a: value)
    }

    var nsColor: NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
}
```

---

## 3. UI/UX Design

### 3.1 Toolbar Mode Activation

```
快捷鍵: L (Layers)
位置: InspectorView 工具列區域
狀態: editorMode = .layers
```

### 3.2 Layer List Panel (Left Side)

```
┌─────────────────────┐
│ 圖層 (Layers)    [+]│  ← Add layer menu
├─────────────────────┤
│ 👁 🔒 文字: 標題    │  ← Visibility / Lock / Name
│ 👁 🔒 形狀: 底色    │
│ 👁 🔒 塗鴉: 簽名    │
└─────────────────────┘
    ↑ Drag to reorder
```

**Interactions:**
- Click to select
- Double-click to rename
- Right-click for context menu (Copy / Delete / Duplicate)
- Drag to reorder (top = front)

### 3.3 Property Editor (Right Side)

| Layer Type | Controls |
|------------|----------|
| Text | Content input, Font picker, Size, Color, Alignment, Background toggle |
| Shape | Type picker, Fill color, Stroke color, Stroke width, Corner radius |
| Drawing | Brush size, Color, Opacity, Clear button |
| Common | Position X/Y, Size W/H, Rotation, Opacity |

### 3.4 Canvas Interaction

- **Select**: Click layer to select, shows 8-point bounding box
- **Move**: Drag layer center area
- **Resize**: Drag corner handles
- **Rotate**: Drag rotation handle (outside bounding box)
- **Drawing mode**: When drawing layer selected, draw directly on canvas

---

## 4. Template System

### 4.1 Template Structure

```swift
struct LayerTemplate: Codable, Identifiable {
    let id: UUID
    var name: String           // "Instagram Story"
    var category: String       // "Social Media"
    var layers: [Layer]        // Template layers
    var variables: [TemplateVariable]  // Custom variables
    var previewImage: Data?    // Thumbnail
    var createdAt: Date
}
```

### 4.2 Dynamic Variables

| Category | Variable | Description | Example |
|----------|----------|-------------|---------|
| **EXIF** | `{filename}` | Filename without extension | `DSC_0001` |
| | `{date}` | Capture date | `2026-01-12` |
| | `{time}` | Capture time | `14:30` |
| | `{camera}` | Camera model | `NIKON Z8` |
| | `{lens}` | Lens info | `24-70mm f/2.8` |
| | `{iso}` | ISO value | `ISO 400` |
| | `{aperture}` | Aperture | `f/2.8` |
| | `{shutter}` | Shutter speed | `1/250s` |
| **Batch** | `{index}` | Sequence number | `001` |
| | `{total}` | Total count | `50` |
| **Custom** | `{custom:名稱}` | User text input | User fills |
| | `{tag:客戶}` | Tag selection | From tag library |
| | `{tag:地點}` | Tag selection | From tag library |

### 4.3 Custom Variable System

```swift
struct TemplateVariable: Codable, Identifiable {
    let id: UUID
    var name: String        // "客戶名稱"
    var type: VariableType
    var defaultValue: String = ""

    enum VariableType: String, Codable {
        case text       // Free text input
        case tag        // Select from library
        case date       // Date picker
    }
}

struct TagLibrary: Codable {
    var tags: [String: [String]]
    // Example: ["客戶": ["A公司", "B工作室"], "地點": ["台北", "高雄"]]
}
```

### 4.4 Batch Apply Flow

```
1. Select multiple photos
2. Choose template
3. System detects custom variables in template
4. Show input dialog:
   ┌────────────────────────┐
   │ 批次套用: 個人水印      │
   ├────────────────────────┤
   │ 標題: [____________]   │  ← {custom:標題}
   │ 客戶: [A公司 ▼]        │  ← {tag:客戶}
   │ 地點: [台北 ▼]         │  ← {tag:地點}
   ├────────────────────────┤
   │ [取消]      [套用 50張] │
   └────────────────────────┘
5. Confirm → Apply to all selected photos (same input values)
```

### 4.5 Tag Library UI (Settings)

```
Settings → Tag Library
┌─────────────────────────┐
│ 客戶    [+]             │
│   • A公司               │
│   • B工作室             │
│   • C攝影社             │
├─────────────────────────┤
│ 地點    [+]             │
│   • 台北                │
│   • 高雄                │
│   • 台中                │
└─────────────────────────┘
```

---

## 5. Rendering Pipeline Integration

### 5.1 Current Pipeline

```
RAW Decode → Camera Profile → User Adjustments → Display
```

### 5.2 Extended Pipeline

```
RAW Decode → Camera Profile → User Adjustments → 【Layer Composite】→ Display
                                                       ↓
                                                 LayerRenderer
```

### 5.3 LayerRenderer Implementation

```swift
class LayerRenderer {
    /// Composite layers onto base image
    func composite(
        layers: LayerStack,
        onto baseImage: CGImage,
        metadata: ImageMetadata  // For variable substitution
    ) -> CGImage {
        guard layers.isVisible, layers.hasLayers else {
            return baseImage
        }

        // 1. Create CGContext at image size
        // 2. Draw baseImage
        // 3. For each visible layer (in order):
        //    - Apply transform
        //    - Render layer content
        // 4. Return composited result
    }

    private func render(_ layer: Layer, in context: CGContext, metadata: ImageMetadata) {
        guard layer.transform.isVisible else { return }

        switch layer {
        case .text(let textLayer):
            renderText(textLayer, in: context, metadata: metadata)
        case .shape(let shapeLayer):
            renderShape(shapeLayer, in: context)
        case .drawing(let drawingLayer):
            renderDrawing(drawingLayer, in: context)
        }
    }

    private func renderText(_ layer: TextLayer, in context: CGContext, metadata: ImageMetadata) {
        // 1. Substitute variables in content
        let resolvedContent = VariableResolver.resolve(layer.content, with: metadata)
        // 2. Create attributed string with font, color, alignment
        // 3. Draw background if enabled
        // 4. Draw text
    }
}
```

### 5.4 Performance Strategy

| Scenario | Strategy |
|----------|----------|
| Live Preview | Low-resolution composite (preview size) |
| Export | Full-resolution composite |
| Batch Processing | Background execution + progress reporting |
| Caching | Cache unchanged layer results |

### 5.5 Persistence

```
photo.dng
photo.rawctlrecipe  ← Existing adjustments
                    ← NEW: "layers": LayerStack
```

---

## 6. Implementation Tasks

### Phase 1: Data Models
- [ ] Add LayerStack to EditRecipe
- [ ] Implement Layer enum and subtypes
- [ ] Add CodableColor utility
- [ ] Update JSON encoding/decoding

### Phase 2: LayerRenderer
- [ ] Create LayerRenderer class
- [ ] Implement text rendering with variable substitution
- [ ] Implement shape rendering
- [ ] Implement drawing stroke rendering
- [ ] Integrate into ImagePipeline

### Phase 3: UI - Layer List
- [ ] Create LayerListView component
- [ ] Add layer selection state
- [ ] Implement drag-to-reorder
- [ ] Add visibility/lock toggles

### Phase 4: UI - Property Editor
- [ ] Create TextLayerEditor
- [ ] Create ShapeLayerEditor
- [ ] Create DrawingLayerEditor
- [ ] Create TransformEditor (shared)

### Phase 5: UI - Canvas Overlay
- [ ] Create LayerOverlayView (similar to CropOverlayView)
- [ ] Implement selection handles
- [ ] Implement drag/resize/rotate gestures
- [ ] Implement drawing canvas

### Phase 6: Template System
- [ ] Create LayerTemplate model
- [ ] Create TemplateVariable system
- [ ] Create TagLibrary storage
- [ ] Create template management UI
- [ ] Implement batch apply flow

---

## 7. Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `L` | Toggle Layers mode |
| `T` | Add Text layer |
| `S` | Add Shape layer |
| `D` | Add Drawing layer |
| `Delete` | Delete selected layer |
| `Cmd+D` | Duplicate layer |
| `Cmd+[` | Move layer back |
| `Cmd+]` | Move layer forward |
| `Cmd+Shift+[` | Move to back |
| `Cmd+Shift+]` | Move to front |

---

## Appendix: File Changes

### New Files
- `Models/LayerStack.swift` - Layer data models
- `Models/LayerTemplate.swift` - Template system
- `Services/LayerRenderer.swift` - Rendering engine
- `Services/VariableResolver.swift` - Variable substitution
- `Components/LayerOverlayView.swift` - Canvas overlay
- `Views/Layers/LayerListView.swift` - Layer list panel
- `Views/Layers/TextLayerEditor.swift` - Text properties
- `Views/Layers/ShapeLayerEditor.swift` - Shape properties
- `Views/Layers/DrawingLayerEditor.swift` - Drawing properties

### Modified Files
- `Models/EditRecipe.swift` - Add `layers: LayerStack`
- `Services/ImagePipeline.swift` - Integrate LayerRenderer
- `Views/InspectorView.swift` - Add Layers section
- `Views/ContentView.swift` - Add LayerOverlayView
