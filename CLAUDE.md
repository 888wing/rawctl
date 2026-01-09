# rawctl Development Guide

## Project Overview

**rawctl** is a native macOS RAW photo editor built with SwiftUI and Core Image.

**Mission**: Photo freedom without subscription fees.

**Core Philosophy**:
- Open Source - All essential editing features are free forever
- Folder-Based - No proprietary catalog, your files stay where they are
- Non-Destructive - Edits stored in sidecar JSON, originals never touched
- Local First - No cloud, no sync, no accounts required

## Current Version

**v1.2** - Color Foundation
- 4-stage color pipeline: RAW Decode → Camera Profile → User Adjustments → Display Transform
- 3 built-in camera profiles (Neutral, Vivid, Portrait)
- Filmic tone curves with highlight shoulder
- Bug fixes: Crop button, GridView animations, sort order

## Architecture

```
rawctl/rawctl/
├── Components/           # Reusable UI components
│   ├── CropOverlayView.swift
│   ├── ProfilePicker.swift
│   ├── ResizePanel.swift
│   ├── StateViews/       # Empty, Error, Network states
│   └── ToastHUD.swift
├── Models/               # Data models
│   ├── AppState.swift    # Global state (@MainActor)
│   ├── CameraProfile.swift
│   ├── Catalog.swift     # Photo library
│   ├── ColorMatrix.swift
│   ├── ColorPipelineConfig.swift
│   ├── EditRecipe.swift  # Non-destructive edits
│   ├── PhotoAsset.swift
│   └── ReleaseNotes.swift
├── Services/             # Business logic (actors)
│   ├── AccountService.swift
│   ├── CatalogService.swift
│   ├── ExportService.swift
│   ├── ImagePipeline.swift  # Core Image rendering
│   └── SidecarService.swift
├── Views/                # SwiftUI views
│   ├── MainLayoutView.swift
│   ├── GridView.swift
│   ├── SingleView.swift
│   ├── InspectorView.swift
│   └── ExportDialog.swift
└── rawctlApp.swift       # App entry point
```

## Development Rules

### CRITICAL: CHANGELOG Update Rule

**Every time you complete work from a development plan (`docs/plans/*.md`), you MUST update the CHANGELOG:**

1. After completing any task from a plan document, update `CHANGELOG.md`
2. Add changes under the current version section (e.g., `## [1.2.0]`)
3. Categorize changes:
   - `### Added` - New features
   - `### Changed` - Changes to existing features
   - `### Fixed` - Bug fixes
   - `### Removed` - Removed features
   - `### Technical` - Internal/API changes
4. Use descriptive bullet points with file/component names
5. Commit CHANGELOG updates with the feature commits

**Example workflow:**
```
1. Read plan: docs/plans/2026-01-08-image-pipeline-v1.2-design.md
2. Implement features from the plan
3. Update CHANGELOG.md with what was implemented
4. Commit: "feat(v1.2): implement color pipeline + update CHANGELOG"
```

### Code Style

- **SwiftUI** for all views
- **`actor`** for thread-safe services
- **`@MainActor`** for UI state
- **`async/await`** over callbacks
- Follow existing patterns in codebase

### Sidecar Format

Edits stored in `{filename}.rawctl.json` (schema v5):
```json
{
  "schemaVersion": 5,
  "asset": { "originalFilename": "DSC00001.ARW" },
  "edit": {
    "exposure": 0.5,
    "cameraProfile": "rawctl-vivid",
    "crop": { "rect": {...}, "aspectRatio": "3:2" },
    "resize": { "mode": "longEdge", "value": 2400 }
  }
}
```

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `←` `→` | Previous / Next photo |
| `Space` | Toggle Grid / Single view |
| `1-5` | Set rating |
| `P/X/U` | Pick / Reject / Unflag |
| `C` | Toggle transform mode |
| `Enter` | Commit transform |
| `Esc` | Cancel transform |
| `⌘E` | Export |

## Development Plans

Plans are stored in `docs/plans/` with naming convention: `YYYY-MM-DD-feature-name.md`

**Active plans:**
- `2026-01-08-image-pipeline-v1.2-design.md` - Color pipeline architecture
- `2026-01-08-image-pipeline-v1.2-phase1.md` - Phase 1 implementation
- `2026-01-09-project-workflow-design.md` - Multi-directory support

**Completed plans:**
- `2026-01-08-crop-rotate-resize-design.md` - Transform tools
- `2026-01-08-security-hardening-design.md` - Account security
- `2026-01-06-bug-fixes-complete.md` - v1.1 bug fixes

## Release Process

Use the `/rawctl-release` skill for releases:
1. Update version in Xcode
2. Update CHANGELOG.md and README.md
3. Update ReleaseNotes.swift
4. Build, sign, notarize DMG
5. Upload to R2 and create GitHub release
6. Update landing page

## Key Files

| File | Purpose |
|------|---------|
| `CHANGELOG.md` | Version history (Keep a Changelog format) |
| `README.md` | Project overview with "What's New" section |
| `rawctl/Models/ReleaseNotes.swift` | In-app release notes |
| `docs/plans/*.md` | Development planning documents |

## Testing

```bash
# Run tests
xcodebuild test -scheme rawctl -destination 'platform=macOS'

# Specific test
xcodebuild test -scheme rawctl -only-testing:rawctlTests/CameraProfileTests
```

## Quick Commands

```bash
# Build release
xcodebuild -scheme rawctl -configuration Release build

# Open project
open rawctl.xcodeproj

# Check git status
git status && git log --oneline -5
```
