# Responsive Design Optimization Plan

**Version**: 1.0
**Date**: 2026-01-11
**Status**: Approved

## Overview

This document defines the responsive design strategy for rawctl, optimizing the UI for different screen sizes from 13" MacBook Air to 27"+ external displays.

**Approach**: Hybrid System (Approach C) - Major layout changes use breakpoints, element sizing uses fluid scaling.

## Breakpoint System

| Breakpoint | Width | Name | Typical Device |
|------------|-------|------|----------------|
| XS | < 900px | Compact | Split window, small windows |
| S | 900-1200px | Standard | 13" MacBook Air |
| M | 1200-1600px | Spacious | 14-16" MacBook Pro |
| L | > 1600px | Extended | 27" iMac, external displays |

### Layout Changes per Breakpoint

**XS (< 900px)**
- Sidebar: Auto-hidden
- Inspector: Auto-hidden (expandable as overlay)
- Workspace: Full width only

**S (900-1200px)**
- Sidebar: Visible
- Inspector: Hidden by default, manually expandable
- Thumbnails: 3-4 columns

**M (1200-1600px)**
- Full 3-column layout
- Inspector: Visible by default
- Thumbnails: 4-6 columns

**L (> 1600px)**
- Full 3-column, Inspector can be widened
- Thumbnails: 6-8 columns, larger size
- Optional: Dual-column Inspector (basic + advanced)

## Inspector Collapsible Mechanism

### Trigger Methods

1. **Button**: Collapse button in Inspector header (chevron icon)
2. **Keyboard**: `⌘⌥I` (consistent with existing Toggle Inspector)
3. **Gesture**:
   - Swipe left from right edge: Expand Inspector
   - Swipe right on Inspector: Collapse
4. **Automatic**:
   - Window < 900px: Auto-hide
   - Window > 1200px: Auto-restore (if previously visible)

### Expansion Modes

| Breakpoint | Mode | Description |
|------------|------|-------------|
| XS/S | **Overlay** | Inspector floats over Workspace with semi-transparent background |
| M/L | **Inline** | Inspector occupies fixed space, Workspace width reduces |

### Animation Specifications

```swift
// Inspector expand/collapse
.animation(.spring(response: 0.3, dampingFraction: 0.8), value: showInspector)

// Overlay background fade
.animation(.easeInOut(duration: 0.2), value: showInspector)
```

### State Memory

- Remember user preference per breakpoint
- Example: Manually hide Inspector at M, resize to S then back to M → stays hidden

## Grid View Adaptive Thumbnails

### Thumbnail Size Calculation

```swift
// Calculation logic
let availableWidth = workspaceWidth - padding
let minThumbnailSize: CGFloat = 120
let maxThumbnailSize: CGFloat = 200
let spacing: CGFloat = 8

// Calculate optimal columns (fill available space)
let columns = max(3, Int(availableWidth / (minThumbnailSize + spacing)))
let thumbnailSize = (availableWidth - CGFloat(columns - 1) * spacing) / CGFloat(columns)
let clampedSize = min(max(thumbnailSize, minThumbnailSize), maxThumbnailSize)
```

### Thumbnail Behavior per Breakpoint

| Breakpoint | Columns | Size | Special Handling |
|------------|---------|------|------------------|
| XS | 2-3 | 120-140px | Simplified metadata |
| S | 3-4 | 130-150px | Standard metadata |
| M | 4-6 | 140-170px | Full metadata + hover preview |
| L | 6-8 | 160-200px | Large size + rating/flag badges |

### Transition Behavior (Immediate)

```swift
// Thumbnail size: No animation, immediate response
LazyVGrid(columns: columns, spacing: spacing) {
    ForEach(assets) { asset in
        ThumbnailView(asset: asset, size: clampedSize)
    }
}
// No .animation() - resize reflects immediately
```

### Smart Prefetching

- Visible area + 2 rows above/below
- Large screens: Increase prefetch range (avoid white flash on fast scroll)

## Single View Adaptation

### Image Display Area

**Core Principle**: Maximize image viewing area, smart toolbar hiding

| Breakpoint | Image Area | Toolbar Position |
|------------|------------|------------------|
| XS | Full width (no Inspector) | Bottom floating, auto-hide after 3s |
| S | Full or -260px (if Inspector open) | Bottom fixed |
| M/L | Minus Inspector width | Bottom fixed + side quick panel |

### Zoom Behavior

```swift
// Fit to View (default)
let fitScale = min(
    availableWidth / imageWidth,
    availableHeight / imageHeight
)

// Large screen optimization: Allow 100% zoom without overflow
let canShow100Percent = imageWidth <= availableWidth && imageHeight <= availableHeight
```

### Navigation Bar Adaptation

| Breakpoint | Content |
|------------|---------|
| XS | Arrows + filename (truncated) only |
| S | Arrows + filename + rating |
| M | Arrows + filename + rating + flag + zoom controls |
| L | Full nav bar + histogram thumbnail |

### Gesture Support

- **Pinch zoom**: All breakpoints
- **Double-tap**: Toggle Fit/100%
- **Swipe**: Left/right to switch photos
- **Long press**: Quick preview (XS/S only, replaces hover)

## Implementation Phases

### Phase 1: Core Breakpoint System (Priority: High)
1. Create `ResponsiveLayout` environment object for unified breakpoint state
2. Refactor `MainLayoutView` with new breakpoint logic
3. Inspector collapsible mechanism (button + keyboard shortcut)

### Phase 2: Grid View Optimization
1. Adaptive thumbnail calculation logic
2. `LazyVGrid` dynamic column adjustment
3. Thumbnail metadata simplified/full display per breakpoint

### Phase 3: Single View Optimization
1. Toolbar auto-hide (XS breakpoint)
2. Navigation bar content per breakpoint
3. Enhanced gesture support

### Phase 4: Advanced Features
1. Inspector overlay mode (XS/S)
2. State memory (UserDefaults)
3. External display switch detection and adaptation

## Summary

| Element | Small Screen Strategy | Large Screen Strategy |
|---------|----------------------|----------------------|
| Inspector | Overlay + collapsible | Inline + expandable |
| Thumbnails | 2-4 columns, 120-150px | 6-8 columns, 160-200px |
| Toolbar | Auto-hide | Fixed + extended features |
| Transitions | Thumbnails immediate, panels animated | Same |

## Technical Notes

### Files to Modify

1. **MainLayoutView.swift** - Core breakpoint logic and layout structure
2. **GridView.swift** - Adaptive thumbnail grid
3. **SingleView.swift** - Photo viewer adaptation
4. **InspectorView.swift** - Collapsible mechanism and overlay mode
5. **New: ResponsiveLayout.swift** - Environment object for breakpoint state

### SwiftUI Considerations

- Use `GeometryReader` for breakpoint detection
- `@Environment` for passing layout state down the view hierarchy
- `NavigationSplitViewColumnWidth` for panel sizing
- `matchedGeometryEffect` for smooth transitions if needed
