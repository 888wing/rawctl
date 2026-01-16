# Crop System Optimization Design

## Overview

Optimize the crop system for better UX and control, focusing on three key improvements:
1. Draw new crop area from scratch (框選新區域)
2. Instant aspect ratio application (Aspect 即時套用)
3. Improved right-side panel entry (右側面板入口)

## Problem Summary

| Issue | Severity | Current State |
|-------|----------|---------------|
| Cannot draw new crop area | **CRITICAL** | Only corner resize and center move available |
| Aspect ratio no instant preview | **HIGH** | Frame doesn't adjust until next corner drag |
| Right panel is weak | **MEDIUM** | Only toggle and picker, no preview or quick entry |

## Scope

### In Scope
- Background drag gesture for drawing new crop area
- Aspect ratio onChange listener with instant application
- Composition panel redesign with preview thumbnail

### Out of Scope (YAGNI)
- Auto-straighten
- Crop presets
- Aspect flip (3:2 ↔ 2:3)

---

## Phase 1: Draw New Crop Area (Priority 1)

### Current Behavior
- Corner handles: Resize existing crop frame
- Center drag: Move crop frame position (Lightroom style)

### Missing Feature
Cannot drag on dark area (outside crop frame) to draw a completely new crop region.

### Solution

Add a background drag gesture layer that creates new crop area when dragging on the dark area:

```swift
// CropOverlayView.swift

/// Background drag state (for drawing new crop area)
@State private var isDrawingNewRect = false
@State private var drawStartPoint: CGPoint = .zero

// Background layer with drag gesture
Rectangle()
    .fill(Color.black.opacity(0.6))  // Dark area
    .gesture(
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                handleBackgroundDrag(value: value, viewSize: viewSize)
            }
            .onEnded { _ in
                commitBackgroundDrag()
            }
    )

private func handleBackgroundDrag(value: DragGesture.Value, viewSize: CGSize) {
    if !isDrawingNewRect {
        // Start drawing new crop area
        isDrawingNewRect = true
        drawStartPoint = CGPoint(
            x: value.startLocation.x / viewSize.width,
            y: value.startLocation.y / viewSize.height
        )
    }

    // Calculate new rect from start point to current location
    let currentPoint = CGPoint(
        x: value.location.x / viewSize.width,
        y: value.location.y / viewSize.height
    )

    var newRect = CropRect(
        x: min(drawStartPoint.x, currentPoint.x),
        y: min(drawStartPoint.y, currentPoint.y),
        w: abs(currentPoint.x - drawStartPoint.x),
        h: abs(currentPoint.y - drawStartPoint.y)
    )

    // Apply aspect ratio constraint if locked
    if let ratio = targetAspect {
        newRect = constrainToAspect(newRect, ratio: ratio)
    }

    // Clamp to bounds
    newRect.x = max(0, min(1 - newRect.w, newRect.x))
    newRect.y = max(0, min(1 - newRect.h, newRect.y))

    localRect = newRect
}

private func commitBackgroundDrag() {
    guard let finalRect = localRect, isDrawingNewRect else { return }

    // Only commit if rect has meaningful size (avoid accidental clicks)
    if finalRect.w > 0.02 && finalRect.h > 0.02 {
        crop.rect = finalRect
        crop.isEnabled = true
    }

    isDrawingNewRect = false
    localRect = nil
    drawStartPoint = .zero
}
```

### Gesture Priority

| Gesture Location | Behavior | Priority |
|------------------|----------|----------|
| Corner handles | Resize | Highest |
| Inside crop frame | Move position | High |
| Dark area (outside) | Draw new | Medium |

---

## Phase 2: Instant Aspect Ratio Application (Priority 2)

### Current Behavior
- Select new aspect ratio (e.g., 16:9)
- Crop frame does NOT adjust immediately
- Only applies on next corner drag

### Solution

Add `onChange` listener in `CropOverlayView` to immediately apply aspect ratio:

```swift
// CropOverlayView.swift

var body: some View {
    GeometryReader { geometry in
        // ... existing content ...
    }
    .onChange(of: crop.aspect) { oldAspect, newAspect in
        withAnimation(.easeInOut(duration: 0.2)) {
            applyAspectRatio(newAspect)
        }
    }
}

private func applyAspectRatio(_ aspect: Crop.Aspect) {
    // Free aspect - no change needed
    guard let ratio = aspect.aspectRatio ?? (aspect == .original ? imageSize.width / imageSize.height : nil) else {
        return
    }

    // Calculate new rect centered on current crop
    let currentCenter = CGPoint(
        x: crop.rect.x + crop.rect.w / 2,
        y: crop.rect.y + crop.rect.h / 2
    )

    // Maintain similar area while applying new aspect ratio
    let currentArea = crop.rect.w * crop.rect.h

    // Calculate new dimensions
    // For normalized coordinates: w * imageAspect / h = targetAspect
    let imageAspect = imageSize.width / imageSize.height
    let normalizedRatio = ratio / imageAspect

    var newW = sqrt(currentArea * normalizedRatio)
    var newH = newW / normalizedRatio

    // Clamp to image bounds
    if newW > 1.0 {
        newW = 1.0
        newH = newW / normalizedRatio
    }
    if newH > 1.0 {
        newH = 1.0
        newW = newH * normalizedRatio
    }

    // Center the new rect
    let newX = max(0, min(1 - newW, currentCenter.x - newW / 2))
    let newY = max(0, min(1 - newH, currentCenter.y - newH / 2))

    crop.rect = CropRect(x: newX, y: newY, w: newW, h: newH)
}
```

### User Experience

| Select Aspect | Behavior |
|---------------|----------|
| Free | No change, free resize |
| Original | Immediately apply image's original ratio |
| 1:1, 4:3, 16:9... | Immediately adjust crop frame to selected ratio |

---

## Phase 3: Right Panel Entry (Priority 3)

### Current Behavior
InspectorView Composition panel only has:
- Crop toggle switch
- Aspect picker
- Straighten slider
- Rotation/Flip buttons

### Missing Features
- No crop preview thumbnail
- No quick entry to transform mode

### Solution

Add `CropPreviewThumbnail` component and "Edit Crop" button:

```swift
// Components/CropPreviewThumbnail.swift

struct CropPreviewThumbnail: View {
    @Binding var crop: Crop
    let previewImage: NSImage?
    let onTap: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Scaled-down preview image
                if let image = previewImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .overlay {
                            // Crop frame overlay (simplified)
                            if crop.isEnabled {
                                CropRectOverlay(rect: crop.rect)
                            }
                        }
                }

                // Tap hint when no crop
                if !crop.isEnabled {
                    VStack(spacing: 4) {
                        Image(systemName: "crop")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary.opacity(0.6))
                        Text("Click to crop")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
        }
        .background(Color.black.opacity(0.3))
        .cornerRadius(6)
    }
}

/// Simple crop rect overlay for thumbnail
private struct CropRectOverlay: View {
    let rect: CropRect

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .stroke(Color.white, lineWidth: 1)
                .frame(
                    width: geo.size.width * rect.w,
                    height: geo.size.height * rect.h
                )
                .position(
                    x: geo.size.width * (rect.x + rect.w / 2),
                    y: geo.size.height * (rect.y + rect.h / 2)
                )
        }
    }
}
```

### InspectorView Changes

```swift
// InspectorView.swift - Composition section

DisclosureGroup("Composition", isExpanded: $compositionExpanded) {
    VStack(spacing: 12) {
        // NEW: Crop preview thumbnail
        CropPreviewThumbnail(
            crop: $localRecipe.crop,
            previewImage: appState.currentPreviewImage,
            onTap: {
                // Save history before entering transform mode
                pushHistory()
                appState.transformMode = true
            }
        )
        .frame(height: 80)

        // NEW: Edit Crop button
        Button {
            pushHistory()
            appState.transformMode = true
        } label: {
            Label("Edit Crop", systemImage: "crop")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        Divider()

        // Existing controls...
        // Crop toggle, Aspect picker, Straighten slider, Rotation/Flip buttons
    }
    .padding(.top, 6)
}
```

### Panel Layout

```
┌─────────────────────────┐
│ ▼ Composition           │
├─────────────────────────┤
│ ┌─────────────────────┐ │
│ │   [Preview + Frame] │ │  ← Click to enter transform mode
│ │   Click to crop     │ │
│ └─────────────────────┘ │
│ [    Edit Crop    ]     │  ← Explicit entry button
├─────────────────────────┤
│ Aspect: [Free ▼]        │
│ Straighten: [====○===]  │
│ [↺] [↻]    [⇆] [⇅]      │
└─────────────────────────┘
```

---

## Files to Modify

| File | Changes | Complexity |
|------|---------|------------|
| `CropOverlayView.swift` | Add background drag + aspect onChange | **HIGH** |
| `CropToolbar.swift` | Aspect picker onChange integration | **LOW** |
| `InspectorView.swift` | Refactor Composition panel | **MEDIUM** |
| `Components/CropPreviewThumbnail.swift` | New component | **MEDIUM** |

---

## Implementation Phases

```
Phase 1: Draw New Crop Area (Priority 1)
├── Add background drag gesture layer
├── Implement handleBackgroundDrag()
├── Implement commitBackgroundDrag()
└── Test: aspect lock + boundary constraints

Phase 2: Instant Aspect Ratio (Priority 2)
├── Add onChange(of: crop.aspect) listener
├── Implement applyAspectRatio() algorithm
├── Add animation effect
└── Test: all ratios + edge cases

Phase 3: Right Panel Entry (Priority 3)
├── Create CropPreviewThumbnail component
├── Refactor InspectorView Composition section
├── Add "Edit Crop" button
└── Test: click to enter transform mode
```

---

## Expected Outcomes

| Feature | Before | After |
|---------|--------|-------|
| Draw new crop area | ❌ Not possible | ✅ Drag on dark area |
| Aspect instant apply | ❌ Requires drag | ✅ Immediate adjustment |
| Right panel | ⚠️ Weak controls | ✅ Preview + quick entry |

---

## Testing Checklist

### Phase 1 Tests
- [ ] Draw new crop area on dark region
- [ ] Aspect lock maintained during draw
- [ ] Minimum size threshold prevents accidental clicks
- [ ] Boundary constraints work correctly

### Phase 2 Tests
- [ ] Free aspect → no change
- [ ] Original aspect → applies image ratio
- [ ] Fixed aspects (1:1, 4:3, 16:9, etc.) → immediate adjustment
- [ ] Animation smooth and visible
- [ ] Edge cases: very wide/tall crops

### Phase 3 Tests
- [ ] Thumbnail shows current preview image
- [ ] Crop frame overlay visible when enabled
- [ ] Click thumbnail → enters transform mode
- [ ] "Edit Crop" button → enters transform mode
- [ ] History saved before entering transform mode
