# Changelog

All notable changes to rawctl will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] - 2026-01-14

### Added

#### Crop System Optimization
- **Draw new crop area**: Drag on dark region outside existing crop frame to draw a completely new crop area
- **Aspect ratio constraint while drawing**: New crop areas respect locked aspect ratios during drawing
- **Instant aspect ratio application**: Crop frame immediately adjusts when selecting new aspect ratio (animated)
- **CropPreviewThumbnail**: New component in right panel Composition section shows preview with crop overlay
- **Edit Crop button**: Quick entry to transform mode from right panel
- **Minimum size threshold**: Prevents accidental clicks from creating tiny crop areas (2% minimum)

#### Enhanced Zoom Controls (SingleView)
- **Scroll wheel zoom**: Smooth zoom in/out at cursor position with proper anchor point calculation
- **Pinch gesture zoom**: Two-finger trackpad pinch for intuitive zoom control
- **Extended zoom range**: 25% to 800% zoom (previously only Fit and 100%)
- **New zoom level buttons**: Fit, 50%, 100%, 200% quick access buttons
- **Live zoom percentage indicator**: Shows current zoom level in bottom-right corner
- **Smart pan bounds clamping**: Prevents panning beyond image edges when zoomed
- **Zoom anchor point**: Zooming centers on cursor position, not view center

#### Lightroom-Style Crop Toolbar (CropToolbar.swift)
- **Aspect ratio picker**: Quick access to all aspect ratios (Free, Original, 1:1, 4:3, 3:2, 16:9, 5:4, 7:5)
- **Grid overlay picker**: Multiple composition guides for better framing
- **Straighten slider**: Fine-tune image rotation from -45° to +45°
- **Flip buttons**: Horizontal and vertical flip with visual state indicators
- **Rotate 90° buttons**: Quick left/right rotation
- **Action buttons**: Confirm (checkmark), Cancel (X), Reset (arrow) with keyboard shortcuts

#### Crop Grid Overlay Options (CropOverlayView)
- **Rule of Thirds**: Classic 3x3 grid for balanced composition
- **Golden Ratio (Phi)**: Lines at φ (1.618) positions for natural proportions
- **Diagonal**: Corner-to-corner diagonal lines
- **Golden Triangle**: Diagonal with perpendicular lines from corners
- **Golden Spiral**: Fibonacci spiral overlay for dynamic composition
- **None**: Clean view without overlay lines

#### Improved Crop Interaction
- **Lightroom-style image drag**: Dragging inside crop frame moves the image under the fixed frame (inverted from previous behavior)
- **Auto-enable crop**: Crop automatically enables when user modifies the crop rectangle
- **Real-time preview**: Crop changes reflected immediately in the preview

### Fixed

#### Crop System
- **Fixed crop region deviating from user selection**: Crop selection was displaced because of coordinate system mismatch
  - Root cause: SwiftUI uses top-left origin (Y increases downward) but CIImage uses bottom-left origin (Y increases upward)
  - Fixed by inverting Y coordinate in ImagePipeline.swift: `y = 1 - crop.rect.y - crop.rect.h`
  - Applied fix to both RAW and non-RAW rendering pipelines (lines 439 and 650)

#### View Switching
- **Fixed Filmstrip bar not visible in SingleView**: The filmstrip thumbnail strip was hidden at the bottom of SingleView
  - Root cause: Main preview ZStack used fixed `.frame(width:height:)` consuming 100% of GeometryReader height
  - Changed to `.frame(maxWidth: .infinity, maxHeight: .infinity)` to allow VStack to properly allocate space for Filmstrip

#### Performance
- **Fixed severe performance degradation when loading 800+ images**: Loading large folders caused long thumbnail loading times and system slowdown
  - Root cause: Each GridThumbnail cell spawned independent async task with no concurrency limit
  - 800 images = 800 concurrent I/O operations (file reads, image decoding) overwhelming system
  - Added concurrency limiting to ThumbnailService (max 8 concurrent thumbnail generations)
  - Uses async semaphore pattern with waiting queue for excess requests
  - Note: Color management pipeline is NOT involved - ThumbnailService uses ImageIO directly

#### Camera Profiles
- **Fixed camera profiles not applying to JPG/PNG images**: ProfilePicker changes had no visible effect on non-RAW images
  - Root cause: `applyFullRecipe()` (non-RAW pipeline) was missing `applyCameraProfile()` call
  - Camera profiles now apply to all image types, not just RAW files

### Technical

#### SingleView.swift (Zoom)
- Main preview ZStack frame: `.frame(width:height:)` → `.frame(maxWidth:maxHeight:)` to allow Filmstrip visibility
- Added `MagnifyGesture` for trackpad pinch zoom with `lastMagnifyScale` state tracking
- Added `onScrollWheel` custom modifier using `NSViewRepresentable` to capture scroll events
- `handleScrollWheelZoom()`: Calculates zoom anchor point from cursor position for smooth zoom-to-cursor
- `clampOffset()`: Keeps pan offset within scaled image bounds
- `ZoomButton`: Reusable zoom level button component
- Zoom constants: `minZoomScale = 0.25`, `maxZoomScale = 8.0`
- New state: `cropGridOverlay: GridOverlay` for crop overlay type

#### CropToolbar.swift (New)
- `CropToolbar`: Main toolbar with aspect picker, grid picker, straighten slider, flip/rotate buttons
- `AspectPicker`: Menu-based aspect ratio selection
- `GridOverlayPicker`: Menu-based grid overlay type selection
- `StraightenSlider`: Slider component for -45° to +45° rotation
- `GridOverlay` enum: `.none`, `.thirds`, `.phi`, `.diagonal`, `.triangle`, `.spiral`

#### CropOverlayView.swift (Grid Overlays)
- Added `gridOverlay: GridOverlay` parameter with default `.thirds`
- `drawGridOverlay()`: Router function for grid type drawing
- `drawThirdsGrid()`: Rule of thirds implementation
- `drawPhiGrid()`: Golden ratio (φ = 1.618) grid
- `drawDiagonalGrid()`: Corner-to-corner diagonals
- `drawGoldenTriangle()`: Diagonal with perpendicular lines
- `drawGoldenSpiral()`: Fibonacci spiral with phi-based arcs
- `handleCenterDrag()`: Inverted delta direction for Lightroom-style image drag
- Auto-enable crop: Sets `crop.isEnabled = true` when rect modified from default

#### ThumbnailService.swift
- Added concurrency limiting with async semaphore pattern:
  - `maxConcurrentGenerations = 8`: Limits simultaneous thumbnail generation
  - `activeGenerations`: Counter tracking current in-flight operations
  - `waitingContinuations`: Queue of suspended tasks waiting for slots
  - `acquireGenerationSlot()`: Async wait if at capacity
  - `releaseGenerationSlot()`: Resumes next waiting task

#### ImagePipeline.swift
- `applyFullRecipe()`: Added `applyCameraProfile()` call at start of non-RAW pipeline
  - Profile applied before user adjustments (same order as RAW pipeline)

---

## [1.2.0] - 2026-01-10

### Added

#### Anonymous Usage Analytics
- **Opt-in analytics system**: First-launch consent dialog lets users choose to share anonymous usage data
- **Privacy-first design**: No personal data, no IP logging, no device fingerprinting
- **Local aggregation**: Events batched and sent every 5 minutes to minimize network calls
- **What's tracked**:
  - Feature usage counts (which sliders, panels, export formats)
  - Session duration and photo editing patterns
  - App version and locale for compatibility insights
- **What's NOT tracked**:
  - Personal information, photos, or filenames
  - Precise timestamps or location data
  - Any identifiable device information

#### Analytics Controls
- **Settings → Analytics**: Toggle analytics on/off anytime
- **Detailed explanation**: Clear breakdown of what is/isn't collected
- **Privacy Policy link**: Direct access to full privacy documentation
- **Instant effect**: Disabling immediately stops all data collection

#### Legal Pages (Landing)
- **Privacy Policy page** (`/privacy`): Full transparency about data handling
- **Terms of Service page** (`/terms`): MIT license terms and usage conditions
- **Footer links**: Quick access to legal pages from main site

#### Project Workflow System
- **Project-based organization**: Group photos by shoot/project instead of just folders
- **Auto-restore last project**: Automatically reopens last active project on app launch
- **State persistence**: Remembers filter state, sort order, view mode, zoom level, and selected photo per project
- **Multi-directory support**: Single project can reference multiple source folders
- **Security-scoped bookmarks**: Folder access persists across app restarts (macOS sandbox compatible)
- **Catalog versioning**: Safe migration from v1 to v2 format with backward compatibility

#### Project Management
- **Create Project sheet**: Set name, client, date, type, source folders, and notes
- **Rename projects**: Right-click context menu or keyboard shortcut
- **Delete projects**: Removes from catalog without touching original files
- **Project status tracking**: Importing → Culling → Editing → Ready for Delivery → Delivered → Archived
- **Month grouping**: Projects organized by shoot month in sidebar
- **Status indicators**: Color-coded status badges on project rows

#### Lightroom Import
- **Import Lightroom Catalog** (Cmd+Shift+I): Import photos from .lrcat files
- **Metadata extraction**: Ratings, flags, and color labels imported from Lightroom
- **Progress tracking**: Real-time import progress with phase indicators
- **SQLite3 integration**: Direct reading of Lightroom catalog database
- **Error handling**: Graceful handling of corrupt/unsupported catalogs

#### Multi-Select Context Menu
- **Right-click bulk actions**: Apply rating, flag, or color label to multiple selected photos at once
- **Smart selection detection**: Menu shows count of affected photos
- **Rating submenu**: Set 1-5 stars or clear rating for all selected photos
- **Flag submenu**: Set Pick, Reject, or Unflag for all selected photos
- **Color label submenu**: Apply any color label to all selected photos
- **Quick actions**: Select All and Deselect All shortcuts in menu

#### Enhanced Menu Bar
- **File menu**: New Project (Cmd+N), Open Folder (Cmd+O), Import Lightroom Catalog (Cmd+Shift+I)
- **View menu**: Grid/Single view toggle (Cmd+1/2), Toggle Sidebar (Ctrl+Cmd+S), Toggle Inspector (Opt+Cmd+I), Zoom controls (Cmd+/-, Cmd+0), Highlight/Shadow clipping (Cmd+J/U)
- **Photo menu**: Previous/Next photo (Arrow keys), Rating submenu (0-5), Flag submenu (P/X/U), Color Label submenu (6-9), Export (Cmd+E), Reset Adjustments (Cmd+Shift+R)
- **Select menu**: Select All (Cmd+A), Deselect All (Cmd+D), Select Picks, Select Rejects, Invert Selection (Cmd+Shift+I)

#### Responsive Layout Foundation
- **4-tier breakpoint system**: XS (<900px), S (900-1200px), M (1200-1600px), L (>1600px)
- **ResponsiveLayout environment object**: Observable window width with automatic breakpoint detection
- **Inspector collapsible mechanism**: Chevron button in Inspector header with spring animation
- **Auto-show/hide Inspector**: Inspector automatically shows on M/L breakpoints, hides on XS/S
- **Breakpoint preferences**: User can override default Inspector visibility per breakpoint
- **InspectorMode enum**: Overlay mode (XS/S) vs inline mode (M/L) for future implementation

#### Persistence Bug Fix
- **Per-asset debounce**: Fixed racing saves when quickly switching between photos
- **Debounce dictionary**: `saveTasks: [URL: Task<Void, Never>]` replaces single global task
- **Pending saves flush**: All pending saves flushed on app quit via `scenePhase` monitoring
- **Safe merge API**: `saveRecipeOnly()` preserves existing snapshots when only recipe changes

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

#### AI Generation
- **AI generation progress stuck at 90%**: Improved progress tracking in NanoBananaService and AIGenerationService
  - Progress no longer drops to 0% when server doesn't report progress
  - Simulated incremental progress when stuck to show activity (capped at 95%)
  - Smooth transition to 100% before download phase
  - AIGenerationService now shows simulated progress during API call

#### SingleView
- **Crop button not responding**: Fixed disconnected state between `transformMode` and `crop.isEnabled` - crop overlay now correctly shows when clicking the Crop button

#### GridView
- **Infinite dropdown animation on section headers**: Disabled implicit SwiftUI animations on section headers using `.animation(nil)` and `.transaction` modifiers to prevent visual glitches when view updates

### Changed

#### Project & Catalog
- **Catalog format v2**: Extended Project model with state memory fields
- **CatalogService**: Added nonisolated catalogPath for sync termination save
- **AppState.selectProject()**: Now saves/restores state when switching projects
- **App-wide zoom level**: `zoomLevel` property moved to AppState for menu bar integration

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

#### Landing Page
- **Centralized config**: `APP_CONFIG` with version, download URL, and release info
- **Auto-update modal**: One-time notification for users to re-download for auto-update support
- **Community section** with three tabs:
  - **Newsletter**: Email subscription form
  - **Feature Requests**: Vote on 10 feature options (Lens Correction, Local Adjustments, Presets, Batch Export, iCloud Sync, AI Masks, Tethering, Plugins, iOS App, LR Import)
  - **Feedback**: Bug reports, suggestions, and praise collection
- **Version display**: Shows current version in hero section
- All download buttons now use centralized config URL

#### Data Collection API (Cloudflare Workers + R2)
- **API endpoints** at `api.rawctl.app`:
  - `POST /api/subscribe`: Newsletter email collection
  - `POST /api/feature-request`: Feature voting submission
  - `POST /api/feedback`: Bug reports, suggestions, praise
  - `GET /api/stats`: Aggregate statistics
  - `GET /api/export/*`: Data export (emails, features, feedback)
- **R2 storage**: All data persisted in Cloudflare R2 bucket (`rawctl-data`)
- **Scheduled digest**: Cron-triggered daily summary via Resend email API
- **Notification options documented**:
  - Email digest via Resend (recommended)
  - Webhook to n8n/Make/Zapier
  - macOS local notifications via osascript
  - Telegram bot integration
  - RSS feed endpoint

### Technical

#### Analytics (Swift)
- `AnalyticsService.swift`: Core analytics service with opt-in/opt-out management
- `AnalyticsEvent`: Event model with category, action, label, value
- `AnalyticsCategory`: Enum for editing, export, ui, session, feature categories
- Local event aggregation before batch sending
- Session tracking with duration and editing patterns
- Graceful handling of network failures (silent fail, no user impact)

#### Analytics API (Cloudflare Workers)
- `POST /analytics`: Receive anonymous usage data
- `GET /analytics/summary`: Internal dashboard for aggregate stats
- D1 database tables: `analytics_sessions`, `analytics_events`
- 30-day rolling aggregation for storage efficiency

#### Analytics Integration Points
- `ControlSlider.swift`: Track slider adjustments
- `CollapsibleSection.swift`: Track panel open/close
- `ExportService.swift`: Track export start/complete/cancel
- `MainLayoutView.swift`: Track view mode, photo navigation, reset actions
- `FirstLaunchAnalyticsSheet.swift`: Consent dialog on first launch
- `AnalyticsSettingsView.swift`: Preferences panel for analytics control

#### Responsive Layout
- `ResponsiveLayout.swift`: New environment object with breakpoint management
- `LayoutBreakpoint`: Enum with XS/S/M/L cases and computed properties
- `InspectorMode`: Enum for overlay vs inline Inspector rendering
- `MainLayoutView`: Integrated breakpoint transitions with spring animations
- `InspectorView`: Added collapse button with NotificationCenter integration
- `handleBreakpointChange()`: Auto-adjusts Inspector visibility on breakpoint transitions

#### Persistence
- `SidecarService.saveTasks`: Per-asset debounce dictionary
- `SidecarService.pendingSaves`: Pending data for flush on quit
- `SidecarService.flushAllPendingSaves()`: Immediate save of all pending data
- `SidecarService.saveRecipeOnly()`: Safe API preserving existing snapshots
- `rawctlApp.scenePhase`: Monitors app lifecycle for `.inactive` flush trigger

#### Project & Catalog
- `SavedFilterState`: Codable filter state separate from UI-only FilterState
- `SavedViewMode`: Enum for grid/single persistence
- `ProjectImportSource`: Tracks native vs Lightroom import origin
- `LRCatImporter`: SQLite3-based Lightroom catalog reader
- `ImportLightroomSheet`: SwiftUI import UI with progress and error handling
- Auto-save on `NSApplication.willTerminateNotification`
- **Menu notifications**: 20+ new `Notification.Name` extensions for menu-view communication
- **Context menu helpers**: `applyRatingToAssets`, `applyFlagToAssets`, `applyColorLabelToAssets` in GridView
- **Progress tracking**: `lastKnownProgress` and `stuckAttempts` variables for better progress simulation

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
