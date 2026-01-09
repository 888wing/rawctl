# Changelog

All notable changes to rawctl will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-01-09

### Added

#### Camera Profiles (Color Foundation v1.2)
- **4-stage color pipeline**: RAW Decode → Camera Profile → User Adjustments → Display Transform
- **3 built-in camera profiles**:
  - **rawctl Neutral**: Identity matrix with filmic neutral tone curve - faithful color reproduction
  - **rawctl Vivid**: Enhanced saturation/contrast with vivid tone curve - punchy colors
  - **rawctl Portrait**: Skin-optimized matrix with soft tone curve - flattering skin tones
- **ProfilePicker UI** in Light panel for quick profile switching
- **Filmic tone curves**: 6-point curves for natural highlight roll-off
- **Highlight shoulder**: Soft clipping to prevent blown highlights
- **Profile persistence**: Saved in sidecar JSON (schema v5)

#### Color Pipeline Technical
- `ColorPipelineConfig`: Display P3 working space, sRGB output, 16-bit processing
- `ColorMatrix3x3`: Camera→working space transform with SIMD acceleration
- `FilmicToneCurve`: Presets (filmicNeutral, filmicVivid, filmicSoft)
- `HighlightShoulder`: Knee, softness, whitePoint parameters
- `CameraProfile`: Profile container with color matrix + tone curve + look adjustments
- Filter caching for profile application (improved scrubbing performance)

### Fixed

#### SingleView
- **Crop button not responding**: Fixed disconnected state between `transformMode` and `crop.isEnabled` - crop overlay now correctly shows when clicking the Crop button

#### GridView
- **Infinite dropdown animation on section headers**: Disabled implicit SwiftUI animations on section headers using `.animation(nil)` and `.transaction` modifiers to prevent visual glitches when view updates

### Changed

#### Default Sort Order
- Changed default sort criteria from **Filename** to **Capture Date**
- Changed default sort order from **Ascending** to **Descending** (newest photos first)

#### Filename Sorting Enhancement
- Replaced first-letter grouping with **camera brand detection**
- Photos now grouped by camera manufacturer based on filename patterns:
  - DSC_, DSCN → **Nikon**
  - IMG_ → **Canon / iPhone**
  - _DSC → **Sony**
  - DSCF → **Fujifilm**
  - DJI_ → **DJI Drone**
  - GOPR → **GoPro**
  - SAM_ → **Samsung**
  - And more...
- Unrecognized patterns fall back to file extension grouping

---

## [1.1.0] - 2026-01-08

### Added

#### Security Hardening
- **Device ID tracking**: Persistent UUID stored in Keychain, sent with every API request via `X-Device-ID` header
- **Rate limit handling**: HTTP 429 responses parsed with `Retry-After` header support
- **Security block detection**: HTTP 403 responses with descriptive error messages
- **Token replay detection**: Automatic sign-out when `TOKEN_REPLAY_DETECTED` error received
- **New error types**: `AccountError.rateLimited(retryAfter:)`, `.securityBlock(reason:)`, `.tokenReplayDetected`
- **Error severity classification**: Fatal errors (auth) trigger sign-in prompts, recoverable errors show retry banners

#### Crop & Composition
- **Crop overlay** with draggable corner handles and rule-of-thirds grid
- **Aspect ratio presets**: Free, Original, 1:1, 4:3, 3:2, 16:9, 5:4, 7:5
- **Aspect ratio enforcement** when dragging crop handles
- **Real-time dimension labels** showing crop size in pixels
- **Straighten slider** (-45° to +45°) for fine rotation adjustment
- **90° rotation buttons** (rotate left/right)
- **Flip horizontal/vertical** toggle buttons with visual state indicators

#### Resize
- **ResizePanel** component in Inspector with multiple modes:
  - Pixels (width/height with auto-calculate)
  - Percentage (1-200%)
  - Long Edge / Short Edge
  - Presets: Instagram, Instagram Portrait, Facebook Cover, Twitter Header, 4K/2K Wallpaper, Web 1080p
- **Maintain aspect ratio** toggle
- **Calculated output dimensions** preview
- **Recipe-based resize** stored non-destructively in sidecar JSON

#### Transform Mode
- **Transform toolbar** with Crop button alongside AI Edit
- **Transform mode state** for focused crop/rotate/resize editing
- **Keyboard shortcuts**:
  - `C`: Toggle transform/crop mode
  - `Enter`: Commit and exit transform mode
  - `Escape`: Cancel and exit transform mode

#### Export Enhancements
- **"Use Recipe Resize" export option** respects per-photo resize settings
- **Recipe resize dimensions** displayed in export dialog
- **Info/warning messages** when recipe resize is configured
- **Original dimensions** shown in export size section

#### Inspector UI
- **Enhanced Composition section** with crop, straighten, rotation, and flip controls
- **New Resize panel** (hidden by default, enable via panel customization)
- **Panel visibility configuration** for Resize panel

### Changed
- `ImagePipeline.renderForExport()` now accepts `useRecipeResize` parameter
- `ExportService` passes resize flag to control recipe vs export-time sizing
- Crop struct expanded with `straightenAngle`, `rotationDegrees`, `flipHorizontal`, `flipVertical`
- Resize struct added to EditRecipe with full mode support

### Technical
- `Resize.calculateOutputSize()` method for dimension calculation
- `applyRotation()` in ImagePipeline handles 90° rotation, straighten, and flips
- `applyResize()` in ImagePipeline with Lanczos scaling for export
- `PhotoAsset.imageSize` computed property from metadata
- `KeychainHelper.getOrCreateDeviceId()` for persistent device identification with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- `AccountService.parseErrorCode()` and `parseErrorMessage()` for API error response parsing
- HTTP status code handling in `get()` and `post()` methods for 401/403/429 responses

---

## [1.0.0] - 2026-01-08

### Added

#### White Balance
- Preset modes: As Shot, Auto, Daylight, Cloudy, Shade, Tungsten, Fluorescent, Flash
- Absolute Kelvin temperature (2000-12000K)
- Tint adjustment (-150 to +150)
- Eyedropper mode for picking neutral point

#### Effects
- Vignette with amount and midpoint controls
- Sharpness (luminance sharpening)
- Noise reduction
- Split toning (highlight/shadow color grading)

#### Organization
- Rating: 0-5 stars with visual indicators
- Flags: Pick (green) / Reject (red) / Unflag
- Color labels: 7 colors with thumbnail indicators
- Tags: Custom text tags with add/remove
- FilterBar: Filter photos by rating, flag, color, or tag

#### Keyboard Shortcuts
- `1-5`: Set rating (same key toggles off)
- `0`: Clear rating
- `P`: Pick flag
- `X`: Reject flag
- `U`: Unflag
- `6-9`: Color labels (Red, Yellow, Green, Blue)

#### Performance
- Two-stage loading: Instant embedded JPEG preview, then full RAW decode
- Embedded preview extraction using `CGImageSourceCreateThumbnailAtIndex`
- Eliminated flicker when adjusting sliders

#### Core Features
- Folder browsing with file list
- Thumbnail grid view
- Single photo view with filmstrip
- True RAW processing via `CIRAWFilter`
- Non-destructive editing:
  - Exposure (±5 EV)
  - Contrast
  - Highlights
  - Shadows
  - Whites
  - Blacks
  - Temperature
  - Tint
  - Vibrance
  - Saturation
- 5-point Tone Curve editor
- Basic crop with aspect ratios
- Sidecar JSON persistence
- JPG export with sRGB profile
- Memory card detection
- Debounced preview updates (50ms)
- Debounced sidecar saves (300ms)
- RAW filter caching

#### UI
- Horizontal compact FilterBar
- MetadataBar in Inspector for organization
- Histogram with loading states
- WhiteBalancePanel with gradient sliders

---

## Comparison with Lightroom

| Feature | rawctl | Lightroom |
|---------|--------|-----------|
| **Price** | Free | $10/month |
| **Catalog** | Folder-based | Proprietary |
| **Edits** | Sidecar JSON | Database |
| **Cloud** | None | Required for mobile |
| **RAW Support** | CIRAWFilter | Adobe Camera Raw |
| **Camera Profiles** | ✅ (3 built-in) | ✅ (Adobe Standard) |
| **HSL** | ✅ | ✅ |
| **Crop/Rotate** | ✅ | ✅ |
| **Resize** | ✅ | ✅ |
| **Lens Correction** | Planned | ✅ |
| **Masking** | Not planned | ✅ |
