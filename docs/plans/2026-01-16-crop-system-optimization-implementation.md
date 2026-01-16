# Crop System Optimization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Optimize crop system with draw-new-area, instant aspect ratio, and improved right panel entry.

**Architecture:** Add background drag gesture layer for drawing new crop areas, onChange listener for instant aspect ratio application, and CropPreviewThumbnail component for right panel quick entry.

**Tech Stack:** SwiftUI, Core Image, macOS native

---

## Task 1: Add Background Drag State Properties

**Files:**
- Modify: `rawctl/Components/CropOverlayView.swift:16-21`

**Step 1: Add new state properties for background drag**

Add these properties after line 21 (after `localRect` declaration):

```swift
/// Background drag state (for drawing new crop area)
@State private var isDrawingNewRect = false
@State private var drawStartPoint: CGPoint = .zero
```

**Step 2: Verify the build compiles**

Run: `xcodebuild -scheme rawctl -configuration Debug build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add rawctl/Components/CropOverlayView.swift
git commit -m "$(cat <<'EOF'
feat(crop): add background drag state properties

Preparation for drawing new crop area feature.
Adds isDrawingNewRect and drawStartPoint state variables.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Implement handleBackgroundDrag Function

**Files:**
- Modify: `rawctl/Components/CropOverlayView.swift` (add new function after `commitCenterDrag()` ~line 292)

**Step 1: Add handleBackgroundDrag function**

Add this function after `commitCenterDrag()`:

```swift
// MARK: - Background Drag (Draw New Crop Area)

/// Handle background drag - draw a new crop area from scratch
private func handleBackgroundDrag(value: DragGesture.Value, viewSize: CGSize) {
    if !isDrawingNewRect {
        // Start drawing new crop area
        isDrawingNewRect = true
        drawStartPoint = CGPoint(
            x: value.startLocation.x / viewSize.width,
            y: value.startLocation.y / viewSize.height
        )
        // Initialize local rect
        localRect = CropRect(
            x: drawStartPoint.x,
            y: drawStartPoint.y,
            w: 0,
            h: 0
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
        newRect = constrainNewRectToAspect(newRect, ratio: ratio, anchorPoint: drawStartPoint)
    }

    // Clamp to bounds
    newRect.x = max(0, min(1 - newRect.w, newRect.x))
    newRect.y = max(0, min(1 - newRect.h, newRect.y))
    newRect.w = min(newRect.w, 1 - newRect.x)
    newRect.h = min(newRect.h, 1 - newRect.y)

    localRect = newRect
}

/// Constrain a new rect to aspect ratio while keeping anchor point
private func constrainNewRectToAspect(_ rect: CropRect, ratio: Double, anchorPoint: CGPoint) -> CropRect {
    let imageAspect = imageSize.width / imageSize.height
    let normalizedAspect = ratio / imageAspect

    var newRect = rect

    // Determine which dimension to adjust based on current rect shape
    let currentAspect = rect.w / max(rect.h, 0.001) * imageAspect

    if currentAspect > ratio {
        // Too wide - adjust width
        newRect.w = rect.h * normalizedAspect
    } else {
        // Too tall - adjust height
        newRect.h = rect.w / normalizedAspect
    }

    // Recalculate position based on anchor point
    if anchorPoint.x < rect.x + rect.w / 2 {
        // Anchor is on left side
        newRect.x = rect.x
    } else {
        // Anchor is on right side - adjust x to keep right edge
        newRect.x = rect.x + rect.w - newRect.w
    }

    if anchorPoint.y < rect.y + rect.h / 2 {
        // Anchor is on top side
        newRect.y = rect.y
    } else {
        // Anchor is on bottom side - adjust y to keep bottom edge
        newRect.y = rect.y + rect.h - newRect.h
    }

    return newRect
}
```

**Step 2: Verify the build compiles**

Run: `xcodebuild -scheme rawctl -configuration Debug build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add rawctl/Components/CropOverlayView.swift
git commit -m "$(cat <<'EOF'
feat(crop): implement handleBackgroundDrag function

Adds logic for drawing new crop areas from scratch.
Supports aspect ratio constraints during drawing.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Implement commitBackgroundDrag Function

**Files:**
- Modify: `rawctl/Components/CropOverlayView.swift` (add after handleBackgroundDrag)

**Step 1: Add commitBackgroundDrag function**

```swift
/// Commit background drag - finalize the new crop area
private func commitBackgroundDrag() {
    guard let finalRect = localRect, isDrawingNewRect else { return }

    // Only commit if rect has meaningful size (avoid accidental clicks)
    // Minimum 2% of image in each dimension
    if finalRect.w > 0.02 && finalRect.h > 0.02 {
        crop.rect = finalRect
        crop.isEnabled = true
    }

    // Clear state
    isDrawingNewRect = false
    localRect = nil
    drawStartPoint = .zero
}
```

**Step 2: Verify the build compiles**

Run: `xcodebuild -scheme rawctl -configuration Debug build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add rawctl/Components/CropOverlayView.swift
git commit -m "$(cat <<'EOF'
feat(crop): implement commitBackgroundDrag function

Finalizes new crop area with minimum size threshold (2%).
Prevents accidental clicks from creating tiny crop areas.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Add Background Drag Gesture Layer

**Files:**
- Modify: `rawctl/Components/CropOverlayView.swift:58-68` (in ZStack body)

**Step 1: Replace the dimmed overlay with gesture-enabled version**

Find the current dimmed overlay code (~line 58-68):
```swift
// Dimmed overlay for non-cropped areas
Path { path in
    path.addRect(CGRect(origin: .zero, size: viewSize))
}
.fill(Color.black.opacity(0.5))
.reverseMask {
    Rectangle()
        .frame(width: cropRect.width, height: cropRect.height)
        .position(x: cropRect.midX, y: cropRect.midY)
}
```

Replace with:
```swift
// Dimmed overlay for non-cropped areas - with background drag gesture
Path { path in
    path.addRect(CGRect(origin: .zero, size: viewSize))
}
.fill(Color.black.opacity(0.5))
.reverseMask {
    Rectangle()
        .frame(width: cropRect.width, height: cropRect.height)
        .position(x: cropRect.midX, y: cropRect.midY)
}
.contentShape(Rectangle())
.gesture(
    DragGesture(minimumDistance: 5)
        .onChanged { value in
            handleBackgroundDrag(value: value, viewSize: viewSize)
        }
        .onEnded { _ in
            commitBackgroundDrag()
        }
)
```

**Step 2: Verify the build compiles**

Run: `xcodebuild -scheme rawctl -configuration Debug build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 3: Manual Test**

1. Open rawctl app
2. Select a photo and enter crop mode (press C)
3. Drag on the dark area outside the crop frame
4. Verify: A new crop rectangle is drawn from the start point to current position
5. Release drag - verify the new crop area is committed

**Step 4: Commit**

```bash
git add rawctl/Components/CropOverlayView.swift
git commit -m "$(cat <<'EOF'
feat(crop): add background drag gesture for new crop area

Users can now draw a completely new crop area by dragging
on the dark region outside the existing crop frame.

Gesture priority: corner handles > center drag > background drag

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Implement Instant Aspect Ratio Application

**Files:**
- Modify: `rawctl/Components/CropOverlayView.swift` (add onChange modifier and applyAspectRatio function)

**Step 1: Add applyAspectRatio function**

Add this function after the grid overlay drawing functions (after `drawGoldenSpiral`):

```swift
// MARK: - Aspect Ratio Application

/// Apply aspect ratio immediately when changed
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

    // Ensure minimum size
    newW = max(0.1, newW)
    newH = max(0.1, newH)

    // Center the new rect
    let newX = max(0, min(1 - newW, currentCenter.x - newW / 2))
    let newY = max(0, min(1 - newH, currentCenter.y - newH / 2))

    crop.rect = CropRect(x: newX, y: newY, w: newW, h: newH)

    // Auto-enable crop when aspect is changed from default
    if !crop.isEnabled && aspect != .free {
        crop.isEnabled = true
    }
}
```

**Step 2: Add onChange modifier to the body**

Find the closing of the GeometryReader (around line 130-131) and add the onChange modifier:

After the GeometryReader closing brace, add:
```swift
.onChange(of: crop.aspect) { oldAspect, newAspect in
    withAnimation(.easeInOut(duration: 0.2)) {
        applyAspectRatio(newAspect)
    }
}
```

**Step 3: Verify the build compiles**

Run: `xcodebuild -scheme rawctl -configuration Debug build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 4: Manual Test**

1. Open rawctl and select a photo
2. Enter crop mode (press C)
3. From the aspect ratio picker, select "1:1"
4. Verify: The crop frame immediately adjusts to a square shape
5. Select "16:9" - verify immediate adjustment
6. Select "Free" - verify no change (free resize)

**Step 5: Commit**

```bash
git add rawctl/Components/CropOverlayView.swift
git commit -m "$(cat <<'EOF'
feat(crop): instant aspect ratio application

Crop frame now immediately adjusts when aspect ratio is changed.
Uses smooth 0.2s animation for visual feedback.
Maintains crop center position and similar area.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Create CropPreviewThumbnail Component

**Files:**
- Create: `rawctl/Components/CropPreviewThumbnail.swift`

**Step 1: Create the new component file**

```swift
//
//  CropPreviewThumbnail.swift
//  rawctl
//
//  Preview thumbnail for crop area in the right panel
//

import SwiftUI

/// Crop preview thumbnail with visual overlay
struct CropPreviewThumbnail: View {
    @Binding var crop: Crop
    let previewImage: NSImage?
    let onTap: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.3))

                if let image = previewImage {
                    // Scaled-down preview image
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .overlay {
                            // Crop frame overlay (simplified)
                            if crop.isEnabled {
                                CropRectOverlay(rect: crop.rect)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(4)
                } else {
                    // No image placeholder
                    VStack(spacing: 4) {
                        Image(systemName: "photo")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No photo")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // Tap hint when no crop
                if !crop.isEnabled && previewImage != nil {
                    VStack(spacing: 4) {
                        Image(systemName: "crop")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                        Text("Click to crop")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(6)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
        }
        .frame(height: 80)
    }
}

/// Simple crop rect overlay for thumbnail
private struct CropRectOverlay: View {
    let rect: CropRect

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dimmed outside area
                Color.black.opacity(0.4)
                    .mask {
                        Rectangle()
                            .overlay {
                                Rectangle()
                                    .frame(
                                        width: geo.size.width * rect.w,
                                        height: geo.size.height * rect.h
                                    )
                                    .position(
                                        x: geo.size.width * (rect.x + rect.w / 2),
                                        y: geo.size.height * (rect.y + rect.h / 2)
                                    )
                                    .blendMode(.destinationOut)
                            }
                    }

                // White border around crop area
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
}

#Preview("With Crop") {
    CropPreviewThumbnail(
        crop: .constant(Crop(isEnabled: true, rect: CropRect(x: 0.1, y: 0.2, w: 0.6, h: 0.5))),
        previewImage: nil,
        onTap: {}
    )
    .frame(width: 280)
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("No Crop") {
    CropPreviewThumbnail(
        crop: .constant(Crop()),
        previewImage: nil,
        onTap: {}
    )
    .frame(width: 280)
    .padding()
    .preferredColorScheme(.dark)
}
```

**Step 2: Verify the build compiles**

Run: `xcodebuild -scheme rawctl -configuration Debug build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add rawctl/Components/CropPreviewThumbnail.swift
git commit -m "$(cat <<'EOF'
feat(crop): create CropPreviewThumbnail component

New component for right panel showing:
- Scaled preview image with crop overlay
- Click to enter transform mode
- Visual hint when no crop is active

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Integrate CropPreviewThumbnail into InspectorView

**Files:**
- Modify: `rawctl/Views/InspectorView.swift:307-393` (Composition section)

**Step 1: Refactor the Composition DisclosureGroup**

Find the Composition section (around line 307-393) and replace its content:

```swift
// Composition section - Crop, Rotate, Flip
if panelConfig.isVisible(.composition) {
DisclosureGroup("Composition", isExpanded: $compositionExpanded) {
    VStack(spacing: 12) {
        // Crop preview thumbnail
        CropPreviewThumbnail(
            crop: $localRecipe.crop,
            previewImage: appState.currentPreviewImage,
            onTap: {
                // Save history before entering transform mode
                pushHistory()
                appState.transformMode = true
            }
        )

        // Edit Crop button
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

        // Crop toggle and aspect ratio
        HStack {
            Toggle("Crop", isOn: $localRecipe.crop.isEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)

            Spacer()

            if localRecipe.crop.isEnabled {
                Picker("Aspect", selection: $localRecipe.crop.aspect) {
                    ForEach(Crop.Aspect.allCases) { aspect in
                        Text(aspect.displayName).tag(aspect)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.small)
            }
        }

        // Straighten slider (-45° to +45°)
        ControlSlider(
            label: "Straighten",
            value: $localRecipe.crop.straightenAngle,
            range: -45...45,
            format: "%.1f°",
            onDragStart: { pushHistory() }
        )

        // Rotation and Flip buttons
        HStack(spacing: 8) {
            // 90° rotation buttons
            HStack(spacing: 4) {
                Button {
                    pushHistory()
                    localRecipe.crop.rotationDegrees = (localRecipe.crop.rotationDegrees - 90 + 360) % 360
                } label: {
                    Image(systemName: "rotate.left")
                }
                .help("Rotate 90° left")

                Button {
                    pushHistory()
                    localRecipe.crop.rotationDegrees = (localRecipe.crop.rotationDegrees + 90) % 360
                } label: {
                    Image(systemName: "rotate.right")
                }
                .help("Rotate 90° right")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()

            // Flip buttons
            HStack(spacing: 4) {
                Button {
                    pushHistory()
                    localRecipe.crop.flipHorizontal.toggle()
                } label: {
                    Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                }
                .help("Flip horizontal")
                .background(localRecipe.crop.flipHorizontal ? Color.accentColor.opacity(0.3) : Color.clear)
                .cornerRadius(4)

                Button {
                    pushHistory()
                    localRecipe.crop.flipVertical.toggle()
                } label: {
                    Image(systemName: "arrow.up.and.down.righttriangle.up.righttriangle.down")
                }
                .help("Flip vertical")
                .background(localRecipe.crop.flipVertical ? Color.accentColor.opacity(0.3) : Color.clear)
                .cornerRadius(4)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
    .padding(.top, 6)
}
.contextMenu { panelContextMenu(.composition) }
}
```

**Step 2: Verify the build compiles**

Run: `xcodebuild -scheme rawctl -configuration Debug build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 3: Manual Test**

1. Open rawctl and select a photo
2. In the right panel, find the Composition section
3. Verify: CropPreviewThumbnail shows the preview with crop overlay
4. Click the thumbnail - verify it enters transform mode
5. Click "Edit Crop" button - verify it enters transform mode
6. Verify: History is saved (can undo the transform mode entry)

**Step 4: Commit**

```bash
git add rawctl/Views/InspectorView.swift
git commit -m "$(cat <<'EOF'
feat(crop): integrate CropPreviewThumbnail in right panel

Composition section now includes:
- Preview thumbnail with crop overlay visualization
- "Edit Crop" button for quick entry to transform mode
- Both entry points save history for undo support

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Update CHANGELOG and Final Verification

**Files:**
- Modify: `CHANGELOG.md`

**Step 1: Update CHANGELOG**

Add under the current version section:

```markdown
### Added
- **Crop System Optimization**
  - Draw new crop area by dragging on dark region outside existing frame
  - Instant aspect ratio application when selecting new ratio
  - CropPreviewThumbnail component in right panel Composition section
  - "Edit Crop" button for quick entry to transform mode
```

**Step 2: Final Build Verification**

Run: `xcodebuild -scheme rawctl -configuration Debug build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 3: Commit all changes**

```bash
git add CHANGELOG.md
git commit -m "$(cat <<'EOF'
docs: update CHANGELOG for crop system optimization

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

**Step 4: Play completion sound**

```bash
afplay /System/Library/Sounds/Glass.aiff
```

---

## Testing Checklist

### Phase 1: Draw New Crop Area
- [ ] Drag on dark region creates new crop area
- [ ] Aspect lock maintained during draw (when aspect is not Free)
- [ ] Minimum size threshold (2%) prevents accidental clicks
- [ ] Boundary constraints work correctly (can't draw outside image)
- [ ] Existing corner/center drag gestures still work

### Phase 2: Instant Aspect Ratio
- [ ] Free aspect → no change
- [ ] Original aspect → applies image's original ratio
- [ ] Fixed aspects (1:1, 4:3, 16:9, etc.) → immediate adjustment
- [ ] Animation smooth and visible (0.2s)
- [ ] Crop center maintained after aspect change

### Phase 3: Right Panel Entry
- [ ] Thumbnail shows current preview image
- [ ] Crop frame overlay visible when crop is enabled
- [ ] Click thumbnail → enters transform mode
- [ ] "Edit Crop" button → enters transform mode
- [ ] History saved before entering transform mode (undo works)

---

## Files Modified Summary

| File | Changes |
|------|---------|
| `rawctl/Components/CropOverlayView.swift` | Background drag + aspect onChange |
| `rawctl/Components/CropPreviewThumbnail.swift` | New component |
| `rawctl/Views/InspectorView.swift` | Refactored Composition panel |
| `CHANGELOG.md` | Updated with new features |
