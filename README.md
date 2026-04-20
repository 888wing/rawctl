# Latent

Latent is a native macOS RAW editor built with SwiftUI, Core Image, and Metal. It keeps your library folder-based, stores edits next to the original files, and adds optional AI workflows without forcing your photos into a cloud catalog.

> 你的照片，你的自由。不需要月費才能開始編修，也不需要把圖庫交給雲端。

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## What's New in 1.6.0

- **AI Cull** ranks bursts and duplicates by sharpness, saliency, and exposure.
- **AI Colour Grade** generates a complete starting look from scene analysis or a mood prompt.
- **Smart Sync** transfers an adapted grade to similar scenes across the library.
- **AI Mask** adds point-click subject masking powered by Mobile-SAM.
- **Performance hotfixes** make large SD cards open sooner and keep live colour adjustment much more responsive.

Full release history: [CHANGELOG.md](CHANGELOG.md)

## Feature Set

### Core Workflow

- **Local-first**: Open folders directly. No mandatory import step, no proprietary catalog lock-in.
- **Non-destructive**: Edits are stored in `.latent.json` sidecars next to the original image.
- **Legacy-safe**: Existing `.rawctl.json` sidecars are migrated automatically on first open.
- **Direct + MAS distribution**: The app supports both direct download and Mac App Store channels.

### Editing

- Exposure, contrast, highlights, shadows, whites, blacks
- Tone curve, white balance, vibrance, saturation, split toning
- Crop, straighten, rotate, flip, resize
- Ratings, flags, color labels, tags, smart filtering
- Local adjustments and AI masks

### AI Tools

- **AI Cull** for large shoots and burst selection
- **AI Colour Grade** for one-click starting looks
- **Smart Sync** for scene-aware grade transfer
- **AI Mask** for subject isolation

### Performance

- **Staged scan**: Large folders and memory cards become usable before the full scan finishes.
- **Interactive preview path**: Slider drags use a lighter preview pipeline for faster feedback.
- **Background throttling**: Prefetch and preload work yield while the user is actively editing.
- **Metal acceleration**: Core Image rendering stays GPU-backed throughout the main preview path.

## Pricing Model

- **Free**: Unlimited manual editing, local workflow, export, and organization tools.
- **Latent Pro**: Unlocks AI Cull, Smart Sync, AI Mask, and other Pro-gated AI workflows.
- **Credits**: One-off credit packs are available for AI usage without committing to a recurring plan.

## Supported Formats

**RAW**: ARW, CR2, CR3, NEF, ORF, RAF, RW2, DNG, 3FR, IIQ  
**Standard**: JPG, JPEG, PNG, HEIC, TIFF

## Install

### Download

- Latest direct build: [releases.latent-app.com/latent-latest.dmg](https://releases.latent-app.com/latent-latest.dmg)
- Releases: [github.com/888wing/latent/releases](https://github.com/888wing/latent/releases)

### Build from Source

```bash
git clone https://github.com/888wing/latent.git
cd latent
open rawctl.xcodeproj
```

Run the `latent-direct` scheme in Xcode.

## Sidecars

Latent writes non-destructive edits to `{filename}.latent.json`. Legacy `{filename}.rawctl.json` files are migrated automatically.

## Repository

- Changelog: [CHANGELOG.md](CHANGELOG.md)
- Release notes in-app: [rawctl/Models/ReleaseNotes.swift](rawctl/Models/ReleaseNotes.swift)
- GitHub: [github.com/888wing/latent](https://github.com/888wing/latent)

## License

MIT License. See [LICENSE](LICENSE).
