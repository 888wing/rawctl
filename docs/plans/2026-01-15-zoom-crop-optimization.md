# Zoom & Crop Optimization Design

**Version**: v1.4
**Date**: 2026-01-15
**Status**: Planning

## Overview

This document outlines the optimization plan for SingleView zoom functionality and restructuring of the crop feature to match Lightroom-style workflow.

---

## Part 1: Zoom Optimization

### Current Issues

1. **縮放定位不準 (Zoom position inaccurate)**
   - Zoom uses `scaleEffect()` without proper anchor point
   - Double-click zoom doesn't center on cursor position
   - Pan after zoom causes position jumps

2. **縮放範圍不夠 (Zoom range insufficient)**
   - Only 2 levels: Fit (1.0x) and "100%" (2.0x)
   - No intermediate zoom levels
   - No scroll wheel zoom support

3. **縮放不順暢 (Zoom not smooth)**
   - No gesture-based zoom (pinch/scroll)
   - Abrupt transitions between zoom levels

### Proposed Solution

#### 1.1 Zoom Architecture Refactor

```swift
// New zoom state model
struct ZoomState {
    var scale: CGFloat = 1.0        // Current zoom scale (0.1 to 8.0)
    var offset: CGSize = .zero      // Pan offset in image coordinates
    var anchorPoint: CGPoint = .zero // Zoom anchor (normalized 0-1)

    // Computed
    var fittedScale: CGFloat        // Scale to fit image in view
    var actualScale: CGFloat        // scale * fittedScale = actual magnification
}
```

#### 1.2 Zoom Levels

| Button | Scale | Description |
|--------|-------|-------------|
| Fit | 1.0x | Fit entire image in view |
| Fill | Auto | Fill view (may crop edges) |
| 50% | 0.5x | Half of actual size |
| 100% | 1.0x actual | 1:1 pixel mapping |
| 200% | 2.0x actual | 2x magnification |

#### 1.3 Zoom Gestures

- **Scroll wheel**: Smooth zoom in/out at cursor position
- **Pinch (trackpad)**: Two-finger pinch zoom
- **Double-click**: Toggle between Fit and 100%
- **Option+scroll**: Horizontal pan
- **Drag**: Pan when zoomed > Fit

#### 1.4 Implementation Steps

1. Replace `scaleEffect()` with proper coordinate transform
2. Calculate zoom anchor from cursor/center position
3. Add `MagnifyGesture` for trackpad pinch
4. Add scroll wheel handler with `onScrollWheel` modifier
5. Implement smooth animated transitions
6. Add zoom percentage indicator overlay
7. Clamp pan to image bounds

#### 1.5 Key Code Changes

**SingleView.swift**:
```swift
// New zoom handling
@State private var zoomState = ZoomState()

// Scroll wheel zoom
.onScrollWheel { event in
    let delta = event.deltaY
    let cursorPos = event.locationInWindow
    zoomAtPoint(delta: delta, point: cursorPos)
}

// Magnify gesture
.gesture(
    MagnifyGesture()
        .onChanged { value in
            zoomState.scale *= value.magnification
        }
)
```

---

## Part 2: Crop Restructure (Lightroom-Style)

### Current Issues

1. **裁切後無法預覽效果** - Crop overlay shows frame but preview doesn't show cropped result
2. **裁切比例無法鎖定** - Aspect ratio exists in model but UI not accessible
3. **裁切框操作不直覺** - Current: drag frame over image; Lightroom: drag image under fixed frame
4. **裁切結果未正確儲存** - Need to verify sidecar persistence

### Lightroom Crop Workflow Reference

```
1. Press C or click Crop button
2. Crop overlay appears with current aspect ratio
3. Drag corners/edges to resize frame
4. Drag inside frame to reposition image underneath
5. Use aspect ratio picker to lock ratio
6. Grid overlays help composition (thirds, golden ratio)
7. Straighten slider for rotation
8. Press Enter to confirm, Esc to cancel
9. Preview immediately shows cropped result
10. GridView thumbnails update to show crop
```

### Proposed Architecture

#### 2.1 Crop Mode State Machine

```swift
enum CropMode {
    case inactive           // Normal viewing
    case active(CropState)  // Crop editing active
}

struct CropState {
    var rect: CropRect              // Normalized crop rectangle
    var aspect: Crop.Aspect         // Locked aspect ratio
    var straightenAngle: Double     // -45 to +45 degrees
    var overlayType: GridOverlay    // Composition guide type
    var isDraggingImage: Bool       // True = move image under frame
    var isDraggingHandle: Bool      // True = resize frame
    var previewCropped: Bool        // Show cropped preview
}

enum GridOverlay: String, CaseIterable {
    case none = "None"
    case thirds = "Rule of Thirds"
    case phi = "Golden Ratio"
    case diagonal = "Diagonal"
    case triangle = "Golden Triangle"
    case spiral = "Golden Spiral"
}
```

#### 2.2 New Crop Workflow

```
┌─────────────────────────────────────────────────────────────┐
│  Press C / Click Crop Button                                │
│         ↓                                                   │
│  CropMode.active                                            │
│         ↓                                                   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Crop Overlay View                                   │   │
│  │  ┌─────────────────────────────────────┐            │   │
│  │  │  [Aspect Picker] [Grid] [Straighten]│  ← Toolbar │   │
│  │  └─────────────────────────────────────┘            │   │
│  │                                                      │   │
│  │  ┌─────────────────────────────────────┐            │   │
│  │  │         Crop Frame                   │            │   │
│  │  │    ┌───────────────────┐            │            │   │
│  │  │    │   Image Preview   │ ← Drag to  │            │   │
│  │  │    │   (shows crop)    │   reposition│            │   │
│  │  │    └───────────────────┘            │            │   │
│  │  │  ↑ Drag handles to resize           │            │   │
│  │  └─────────────────────────────────────┘            │   │
│  │                                                      │   │
│  │  ┌─────────────────────────────────────┐            │   │
│  │  │  Dimensions: 4032 × 2268 (16:9)     │  ← Info   │   │
│  │  └─────────────────────────────────────┘            │   │
│  └─────────────────────────────────────────────────────┘   │
│         ↓                                                   │
│  Press Enter → Save crop → Exit mode → Preview updates     │
│  Press Esc   → Cancel    → Exit mode → Revert changes      │
└─────────────────────────────────────────────────────────────┘
```

#### 2.3 Component Breakdown

##### CropToolbar.swift (New)
```swift
struct CropToolbar: View {
    @Binding var aspect: Crop.Aspect
    @Binding var overlay: GridOverlay
    @Binding var straightenAngle: Double

    var body: some View {
        HStack(spacing: 16) {
            // Aspect ratio picker
            AspectPicker(selection: $aspect)

            Divider().frame(height: 20)

            // Grid overlay picker
            GridOverlayPicker(selection: $overlay)

            Divider().frame(height: 20)

            // Straighten slider
            StraightenSlider(angle: $straightenAngle)

            Spacer()

            // Flip buttons
            Button { flipHorizontal() } label: {
                Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
            }
            Button { flipVertical() } label: {
                Image(systemName: "arrow.up.and.down.righttriangle.up.righttriangle.down")
            }

            // Rotate 90° buttons
            Button { rotate90(.counterclockwise) } label: {
                Image(systemName: "rotate.left")
            }
            Button { rotate90(.clockwise) } label: {
                Image(systemName: "rotate.right")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}
```

##### CropOverlayView.swift (Refactored)
Key changes:
1. Add toolbar integration
2. Support multiple grid overlay types
3. Implement "drag image under frame" mode
4. Real-time cropped preview
5. Better handle hit testing

##### CropPreviewMode
When crop mode is active, render preview with crop applied in real-time:
```swift
// In loadPreview()
if appState.cropMode.isActive && cropState.previewCropped {
    // Apply current crop rect to preview
    recipe.crop = cropState.currentCrop
    recipe.crop.isEnabled = true
}
```

#### 2.4 Grid Overlay Implementations

```swift
// Rule of Thirds (existing)
func drawThirdsGrid(in rect: CGRect) -> Path

// Golden Ratio (φ = 1.618)
func drawPhiGrid(in rect: CGRect) -> Path {
    let phi: CGFloat = 1.618
    let w = rect.width
    let h = rect.height
    // Vertical lines at w/φ and w - w/φ
    // Horizontal lines at h/φ and h - h/φ
}

// Diagonal
func drawDiagonalGrid(in rect: CGRect) -> Path {
    // Corner to corner diagonals
}

// Golden Triangle
func drawGoldenTriangle(in rect: CGRect) -> Path {
    // Diagonal + perpendiculars from corners
}

// Golden Spiral (Fibonacci)
func drawGoldenSpiral(in rect: CGRect) -> Path {
    // Fibonacci spiral overlay
}
```

#### 2.5 Straighten Tool

```swift
struct StraightenSlider: View {
    @Binding var angle: Double  // -45 to +45

    var body: some View {
        HStack {
            Image(systemName: "level")
            Slider(value: $angle, in: -45...45)
                .frame(width: 120)
            Text(String(format: "%.1f°", angle))
                .font(.system(size: 10, design: .monospaced))
                .frame(width: 45)
        }
    }
}
```

#### 2.6 GridView Crop Preview

When crop is applied, GridView should show cropped thumbnails:

```swift
// GridThumbnail.swift - already doing this via recipe
.task(id: recipe) {
    if hasEdits {
        // This already renders with crop applied
        thumbnail = await ImagePipeline.shared.renderPreview(
            for: asset,
            recipe: recipe,  // Includes crop
            maxSize: size * 2,
            fastMode: true
        )
    }
}
```

**Issue**: Need to ensure `recipe.crop.isEnabled` is set when crop rect changes.

---

## Part 3: Implementation Plan

### Phase 1: Zoom Optimization (Priority: High)

| Task | Effort | Files |
|------|--------|-------|
| 1.1 Refactor zoom state management | 2h | SingleView.swift |
| 1.2 Add scroll wheel zoom | 1h | SingleView.swift |
| 1.3 Add pinch gesture zoom | 1h | SingleView.swift |
| 1.4 Fix zoom anchor point calculation | 2h | SingleView.swift |
| 1.5 Add zoom level buttons (50%, 100%, 200%) | 1h | SingleView.swift |
| 1.6 Implement smooth pan with bounds clamping | 1h | SingleView.swift |
| 1.7 Add zoom percentage indicator | 0.5h | SingleView.swift |

### Phase 2: Crop Restructure (Priority: High)

| Task | Effort | Files |
|------|--------|-------|
| 2.1 Create CropToolbar component | 2h | Components/CropToolbar.swift (new) |
| 2.2 Add grid overlay options | 2h | CropOverlayView.swift |
| 2.3 Implement "drag image under frame" mode | 3h | CropOverlayView.swift |
| 2.4 Add straighten slider with preview | 2h | CropToolbar.swift, CropOverlayView.swift |
| 2.5 Wire up aspect ratio picker | 1h | CropToolbar.swift |
| 2.6 Real-time cropped preview in crop mode | 2h | SingleView.swift, ImagePipeline.swift |
| 2.7 Fix crop.isEnabled auto-set on rect change | 1h | CropOverlayView.swift |
| 2.8 Ensure GridView updates with crop | 1h | GridView.swift verification |

### Phase 3: Polish & Testing

| Task | Effort | Files |
|------|--------|-------|
| 3.1 Keyboard shortcuts (Enter/Esc in crop mode) | 0.5h | SingleView.swift |
| 3.2 Smooth animations for mode transitions | 1h | Various |
| 3.3 Test crop persistence in sidecar | 1h | SidecarService.swift |
| 3.4 Performance optimization for real-time preview | 2h | ImagePipeline.swift |

---

## Part 4: Technical Details

### 4.1 Zoom Coordinate Math

```swift
/// Calculate new offset to zoom at specific point
func zoomAtPoint(scale: CGFloat, point: CGPoint, currentOffset: CGSize, currentScale: CGFloat) -> CGSize {
    // Convert screen point to image coordinates
    let imagePoint = CGPoint(
        x: (point.x - currentOffset.width) / currentScale,
        y: (point.y - currentOffset.height) / currentScale
    )

    // Calculate new offset to keep imagePoint at same screen position
    let newOffset = CGSize(
        width: point.x - imagePoint.x * scale,
        height: point.y - imagePoint.y * scale
    )

    return newOffset
}
```

### 4.2 Crop "Drag Image" Mode

In Lightroom, when you drag inside the crop frame, the image moves underneath while the frame stays fixed. This requires inverting the drag logic:

```swift
// Current (drag frame):
cropRect.x += delta.x
cropRect.y += delta.y

// Lightroom style (drag image under fixed frame):
// Moving image right = crops more from left
cropRect.x -= delta.x / imageScale
cropRect.y -= delta.y / imageScale
```

### 4.3 Aspect Ratio Enforcement

When aspect ratio is locked, handle resizing needs to maintain ratio:

```swift
func constrainToAspect(_ rect: CropRect, aspect: Double, anchor: CornerPosition) -> CropRect {
    var result = rect

    // Determine which dimension to adjust based on drag direction
    let currentAspect = rect.w / rect.h

    if currentAspect > aspect {
        // Too wide, reduce width
        result.w = result.h * aspect
    } else {
        // Too tall, reduce height
        result.h = result.w / aspect
    }

    // Anchor adjustment based on which corner is being dragged
    // ...

    return result
}
```

---

## Part 5: UI/UX Reference

### Crop Mode Visual Design

```
┌────────────────────────────────────────────────────────────────┐
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ [16:9 ▾] │ [⊞ Thirds ▾] │ ─○─ -2.5° │ ⟲ ⟳ │ ⇆ ⇅ │ ✓ ✕ │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                │
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
│  ░░░░┌────────────────────────────────────────────────┐░░░░░  │
│  ░░░░│ · · · · · · · · │ · · · · · · · · │ · · · · · │░░░░░  │
│  ░░░░│                 │                 │           │░░░░░  │
│  ░░░░│─────────────────┼─────────────────┼───────────│░░░░░  │
│  ░░░░│                 │                 │           │░░░░░  │
│  ░░░░│                 │      IMAGE      │           │░░░░░  │
│  ░░░░│                 │                 │           │░░░░░  │
│  ░░░░│─────────────────┼─────────────────┼───────────│░░░░░  │
│  ░░░░│                 │                 │           │░░░░░  │
│  ░░░░│ · · · · · · · · │ · · · · · · · · │ · · · · · │░░░░░  │
│  ░░░░└────────────────────────────────────────────────┘░░░░░  │
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │              3840 × 2160  •  16:9  •  8.3 MP             │ │
│  └──────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────┘

Legend:
░░░░ = Dimmed area (outside crop)
───  = Rule of thirds grid lines
· · = Corner/edge handles
```

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `C` | Toggle crop mode |
| `Enter` | Confirm crop and exit |
| `Esc` | Cancel crop and exit |
| `O` | Cycle through grid overlays |
| `X` | Swap aspect ratio (e.g., 16:9 ↔ 9:16) |
| `R` | Reset crop to original |
| `[` / `]` | Rotate straighten -1° / +1° |
| `Shift+[` / `]` | Rotate -5° / +5° |

---

## Success Criteria

### Zoom
- [ ] Scroll wheel zooms smoothly at cursor position
- [ ] Pinch gesture works on trackpad
- [ ] Double-click toggles Fit/100% correctly
- [ ] Pan is constrained to image bounds
- [ ] Zoom levels include 50%, 100%, 200%
- [ ] Zoom percentage indicator shows current level

### Crop
- [ ] Pressing C enters crop mode with toolbar
- [ ] Aspect ratio picker locks ratio correctly
- [ ] Grid overlays render (thirds, golden ratio, etc.)
- [ ] Dragging inside frame moves image (Lightroom-style)
- [ ] Straighten slider rotates image with preview
- [ ] Enter confirms, Esc cancels
- [ ] Crop saves correctly to sidecar
- [ ] GridView thumbnails show cropped preview
- [ ] Real-time preview of crop during editing

---

## Next Steps

1. Review this design with user for approval
2. Implement Phase 1 (Zoom) - ~8 hours
3. Implement Phase 2 (Crop) - ~14 hours
4. Testing and polish - ~4 hours

**Total estimated effort**: ~26 hours
