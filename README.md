# rawctl

A native macOS RAW photo editor built with SwiftUI and Core Image, featuring true RAW processing, non-destructive editing, and local-first AI tools.

**Mission: Photo freedom without subscription fees.**

> 你的照片，你的自由。不需要月費，不需要帳號，不需要雲端。
> Your photos, your freedom. No monthly fees, no accounts, no cloud required.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## ✨ Features

### Core Philosophy
- **Open Source** - All essential editing features are free forever
- **Folder-Based** - No proprietary catalog, your files stay where they are
- **Non-Destructive** - Edits stored in sidecar JSON, originals never touched
- **Local First** - No cloud, no sync, no accounts required
- **AI Powered** - Experimental AI features for creative editing (optional)

### 🤖 AI Lab (NanoBanana)
- **Generative Fill** - Remove objects or expand canvas using local AI models
- **AI Layers** - Non-destructive AI edits with layer masking and blending
- **Smart Selection** - Intelligent subject selection (Coming soon)
- **Local History** - Track and revert AI generation steps

### 🎨 Editing Controls

| Category | Controls |
|----------|----------|
| **Light** | Exposure (±5 EV), Contrast, Highlights, Shadows, Whites, Blacks |
| **Tone Curve** | RGB Curves + Luma Curve with 5-point visual editor |
| **Color** | HSL (Hue, Saturation, Luminance) Panel, Vibrance, Saturation |
| **White Balance** | Presets (Daylight, Cloudy, Tungsten, etc.), Temperature (2000-12000K), Tint |
| **Effects** | Vignette, Sharpness, Noise Reduction, Dehaze |
| **Split Toning** | Highlight/Shadow color grading |
| **Composition** | Crop with aspect ratios, Rotate, Flip |
| **Histogram** | Real-time RGB and Luma histogram |

### 🏷️ Organization

| Feature | Description |
|---------|-------------|
| **Rating** | 0-5 stars (keyboard: `1-5`, `0` to clear) |
| **Flags** | Pick / Reject / Unflag (keyboard: `P`, `X`, `U`) |
| **Color Labels** | 7 colors (keyboard: `6-9` for Red/Yellow/Green/Blue) |
| **Smart Collections** | Dynamic albums based on EXIF, rating, or tags |
| **Metadata** | View EXIF data (Camera, Lens, ISO, Aperture, Shutter) |

### ⚡ Performance

- **Two-Stage Loading** - Instant embedded JPEG preview, then full RAW decode
- **GPU Acceleration** - Metal-powered Core Image processing
- **Smart Caching** - RAW filter and thumbnail caching
- **Render Queue** - Background export processing

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
3. Adjust sliders in the right panel or use AI tools in the left panel
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
│   ├── SidebarView.swift     # Folder browser & Collections
│   ├── GridView.swift        # Thumbnail grid
│   ├── SingleView.swift      # Photo preview
│   └── InspectorView.swift   # Edit controls
├── Components/
│   ├── AIGenerationPanel.swift # AI Tool interface
│   ├── HistogramView.swift   # Real-time histogram
│   ├── ToneCurveView.swift   # Curve editor
│   └── HSLPanel.swift        # Color mixer
└── Services/
     ├── ImagePipeline.swift   # Core Image rendering
     ├── NanoBananaService.swift # AI Service integration
     └── ExportService.swift   # Export manaager
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
    "hsl": {
      "red": { "h": 0, "s": 0.1, "l": 0 },
      "blue": { "h": 0, "s": 0.2, "l": -0.1 }
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
| `⌘E` | Export |

## 🗺️ Roadmap

### ✅ Completed
- [x] RAW processing with CIRAWFilter
- [x] Non-destructive sidecar editing
- [x] Tone curve editor & HSL Panel
- [x] RGB Histogram
- [x] AI Generative Tools (NanoBanana)
- [x] Smart Collections
- [x] Rating, flags, color labels
- [x] GPU Acceleration
- [x] JPG/HEIC/TIFF Export

### 🔜 Planned
- [ ] Batch Processing
- [ ] Lens Correction Profiles
- [ ] Plugin System API
- [ ] Masking Brush
- [ ] Compare View (Before/After)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing`)
5. Open a Pull Request

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- Apple Core Image team for `CIRAWFilter`
- SwiftUI community for inspiration
