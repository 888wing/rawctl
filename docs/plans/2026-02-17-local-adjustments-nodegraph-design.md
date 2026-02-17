# Local Adjustments & Masking System Design
**Date**: 2026-02-17
**Version Target**: rawctl v2.0
**Status**: Design approved, ready for implementation

---

## Overview

Add a professional-grade local adjustment system to rawctl using an Implicit NodeGraph architecture (Lightroom-style). Each photo's edit recipe becomes a stack of nodes — one global node plus unlimited local adjustment nodes, each with its own mask and adjustments.

**Supported mask types (Phase 1):**
- Radial Gradient (圓形漸層)
- Linear Gradient (線性漸層)
- Brush (筆刷, Phase 2)

---

## Architecture Decision

**Chosen approach**: Implicit NodeGraph (Lightroom-style list UI)

| Approach | Time | Complexity | Flexibility |
|---------|------|-----------|-------------|
| Implicit List (chosen) | 3-4 weeks | Low | Medium |
| Explicit Node Editor | 8-10 weeks | Very High | Very High |
| Simplified (gradient only) | 1 week | Minimal | Low |

**Rationale**: Photographers are familiar with Lightroom's adjustment brush workflow. The existing `ColorNode`/`NodeGraph`/`NodeMask` models in `ColorNode.swift` provide a solid backend foundation — only the UI layer and pipeline integration are missing.

---

## Section 1: High-Level Architecture

### Pipeline Order

```
Input Image
    ↓
[Global Node]      ← existing sliders (exposure, contrast, HSL, etc.)
    ↓
[Local Node 1]     ← radial/linear/brush mask + own adjustments
    ↓
[Local Node 2]
    ↓
    ...
    ↓
Output
```

### Key Design Decisions

1. **Global node always first** — contains all existing global adjustments
2. **Local nodes stack sequentially** — list order = render order
3. **Masks are optional** — Global node has no mask; Local nodes must have one
4. **Non-destructive** — all stored in sidecar JSON

### Development Phases

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| 1 | 2 weeks | NodeGraph backend + Radial/Linear mask UI |
| 2 | 2 weeks | Brush tool + bitmap mask system |
| 3 | 1 week | Blend modes, opacity, density controls |

---

## Section 2: Data Model Changes

### EditRecipe v6

```swift
struct EditRecipe: Codable, Equatable {
    var schemaVersion: Int = 6

    // MARK: - Node-Based Editing (v6+)
    var nodeGraph: NodeGraph

    // MARK: - Metadata (unchanged)
    var rating: Int = 0
    var colorLabel: ColorLabel = .none
    var flag: Flag = .none
    var tags: [String] = []

    init() {
        // Creates: Input → Global → Output
        let inputNode = ColorNode(name: "Input", type: .input)
        let globalNode = ColorNode(name: "Global", type: .serial)
        let outputNode = ColorNode(name: "Output", type: .output)

        var graph = NodeGraph()
        graph.nodes = [inputNode, globalNode, outputNode]
        graph.connections = [
            NodeConnection(from: inputNode.id, to: globalNode.id),
            NodeConnection(from: globalNode.id, to: outputNode.id)
        ]
        self.nodeGraph = graph
    }
}
```

### NodeMask Enhancement (add Brush + Density)

```swift
struct NodeMask: Codable, Equatable {
    var type: MaskType
    var feather: Double = 20.0
    var density: Double = 100.0   // NEW: overall mask strength 0-100
    var invert: Bool = false

    enum MaskType: Codable, Equatable {
        case luminosity(min: Double, max: Double)
        case color(hue: Double, hueRange: Double, satMin: Double)
        case radial(centerX: Double, centerY: Double, radius: Double)
        case linear(angle: Double, position: Double, falloff: Double)
        case brush(bitmap: BrushMaskBitmap)  // NEW
    }
}

struct BrushMaskBitmap: Codable, Equatable {
    var width: Int
    var height: Int
    var data: Data   // Grayscale bitmap (1 byte per pixel, 0-255)
    // Storage: PNG-encoded then base64 in JSON
}
```

### Schema Migration: v5 → v6

Migration is automatic on decode. All existing v5 sidecars load correctly:

```swift
init(from decoder: Decoder) throws {
    let version = decodeVersion(decoder) ?? 5

    if version < 6 {
        // Auto-migrate: wrap v5 flat adjustments into a Global node
        let v5 = try EditRecipe_v5(from: decoder)
        self.init()  // Creates default graph (Input → Global → Output)

        // Place v5 adjustments into Global node
        if let i = nodeGraph.nodes.firstIndex(where: { $0.name == "Global" }) {
            nodeGraph.nodes[i].adjustments = v5
        }

        self.rating = v5.rating
        self.colorLabel = v5.colorLabel
        self.flag = v5.flag
        self.tags = v5.tags
    } else {
        // v6: direct decode
        self.nodeGraph = try container.decode(NodeGraph.self, forKey: .nodeGraph)
        // ... metadata
    }
}
```

Migration is **read-only**: old `.rawctl.json` files are read and automatically upgraded in memory. The upgraded v6 format is saved on first edit.

---

## Section 3: UI Components

### Inspector Integration

New **"Local Adjustments"** panel added between Composition and Effects in `InspectorView`.

```
Inspector (right panel)
├── Light
├── Color
├── Composition
├── Local Adjustments  ← NEW
│   ├── [+ Add Adjustment] menu
│   ├── LocalAdjustmentRow: "Brighten Face"  (radial)
│   ├── LocalAdjustmentRow: "Darken Sky"     (linear)
│   └── LocalAdjustmentRow: "Retouch"        (brush)
├── Effects
└── Detail
```

### MaskingPanel

```swift
struct MaskingPanel: View {
    // Displays list of local nodes (excludes Input, Global, Output)
    // [+ Add Adjustment] Menu → addRadialMask() | addLinearMask() | addBrushMask()
    // Supports drag-to-reorder (changes render order)
}
```

### LocalAdjustmentRow

Each row shows:
- **Checkbox**: enable/disable node
- **Mask icon**: circle (radial) / bars (linear) / brush
- **Name**: editable text field
- **Pencil button**: enter mask editing mode
- **Chevron**: expand/collapse adjustment sliders

Expanded state shows only non-zero adjustments plus an **"Add Parameter"** menu to add more sliders.

### AppState New Properties

```swift
@Published var editingMaskId: UUID? = nil   // which node is being masked
@Published var showMaskOverlay: Bool = true  // toggle mask visualization
```

### Mask Editing Mode (SingleView)

When `editingMaskId != nil`:
1. Preview shows the mask overlay (semi-transparent)
2. Interactive handles appear on photo (drag to reposition/resize)
3. **MaskEditingToolbar** floats at bottom: Feather slider, Invert, Show Mask toggle, Done, Cancel

---

## Section 4: Mask Tools

### Radial Mask Editor

Interactive handles on the photo:
- **Center handle** (white circle, 20pt): drag to reposition
- **Radius handle** (white circle, 16pt): drag to resize
- **Solid circle outline**: inner edge of mask
- **Dashed circle outline**: feather extent (outer edge)

All coordinates stored as normalized 0-1 values relative to image dimensions.

### Linear Mask Editor

Interactive elements on the photo:
- **Center handle**: drag to move the gradient line (perpendicular direction)
- **Endpoint handles**: drag to rotate
- **Two parallel dashed lines**: show falloff extent

Angle stored in degrees (0 = horizontal), position as 0-1 (0 = top, 1 = bottom), falloff as 0-1 fraction.

### Brush Mask Editor

- **Canvas-based** painting using SwiftUI `Canvas`
- Bitmap dimensions match scaled preview size, upscaled at export
- **Brush properties** in toolbar: Size (10-200px), Hardness (0-1), Opacity (0-1)
- **Alt+drag** = erase mode
- Gaussian falloff from brush center based on hardness:
  ```
  alpha = 1.0                           if distance ≤ radius × (1 - hardness)
  alpha = linear falloff to 0.0         if distance ≤ radius
  alpha = 0.0                           if distance > radius
  ```
- Strokes commit to `BrushMaskBitmap.data` on `DragGesture.onEnded`

---

## Section 5: Rendering Pipeline

### Updated renderPreview()

```swift
func renderPreview(for asset: PhotoAsset, recipe: EditRecipe, maxSize: CGFloat, fastMode: Bool) async -> NSImage? {
    // 1. Load base image (RAW via CIRAWFilter, or standard)
    guard var base = await loadBaseImage(asset, isRaw, maxSize) else { return nil }

    // 2. Apply NodeGraph
    base = await renderNodeGraph(recipe.nodeGraph, baseImage: base, fastMode: fastMode)

    return renderToNSImage(base)
}
```

### NodeGraph Rendering Loop

```swift
func renderNodeGraph(_ graph: NodeGraph, baseImage: CIImage, fastMode: Bool) async -> CIImage {
    var result = baseImage

    for node in graph.enabledNodes {
        guard node.type == .serial else { continue }

        // Apply this node's adjustments to current result
        var nodeOutput = applyNodeAdjustments(node.adjustments, to: result, fastMode: fastMode)

        // If has mask: blend adjusted back over original using mask
        if let mask = node.mask {
            let maskImage = createMaskImage(mask, extent: result.extent)
            let blend = CIFilter.blendWithMask()
            blend.inputImage = nodeOutput      // foreground (adjusted)
            blend.backgroundImage = result     // background (original)
            blend.maskImage = maskImage
            nodeOutput = blend.outputImage ?? nodeOutput
        }

        // Apply blend mode / opacity if non-default
        if node.blendMode != .normal || node.opacity < 1.0 {
            nodeOutput = blendImages(background: result, foreground: nodeOutput,
                                     mode: node.blendMode, opacity: node.opacity)
        }

        result = nodeOutput
    }

    return result
}
```

### Mask Image Generation Pipeline

```
NodeMask
    ↓ createBaseShape (radial / linear / brush / luminosity / color)
    ↓ apply Gaussian blur (feather)
    ↓ invert (if mask.invert)
    ↓ scale opacity (density)
    → CIImage (grayscale mask)
```

Used by `CIBlendWithMask` to composite adjusted region over original.

### Performance Optimizations

1. **Incremental rendering**: Cache per-node outputs; only re-render from changed node onwards
2. **Fast mode**: Skip expensive filters (grain, noiseReduction, HSL, clarity) during scrubbing
3. **Node cache invalidation**: Clear on photo switch or explicit recipe reset
4. **Brush bitmap**: Paint directly into `Data` buffer on drag; only commit to model on stroke end

---

## Section 6: Persistence & Migration

### Sidecar v6 JSON Example

```json
{
  "schemaVersion": 6,
  "edit": {
    "nodeGraph": {
      "nodes": [
        { "id": "...", "name": "Input",  "type": "input",  "adjustments": {} },
        { "id": "...", "name": "Global", "type": "serial",
          "adjustments": { "exposure": 0.5, "contrast": 15, "profileId": "rawctl-vivid" } },
        { "id": "...", "name": "Darken Sky", "type": "serial",
          "adjustments": { "exposure": -0.5, "saturation": 15 },
          "mask": {
            "type": { "linear": { "angle": 0, "position": 0.3, "falloff": 0.4 } },
            "feather": 20, "density": 100, "invert": false
          }
        },
        { "id": "...", "name": "Output", "type": "output", "adjustments": {} }
      ],
      "connections": [ ... ]
    },
    "rating": 4,
    "colorLabel": "green",
    "flag": "pick"
  }
}
```

### Migration Rules

| From | To | Action |
|------|-----|--------|
| v1–v5 | v6 | Wrap global adjustments into Global node; preserve metadata |
| v6 | v6 | Direct decode, no migration needed |

- Migration is **automatic on read**, **non-destructive**
- Original v5 file is preserved until first write (then replaced with v6)
- Sidecar filename unchanged: `{photo}.rawctl.json`

### Backward Compatibility

rawctl v1.x cannot read v6 sidecars. Strategy:
- rawctl v2.0 writes v6 format
- If a v1.x user opens a v6 sidecar, they see no edits (graceful degradation — existing `decodeIfPresent` handles missing keys)

---

## Section 7: Testing

### Unit Tests (`rawctlTests/NodeGraphTests.swift`)

| Test | Coverage |
|------|---------|
| Default recipe creates Global node | Data model |
| Topological sort (shuffled input) | NodeGraph |
| v5 → v6 migration correctness | All adjustment fields |
| v6 sidecar roundtrip | Encode/decode |
| Radial mask generation | ImagePipeline |
| Linear mask generation | ImagePipeline |
| Mask invert | ImagePipeline |
| Brush bitmap roundtrip | BrushMaskBitmap |
| Brush stroke painting (center/edge) | BrushMaskBitmap |

### Integration Tests (`rawctlTests/MaskingIntegrationTests.swift`)

| Test | Coverage |
|------|---------|
| Multiple local adjustments stack | Render order |
| Sidecar roundtrip with masks | Full persistence |
| Migration from each schema version | v1, v2, v3, v4, v5 |

### Coverage Targets

| Area | Target |
|------|--------|
| NodeGraph data model | 95%+ |
| Mask generation | 90%+ |
| ImagePipeline integration | 85%+ |
| Migration (all v1-v5 formats) | 100% |

### Performance Targets

| Scenario | Target |
|----------|--------|
| Fast mode render (5 local adjustments) | < 50ms |
| Full quality render (5 adjustments) | < 500ms |
| Brush stroke response | < 16ms (60fps) |
| Sidecar save with large brush bitmap | < 200ms |

---

## Implementation Plan

### Phase 1: NodeGraph Backend + Gradient Masks (2 weeks)

**Week 1:**
- [ ] Rename existing `EditRecipe` → `EditRecipe_v5` (keep all fields)
- [ ] Create new `EditRecipe` v6 with `nodeGraph: NodeGraph`
- [ ] Implement `init(from decoder:)` with v5→v6 migration
- [ ] Update `SidecarFile.schemaVersion` to 6
- [ ] Update `SidecarService` to use new model
- [ ] Update `ImagePipeline.renderPreview()` to use `renderNodeGraph()`
- [ ] Implement `applyNodeAdjustments()` (refactored from existing code)
- [ ] Implement `createMaskImage()` for radial and linear types
- [ ] Write unit tests for migration and rendering

**Week 2:**
- [ ] Implement `MaskingPanel` in Inspector
- [ ] Implement `LocalAdjustmentRow`
- [ ] Add `editingMaskId` to `AppState`
- [ ] Implement `MaskOverlayView` on SingleView
- [ ] Implement `RadialMaskEditor` with drag handles
- [ ] Implement `LinearMaskEditor` with drag handles
- [ ] Implement `MaskEditingToolbar`
- [ ] End-to-end test: create radial mask → adjust exposure → save → reload

### Phase 2: Brush Tool (2 weeks)

**Week 3:**
- [ ] Implement `BrushMaskBitmap` with `paintAt()` method
- [ ] Implement `BrushMaskEditor` using SwiftUI Canvas
- [ ] Implement `createBrushMask()` in ImagePipeline
- [ ] Add PNG compression for bitmap storage
- [ ] Brush tool UI: size, hardness, opacity sliders in toolbar

**Week 4:**
- [ ] Erase mode (Alt+drag)
- [ ] Brush preview cursor on hover
- [ ] Undo support for brush strokes
- [ ] Performance testing with large bitmaps
- [ ] End-to-end test: brush mask → save → reload → render

### Phase 3: Polish (1 week)

- [ ] Blend mode picker per local node
- [ ] Opacity slider per local node
- [ ] Mask density slider
- [ ] "Duplicate Adjustment" in context menu
- [ ] Keyboard shortcut: `M` to toggle mask overlay
- [ ] Update CHANGELOG.md

---

## Files to Create / Modify

| File | Action | Notes |
|------|--------|-------|
| `Models/EditRecipe.swift` | Modify | v6 with nodeGraph, migration decoder |
| `Models/ColorNode.swift` | Modify | Add brush mask, density to NodeMask |
| `Services/ImagePipeline.swift` | Modify | renderNodeGraph, applyNodeAdjustments, createMaskImage |
| `Services/SidecarService.swift` | Modify | schemaVersion 6 |
| `Models/AppState.swift` | Modify | editingMaskId, showMaskOverlay |
| `Components/MaskingPanel.swift` | Create | New panel |
| `Components/LocalAdjustmentRow.swift` | Create | New component |
| `Components/MaskOverlayView.swift` | Create | Overlay on SingleView |
| `Components/RadialMaskEditor.swift` | Create | Drag handles |
| `Components/LinearMaskEditor.swift` | Create | Drag handles |
| `Components/BrushMaskEditor.swift` | Create | Canvas-based painting |
| `Components/MaskEditingToolbar.swift` | Create | Editing controls |
| `Views/SingleView.swift` | Modify | Integrate MaskOverlayView |
| `Views/InspectorView.swift` | Modify | Add MaskingPanel |
| `rawctlTests/NodeGraphTests.swift` | Create | Unit tests |
| `rawctlTests/MaskingIntegrationTests.swift` | Create | Integration tests |
