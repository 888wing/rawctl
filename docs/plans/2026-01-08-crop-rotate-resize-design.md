# Crop, Rotate & Resize Overhaul

**Date:** 2026-01-08
**Status:** Approved

## Overview

Full overhaul of crop, rotate, and resize features with unified UI entry points and enhanced functionality.

## Current State

| Feature | Status | Location |
|---------|--------|----------|
| Crop | Basic UI exists | `CropOverlayView`, toggle in Composition panel |
| 90° Rotation | Works | Buttons in Composition panel |
| Fine Rotation | Exists but separate | Transform panel (-45° to +45°) |
| Resize | Export only | No edit-time resize UI |
| Aspect Ratios | Picker exists | Not enforced in overlay |

## Design

### 1. UI Entry Points

**Toolbar Buttons (SingleView bottom-left)**

Two buttons displayed horizontally:

```
┌──────────┬──────────┐
│ ✂️ Crop  │ ✨ AI Edit│
└──────────┴──────────┘
```

- Crop button enters **Transform Mode**
- Keyboard shortcut: **C** to enter/exit
- Press **Enter** or "Done" to commit
- Press **Escape** to cancel

**Inspector Panel**

Reorganize Composition section into 3 sub-sections:
- **Crop** - aspect ratio, straighten, flip
- **Rotate** - 90° buttons integrated with straighten
- **Resize** - new feature

### 2. Crop Enhancement

**Data Model (EditRecipe.swift)**

```swift
struct Crop: Codable, Equatable {
    var isEnabled: Bool = false
    var aspect: Aspect = .free
    var rect: CropRect = CropRect()
    var rotationDegrees: Int = 0          // 90° increments (existing)
    var straightenAngle: Double = 0       // NEW: -45° to +45°
    var flipHorizontal: Bool = false      // NEW
    var flipVertical: Bool = false        // NEW

    enum Aspect: String, Codable, CaseIterable, Identifiable {
        case free = "free"
        case original = "original"        // NEW
        case square = "1:1"
        case ratio4x3 = "4:3"
        case ratio3x2 = "3:2"
        case ratio16x9 = "16:9"
        case ratio5x4 = "5:4"             // NEW
        case ratio7x5 = "7:5"             // NEW

        var aspectRatio: Double? {
            switch self {
            case .free, .original: return nil
            case .square: return 1.0
            case .ratio4x3: return 4.0/3.0
            case .ratio3x2: return 3.0/2.0
            case .ratio16x9: return 16.0/9.0
            case .ratio5x4: return 5.0/4.0
            case .ratio7x5: return 7.0/5.0
            }
        }
    }
}
```

**CropOverlayView Enhancement**
- Enforce aspect ratio when dragging corners
- Display current dimensions in pixels
- Support locked ratio mode

**Inspector UI**

```
┌─ Crop ─────────────────────────────────┐
│  [Toggle: Enable Crop]                 │
│                                        │
│  Aspect Ratio: [Free ▼]               │
│  ┌────┬────┬────┬────┐                │
│  │Free│1:1 │4:3 │16:9│                │
│  └────┴────┴────┴────┘                │
│                                        │
│  Straighten: ────●──── [-45° to +45°] │
│                                        │
│  ┌────┬────┐  ┌────┬────┐            │
│  │ ↺  │ ↻  │  │ ↔️ │ ↕️ │            │
│  │-90°│+90°│  │Flip│Flip│            │
│  └────┴────┘  └────┴────┘            │
└────────────────────────────────────────┘
```

### 3. Rotate Integration

**Unified Rotation Control**

All rotation handled in Crop struct (remove Transform panel's rotate):

```swift
var rotationDegrees: Int = 0        // 90° increments (0, 90, 180, 270)
var straightenAngle: Double = 0     // -45° to +45° continuous
```

**ImagePipeline Update**

```swift
private func applyRotation(_ crop: Crop, to image: CIImage) -> CIImage {
    var result = image

    // 1. Apply 90° rotation
    if crop.rotationDegrees != 0 {
        let radians = CGFloat(crop.rotationDegrees) * .pi / 180.0
        result = result.transformed(by: CGAffineTransform(rotationAngle: radians))
    }

    // 2. Apply fine angle
    if crop.straightenAngle != 0 {
        let radians = CGFloat(crop.straightenAngle) * .pi / 180.0
        let center = CGPoint(x: result.extent.midX, y: result.extent.midY)
        let transform = CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: radians)
            .translatedBy(x: -center.x, y: -center.y)
        result = result.transformed(by: transform)
    }

    // 3. Apply flips
    if crop.flipHorizontal {
        result = result.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
    }
    if crop.flipVertical {
        result = result.transformed(by: CGAffineTransform(scaleX: 1, y: -1))
    }

    return result
}
```

### 4. Resize Feature (New)

**Data Model**

```swift
struct Resize: Codable, Equatable {
    var isEnabled: Bool = false
    var mode: ResizeMode = .pixels
    var width: Int = 0                    // 0 = auto-calculate
    var height: Int = 0
    var percentage: Double = 100          // 50-200%
    var preset: ResizePreset = .none
    var maintainAspectRatio: Bool = true

    enum ResizeMode: String, Codable {
        case pixels
        case percentage
        case preset
        case longEdge
        case shortEdge
    }

    enum ResizePreset: String, Codable, CaseIterable {
        case none = "None"
        case instagram = "Instagram (1080×1080)"
        case instagramPortrait = "Instagram Portrait (1080×1350)"
        case facebookCover = "Facebook Cover (1640×856)"
        case twitterHeader = "Twitter Header (1500×500)"
        case wallpaper4K = "4K Wallpaper (3840×2160)"
        case wallpaper2K = "2K Wallpaper (2560×1440)"
        case web1080 = "Web 1080p (1920×1080)"

        var dimensions: (width: Int, height: Int)? { ... }
    }
}
```

**Behavior Clarification**

| | In-App Resize | Export Resize |
|---|---|---|
| Purpose | Permanently set output dimensions | Temporary scale for single export |
| Location | Inspector → Resize panel | Export Dialog |
| Storage | Written to sidecar, affects all exports | One-time export setting |
| Reversible | ✅ Non-destructive (stored in recipe) | N/A |

In-app Resize does NOT resample the original image:
1. Target dimensions saved to `EditRecipe.resize`
2. Preview shows scaled effect
3. **Actual scaling happens at export time**

This maintains non-destructive editing principles.

**User Warning UI**

```
┌─ Resize ───────────────────────────────┐
│  [Toggle: Enable Resize]               │
│                                        │
│  ⚠️ Resize changes final output size.  │
│     Original file is not affected.     │
│     Applied when exporting.            │
│                                        │
│  Mode: [Long Edge ▼]                   │
│  ...                                   │
└────────────────────────────────────────┘
```

**Export Dialog Integration**

```
Export Dialog:
┌────────────────────────────────────────┐
│  Output Size:                          │
│  ○ Original (6000×4000)               │
│  ○ Use Recipe Resize (2000×1333)      │
│  ○ Custom: [____] × [____]            │
│                                        │
│  ℹ️ Recipe has Resize set, using that  │
└────────────────────────────────────────┘
```

## Implementation

### Files to Modify

| File | Changes |
|------|---------|
| `EditRecipe.swift` | Extend `Crop` struct, add `Resize` struct |
| `ImagePipeline.swift` | Add `applyRotation()`, `applyResize()`, integrate into pipeline |
| `CropOverlayView.swift` | Enforce aspect ratios, show dimension labels |
| `SingleView.swift` | Add toolbar buttons, Transform Mode state |
| `InspectorView.swift` | Refactor Composition → Crop/Rotate/Resize sections |
| `ExportDialog.swift` | Integrate Recipe Resize option |
| `AppState.swift` | Add `transformMode: Bool` |

### New Files

| File | Purpose |
|------|---------|
| `Components/TransformToolbar.swift` | Quick controls bar above image |
| `Components/ResizePanel.swift` | Resize controls in Inspector |

### Implementation Phases

```
Phase 1: Data Model
├── Extend Crop struct (straightenAngle, flip)
├── Add Resize struct
└── Update sidecar schema version

Phase 2: ImagePipeline
├── Integrate rotation logic
├── Implement applyResize()
└── Adjust processing order

Phase 3: UI - Inspector
├── Refactor Composition section
├── Add ResizePanel
└── Enhance Crop controls

Phase 4: UI - SingleView
├── Add toolbar button group
├── Transform Mode state management
├── CropOverlayView enhancement

Phase 5: Export Integration
└── ExportDialog support for Recipe Resize
```

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| C | Enter/exit Transform Mode |
| Enter | Commit changes |
| Escape | Cancel changes |
| R | Rotate 90° clockwise (in Transform Mode) |
| Shift+R | Rotate 90° counter-clockwise |
| H | Flip horizontal |
| V | Flip vertical |
