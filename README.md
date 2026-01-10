# rawctl

A native macOS RAW photo editor built with SwiftUI and Core Image, featuring true RAW processing with non-destructive editing.

**Mission: Photo freedom without subscription fees.**

> 你的照片，你的自由。不需要月費，不需要帳號，不需要雲端。
> Your photos, your freedom. No monthly fees, no accounts, no cloud required.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## 🆕 What's New (v1.2)

- **Camera Profiles**: 3 built-in profiles (Neutral, Vivid, Portrait) with 4-stage color pipeline
- **Filmic Tone Curves**: Natural highlight roll-off with soft clipping
- **Camera Brand Detection**: Photos grouped by manufacturer (Nikon, Canon, Sony, Fujifilm, etc.)
- **Default Sort**: Now sorts by Capture Date (newest first) instead of filename
- **Bug Fixes**: Crop button responsiveness, GridView animation glitches

Full changelog: [CHANGELOG.md](CHANGELOG.md)

## ✨ Features

### Core Philosophy
- **Open Source** - All essential editing features are free forever
- **Folder-Based** - No proprietary catalog, your files stay where they are
- **Non-Destructive** - Edits stored in sidecar JSON, originals never touched
- **Local First** - No cloud, no sync, no accounts required

### 🎨 Editing Controls

| Category | Controls |
|----------|----------|
| **Light** | Exposure (±5 EV), Contrast, Highlights, Shadows, Whites, Blacks |
| **Tone Curve** | 5-point curve with visual editor |
| **White Balance** | Presets (Daylight, Cloudy, Tungsten, etc.), Temperature (2000-12000K), Tint |
| **Color** | Vibrance, Saturation |
| **Effects** | Vignette, Sharpness, Noise Reduction |
| **Split Toning** | Highlight/Shadow color grading |
| **Composition** | Crop with aspect ratios, Straighten, Rotate 90°, Flip |
| **Resize** | Pixels, Percentage, Long/Short Edge, Presets (Instagram, 4K, etc.) |

### 🏷️ Organization

| Feature | Description |
|---------|-------------|
| **Rating** | 0-5 stars (keyboard: `1-5`, `0` to clear) |
| **Flags** | Pick / Reject / Unflag (keyboard: `P`, `X`, `U`) |
| **Color Labels** | 7 colors (keyboard: `6-9` for Red/Yellow/Green/Blue) |
| **Tags** | Custom text tags with search |
| **Filters** | Filter by rating, flag, color, or tag |

### ⚡ Performance

- **Two-Stage Loading** - Instant embedded JPEG preview, then full RAW decode
- **GPU Acceleration** - Metal-powered Core Image processing
- **Smart Caching** - RAW filter and thumbnail caching
- **Prefetch** - Adjacent photos loaded in background

### 📁 Supported Formats

**RAW**: ARW, CR2, CR3, NEF, ORF, RAF, RW2, DNG, 3FR, IIQ  
**Standard**: JPG, JPEG, PNG, HEIC, TIFF

## 🖥️ Screenshots

*(Coming soon)*

## 🚀 Quick Start

### Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0+ (for building)

### Installation

```bash
git clone https://github.com/yourname/rawctl.git
cd rawctl/rawctl
open rawctl.xcodeproj
# Press ⌘R to build and run
```

### First Steps

1. Click "Open Folder" or drag a folder to the sidebar
2. Browse photos in Grid view, double-click to edit
3. Adjust sliders in the right panel
4. Export with File → Export (⌘E)

## 📐 Architecture

```
rawctl/
├── Models/
│   ├── PhotoAsset.swift      # Photo file representation
│   ├── EditRecipe.swift      # Non-destructive edit parameters
│   └── AppState.swift        # Global state management
├── Views/
│   ├── MainLayoutView.swift  # 3-column NavigationSplitView
│   ├── SidebarView.swift     # Folder browser
│   ├── GridView.swift        # Thumbnail grid
│   ├── SingleView.swift      # Photo preview
│   └── InspectorView.swift   # Edit controls
├── Components/
│   ├── ControlSlider.swift   # Custom sliders
│   ├── ToneCurveView.swift   # Curve editor
│   ├── WhiteBalancePanel.swift # WB presets & sliders
│   └── FilterBar.swift       # Photo filtering
└── Services/
    ├── ImagePipeline.swift   # Core Image rendering
    ├── SidecarService.swift  # JSON persistence
    ├── ExportService.swift   # JPG export
    └── ThumbnailService.swift # Thumbnail cache
```

## 💾 Sidecar Format

Edits are stored in `{filename}.rawctl.json`:

```json
{
  "schemaVersion": 1,
  "asset": {
    "originalFilename": "DSC00001.ARW",
    "fileSize": 25165824
  },
  "edit": {
    "exposure": 0.5,
    "whiteBalance": {
      "preset": "daylight",
      "temperature": 5500,
      "tint": 0
    },
    "rating": 4,
    "colorLabel": "green",
    "tags": ["landscape", "sunset"]
  }
}
```

## ⌨️ Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `←` `→` | Previous / Next photo |
| `Space` | Toggle Grid / Single view |
| `1-5` | Set rating |
| `0` | Clear rating |
| `P` | Flag as Pick |
| `X` | Flag as Reject |
| `U` | Unflag |
| `6` | Red label |
| `7` | Yellow label |
| `8` | Green label |
| `9` | Blue label |
| `C` | Toggle transform/crop mode |
| `Enter` | Commit transform |
| `Esc` | Cancel transform |
| `⌘E` | Export |

## 🗺️ Roadmap

### ✅ Completed (v1.2)
- [x] RAW processing with CIRAWFilter
- [x] Non-destructive sidecar editing
- [x] Tone curve editor
- [x] White balance presets
- [x] Rating, flags, color labels
- [x] Filtering and search
- [x] Keyboard shortcuts
- [x] Two-stage loading optimization
- [x] JPG export with sRGB
- [x] Crop with aspect ratios & rule-of-thirds
- [x] Straighten, rotate 90°, flip controls
- [x] Resize with multiple modes & presets
- [x] Transform mode with keyboard shortcuts
- [x] Camera profiles (Neutral, Vivid, Portrait)
- [x] 4-stage color pipeline with filmic tone curves
- [x] Camera brand detection for filename sorting

### 🔜 Planned
- [ ] Before/After comparison
- [ ] HSL color adjustment
- [ ] Lens correction profiles
- [ ] Batch export with progress
- [ ] Undo/Redo support
- [ ] Plugin system

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing`)
5. Open a Pull Request

### Code Style

- SwiftUI for all views
- `actor` for thread-safe services
- `@MainActor` for UI state
- Prefer `async/await` over callbacks

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- Apple Core Image team for `CIRAWFilter`
- SwiftUI community for inspiration
