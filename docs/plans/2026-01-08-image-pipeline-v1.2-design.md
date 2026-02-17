# rawctl v1.2 Image Pipeline Design

**Version**: 1.2.0
**Date**: 2026-01-08
**Status**: Draft
**Target**: macOS (Apple Silicon optimized)

## Executive Summary

v1.2 將同時改進兩個核心系統：
1. **Color Pipeline** - 解決「一調就過火」問題
2. **Preview System** - 實現 Lightroom 級別的互動手感

## Problem Statement

### 現時問題

1. **調整容易過曝/死黑** - 缺少 tone mapping 和 highlight roll-off
2. **預覽響應慢** - 無 tile-based rendering，每次全圖重算
3. **色彩不準確** - 無 camera profile system，直接用 linear RAW 數據

### 目標成果

- 調整 ±2 stops 曝光後仍保持自然
- Slider 拖動即時響應 (<50ms)
- 「一開相已經好睇」的 base look

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      RAW File Input                          │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Stage 1: RAW Decode (CIRAWFilter)                          │
│  - Demosaic                                                  │
│  - White Balance (camera As-Shot or user override)           │
│  - Exposure (EV adjustment)                                  │
│  Output: Linear RGB (scene-referred, wide gamut)             │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Stage 2: Camera Profile (NEW)                               │
│  - Input Transform (camera → working space)                  │
│  - Base Tone Curve (log encoding for headroom)               │
│  - Look/Style (Neutral, Vivid, Portrait)                     │
│  Output: Working space (log-encoded, P3 gamut)               │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Stage 3: User Adjustments (Working Space)                   │
│  - Exposure (with shoulder protection)                       │
│  - Contrast (S-curve with controlled pivot)                  │
│  - Highlights/Shadows (with soft knee)                       │
│  - Whites/Blacks (endpoint control)                          │
│  - Tone Curve (user curve on top of base)                    │
│  - HSL / Color Grading                                       │
│  Output: Adjusted working space                              │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Stage 4: Output Transform (NEW)                             │
│  - Display Transform (working → display)                     │
│  - Gamut Mapping (P3 → sRGB if needed)                       │
│  - Final Tone Mapping (filmic highlight roll-off)            │
│  Output: Display-referred (sRGB/P3)                          │
└─────────────────────────────────────────────────────────────┘
```

---

## Milestone A: Color Correctness

### A1. Working Color Space Definition

**Goal**: 定義 rawctl 的標準工作色彩空間

```swift
struct ColorPipelineConfig {
    /// Working color space (scene-referred, log-encoded)
    static let workingColorSpace = CGColorSpace(name: CGColorSpace.displayP3)!

    /// Internal processing precision
    static let processingBitDepth: Int = 16  // 16-bit float

    /// Log encoding for headroom
    static let logEncoding = LogEncoding.logC  // Similar to ARRI LogC
}

enum LogEncoding {
    case linear     // No encoding (current behavior)
    case logC       // Cinematic log curve
    case filmicLog  // Custom filmic log
}
```

### A2. Camera Profile System

**Goal**: 內建 2-3 個 base profile

```swift
/// Camera profile for color transform and base look
struct CameraProfile: Codable, Identifiable {
    let id: String
    let name: String
    let manufacturer: String?

    /// Color matrix (camera → working space)
    let colorMatrix: ColorMatrix3x3

    /// Base tone curve (applied before user adjustments)
    let baseToneCurve: ToneCurve

    /// Highlight shoulder parameters
    let highlightShoulder: HighlightShoulder

    /// Optional look/style adjustments
    let look: ProfileLook?
}

struct HighlightShoulder {
    let knee: Double        // Where roll-off begins (0.8 = 80% brightness)
    let softness: Double    // How gradual the roll-off (0.0-1.0)
    let whitePoint: Double  // Maximum output value (0.95-1.0)
}

/// Built-in profiles
enum BuiltInProfile: String, CaseIterable {
    case neutral = "rawctl.neutral"
    case vivid = "rawctl.vivid"
    case portrait = "rawctl.portrait"

    var profile: CameraProfile {
        switch self {
        case .neutral:
            return CameraProfile(
                id: rawValue,
                name: "rawctl Neutral",
                manufacturer: "rawctl",
                colorMatrix: .identity,
                baseToneCurve: ToneCurve.filmicNeutral,
                highlightShoulder: HighlightShoulder(knee: 0.85, softness: 0.3, whitePoint: 0.98),
                look: nil
            )
        case .vivid:
            return CameraProfile(
                id: rawValue,
                name: "rawctl Vivid",
                manufacturer: "rawctl",
                colorMatrix: .identity,
                baseToneCurve: ToneCurve.filmicVivid,
                highlightShoulder: HighlightShoulder(knee: 0.82, softness: 0.25, whitePoint: 0.97),
                look: ProfileLook(saturationBoost: 0.15, contrastBoost: 0.1)
            )
        case .portrait:
            return CameraProfile(
                id: rawValue,
                name: "rawctl Portrait",
                manufacturer: "rawctl",
                colorMatrix: .skinToneOptimized,
                baseToneCurve: ToneCurve.filmicSoft,
                highlightShoulder: HighlightShoulder(knee: 0.88, softness: 0.4, whitePoint: 0.99),
                look: ProfileLook(saturationBoost: -0.05, warmthShift: 0.02)
            )
        }
    }
}
```

### A3. Base Tone Curve (Filmic)

**Goal**: 實現類似 Lightroom 的 filmic tone mapping

```swift
extension ToneCurve {
    /// Filmic neutral - natural roll-off, no crushed blacks
    static var filmicNeutral: ToneCurve {
        ToneCurve(points: [
            CurvePoint(x: 0.00, y: 0.00),   // Black point
            CurvePoint(x: 0.05, y: 0.03),   // Shadow lift (subtle)
            CurvePoint(x: 0.18, y: 0.18),   // Mid-gray anchor
            CurvePoint(x: 0.50, y: 0.52),   // Slight mid lift
            CurvePoint(x: 0.85, y: 0.90),   // Shoulder start
            CurvePoint(x: 1.00, y: 0.98),   // Soft white clip
        ])
    }

    /// Filmic vivid - more contrast, saturated
    static var filmicVivid: ToneCurve {
        ToneCurve(points: [
            CurvePoint(x: 0.00, y: 0.00),
            CurvePoint(x: 0.05, y: 0.02),   // Slightly deeper shadows
            CurvePoint(x: 0.18, y: 0.16),   // Below mid for contrast
            CurvePoint(x: 0.50, y: 0.54),   // Push mids up
            CurvePoint(x: 0.82, y: 0.92),   // Earlier shoulder
            CurvePoint(x: 1.00, y: 0.97),
        ])
    }

    /// Filmic soft - lower contrast, skin-friendly
    static var filmicSoft: ToneCurve {
        ToneCurve(points: [
            CurvePoint(x: 0.00, y: 0.02),   // Lifted blacks
            CurvePoint(x: 0.05, y: 0.06),
            CurvePoint(x: 0.18, y: 0.20),   // Slightly above mid
            CurvePoint(x: 0.50, y: 0.50),
            CurvePoint(x: 0.88, y: 0.88),   // Late, gentle shoulder
            CurvePoint(x: 1.00, y: 0.99),
        ])
    }
}
```

### A4. Highlight Roll-off Implementation

**Goal**: 防止高光爆白

```swift
/// Apply highlight shoulder (soft roll-off to prevent clipping)
func applyHighlightShoulder(_ shoulder: HighlightShoulder, to image: CIImage) -> CIImage {
    // Use tone curve to create smooth shoulder
    let kneeStart = shoulder.knee
    let softness = shoulder.softness
    let whitePoint = shoulder.whitePoint

    // Calculate shoulder curve points
    let shoulderMid = kneeStart + (1.0 - kneeStart) * 0.5
    let shoulderEnd = 1.0

    let filter = CIFilter.toneCurve()
    filter.inputImage = image
    filter.point0 = CGPoint(x: 0, y: 0)
    filter.point1 = CGPoint(x: 0.25, y: 0.25)
    filter.point2 = CGPoint(x: 0.5, y: 0.5)
    filter.point3 = CGPoint(x: kneeStart, y: kneeStart * (1.0 - softness * 0.1))
    filter.point4 = CGPoint(x: shoulderEnd, y: whitePoint)

    return filter.outputImage ?? image
}
```

### A5. Display Transform

**Goal**: 正確從 working space 轉換到顯示器

```swift
/// Output transform to display color space
func applyDisplayTransform(to image: CIImage, targetSpace: CGColorSpace) -> CIImage {
    var result = image

    // 1. Apply final tone mapping (scene → display)
    result = applyFinalToneMapping(to: result)

    // 2. Gamut map if needed (P3 → sRGB)
    if targetSpace.name == CGColorSpace.sRGB {
        result = applyGamutMapping(from: .displayP3, to: .sRGB, image: result)
    }

    // 3. Apply display gamma (if not handled by ColorSync)
    // Note: Usually ColorSync handles this

    return result
}

/// Final tone mapping for display
private func applyFinalToneMapping(to image: CIImage) -> CIImage {
    // Apply subtle filmic curve for display
    // This catches any remaining out-of-range values
    let filter = CIFilter.toneCurve()
    filter.inputImage = image
    filter.point0 = CGPoint(x: 0, y: 0)
    filter.point1 = CGPoint(x: 0.25, y: 0.25)
    filter.point2 = CGPoint(x: 0.5, y: 0.5)
    filter.point3 = CGPoint(x: 0.75, y: 0.76)
    filter.point4 = CGPoint(x: 1.0, y: 1.0)

    return filter.outputImage ?? image
}
```

---

## Milestone B: Preview System (Lightroom-like Performance)

### B1. Multi-Resolution Preview Pyramid

**Goal**: 建立多解析度預覽金字塔

```swift
/// Multi-resolution preview pyramid for fast rendering
actor PreviewPyramid {
    struct PyramidLevel {
        let scale: CGFloat      // 1.0 = full, 0.5 = half, etc.
        let maxDimension: Int   // Max width or height
        let quality: Quality

        enum Quality {
            case draft      // Skip expensive filters
            case preview    // Most filters, reduced quality
            case full       // All filters, full quality
        }
    }

    static let levels: [PyramidLevel] = [
        PyramidLevel(scale: 0.125, maxDimension: 400, quality: .draft),    // 1/8 - instant scrub
        PyramidLevel(scale: 0.25, maxDimension: 800, quality: .draft),     // 1/4 - fast preview
        PyramidLevel(scale: 0.5, maxDimension: 1600, quality: .preview),   // 1/2 - editing preview
        PyramidLevel(scale: 1.0, maxDimension: 4096, quality: .full),      // 1/1 - export/zoom
    ]

    private var cache: [String: [CGFloat: CIImage]] = [:]  // assetId → [scale → image]

    /// Get best available level for current view size
    func getBestLevel(for viewSize: CGSize, assetId: String) -> (level: PyramidLevel, image: CIImage?) {
        let targetDimension = max(viewSize.width, viewSize.height) * 2  // 2x for retina

        // Find smallest level that covers the view
        for level in Self.levels {
            if CGFloat(level.maxDimension) >= targetDimension {
                let cached = cache[assetId]?[level.scale]
                return (level, cached)
            }
        }

        // Return largest level
        let largest = Self.levels.last!
        return (largest, cache[assetId]?[largest.scale])
    }
}
```

### B2. Tile-Based Renderer

**Goal**: 只重算可見區域

```swift
/// Tile-based renderer for efficient partial updates
actor TileRenderer {
    static let tileSize: Int = 512  // 512x512 pixel tiles

    struct Tile: Hashable {
        let x: Int  // Column index
        let y: Int  // Row index

        var rect: CGRect {
            CGRect(
                x: x * TileRenderer.tileSize,
                y: y * TileRenderer.tileSize,
                width: TileRenderer.tileSize,
                height: TileRenderer.tileSize
            )
        }
    }

    /// Rendered tile cache
    private var tileCache: [String: [Tile: CGImage]] = [:]  // assetId → [tile → rendered]

    /// Recipe hash for invalidation
    private var recipeHashes: [String: Int] = [:]

    /// Get visible tiles for a viewport
    func visibleTiles(imageSize: CGSize, viewport: CGRect, scale: CGFloat) -> [Tile] {
        let scaledViewport = CGRect(
            x: viewport.origin.x / scale,
            y: viewport.origin.y / scale,
            width: viewport.width / scale,
            height: viewport.height / scale
        )

        let startCol = max(0, Int(floor(scaledViewport.minX / CGFloat(Self.tileSize))))
        let endCol = Int(ceil(scaledViewport.maxX / CGFloat(Self.tileSize)))
        let startRow = max(0, Int(floor(scaledViewport.minY / CGFloat(Self.tileSize))))
        let endRow = Int(ceil(scaledViewport.maxY / CGFloat(Self.tileSize)))

        var tiles: [Tile] = []
        for row in startRow..<endRow {
            for col in startCol..<endCol {
                tiles.append(Tile(x: col, y: row))
            }
        }
        return tiles
    }

    /// Render specific tiles
    func renderTiles(
        _ tiles: [Tile],
        for assetId: String,
        sourceImage: CIImage,
        recipe: EditRecipe,
        quality: PreviewPyramid.PyramidLevel.Quality
    ) async -> [Tile: CGImage] {
        var results: [Tile: CGImage] = [:]

        // Check recipe changed
        let newHash = recipe.hashValue
        if recipeHashes[assetId] != newHash {
            tileCache[assetId]?.removeAll()
            recipeHashes[assetId] = newHash
        }

        for tile in tiles {
            // Check cache
            if let cached = tileCache[assetId]?[tile] {
                results[tile] = cached
                continue
            }

            // Render tile
            let tileRect = tile.rect
            let croppedSource = sourceImage.cropped(to: tileRect)
            let processed = await renderTile(croppedSource, recipe: recipe, quality: quality)

            if let cgImage = processed {
                results[tile] = cgImage
                if tileCache[assetId] == nil {
                    tileCache[assetId] = [:]
                }
                tileCache[assetId]?[tile] = cgImage
            }
        }

        return results
    }

    private func renderTile(_ image: CIImage, recipe: EditRecipe, quality: PreviewPyramid.PyramidLevel.Quality) async -> CGImage? {
        let fastMode = quality == .draft
        // Use existing ImagePipeline logic with fastMode
        return nil  // TODO: Implement
    }
}
```

### B3. Draft/Full Quality Pipeline

**Goal**: Slider 拖動時用 draft，停手後補算 full

```swift
/// Quality-aware render coordinator
actor RenderCoordinator {
    private var pendingFullQualityRender: Task<Void, Never>?
    private let fullQualityDelay: UInt64 = 200_000_000  // 200ms

    /// Handle slider value change
    func onSliderChange(assetId: String, recipe: EditRecipe) async -> NSImage? {
        // Cancel pending full-quality render
        pendingFullQualityRender?.cancel()

        // Immediate draft render
        let draftImage = await renderDraft(assetId: assetId, recipe: recipe)

        // Schedule full-quality render after delay
        pendingFullQualityRender = Task {
            try? await Task.sleep(nanoseconds: fullQualityDelay)

            guard !Task.isCancelled else { return }

            let fullImage = await renderFull(assetId: assetId, recipe: recipe)

            // Notify UI to update (via callback or notification)
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .previewFullQualityReady,
                    object: nil,
                    userInfo: ["assetId": assetId, "image": fullImage as Any]
                )
            }
        }

        return draftImage
    }

    /// Slider released - ensure full quality
    func onSliderEnd(assetId: String, recipe: EditRecipe) async -> NSImage? {
        pendingFullQualityRender?.cancel()
        return await renderFull(assetId: assetId, recipe: recipe)
    }

    private func renderDraft(assetId: String, recipe: EditRecipe) async -> NSImage? {
        // Use 1/4 pyramid level, skip expensive filters
        return nil  // TODO: Implement with PreviewPyramid
    }

    private func renderFull(assetId: String, recipe: EditRecipe) async -> NSImage? {
        // Use 1/2 or 1/1 pyramid level, all filters
        return nil  // TODO: Implement with PreviewPyramid
    }
}

extension Notification.Name {
    static let previewFullQualityReady = Notification.Name("rawctl.previewFullQualityReady")
}
```

### B4. Intermediate Result Cache

**Goal**: Cache demosaic + WB 後的 working buffer

```swift
/// Cache for intermediate processing results
actor IntermediateCache {
    struct CacheEntry {
        let image: CIImage
        let stage: ProcessingStage
        let recipePartialHash: Int  // Hash of recipe up to this stage
        let timestamp: Date
    }

    enum ProcessingStage: Int, Comparable {
        case rawDecode = 1        // After CIRAWFilter
        case cameraProfile = 2    // After profile applied
        case baseAdjustments = 3  // After exposure/contrast/HS
        case colorGrading = 4     // After HSL/curves
        case effects = 5          // After clarity/dehaze/etc

        static func < (lhs: ProcessingStage, rhs: ProcessingStage) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    private var cache: [String: [ProcessingStage: CacheEntry]] = [:]
    private let maxEntriesPerAsset = 3

    /// Get cached result if recipe hasn't changed up to that stage
    func getCached(
        assetId: String,
        stage: ProcessingStage,
        recipePartialHash: Int
    ) -> CIImage? {
        guard let entry = cache[assetId]?[stage],
              entry.recipePartialHash == recipePartialHash else {
            return nil
        }
        return entry.image
    }

    /// Store intermediate result
    func store(
        assetId: String,
        stage: ProcessingStage,
        image: CIImage,
        recipePartialHash: Int
    ) {
        if cache[assetId] == nil {
            cache[assetId] = [:]
        }

        // Invalidate later stages (recipe changed)
        for existingStage in cache[assetId]!.keys where existingStage > stage {
            cache[assetId]?.removeValue(forKey: existingStage)
        }

        cache[assetId]?[stage] = CacheEntry(
            image: image,
            stage: stage,
            recipePartialHash: recipePartialHash,
            timestamp: Date()
        )
    }
}
```

### B5. Metal Performance Shaders Integration

**Goal**: Apple Silicon GPU 加速關鍵運算

```swift
/// Metal-accelerated image processing for Apple Silicon
actor MetalProcessor {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue

    // Pre-compiled pipelines
    private var hslPipeline: MTLComputePipelineState?
    private var toneCurvePipeline: MTLComputePipelineState?
    private var clarityPipeline: MTLComputePipelineState?

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            return nil
        }
        self.device = device
        self.commandQueue = queue

        // Compile shaders
        Task {
            await compileShaders()
        }
    }

    private func compileShaders() async {
        // Load Metal library
        guard let library = device.makeDefaultLibrary() else { return }

        // HSL adjustment shader
        if let hslFunction = library.makeFunction(name: "hslAdjustment") {
            hslPipeline = try? device.makeComputePipelineState(function: hslFunction)
        }

        // Tone curve shader
        if let curveFunction = library.makeFunction(name: "toneCurveApply") {
            toneCurvePipeline = try? device.makeComputePipelineState(function: curveFunction)
        }

        // Clarity (local contrast) shader
        if let clarityFunction = library.makeFunction(name: "clarityEnhance") {
            clarityPipeline = try? device.makeComputePipelineState(function: clarityFunction)
        }
    }

    /// Process HSL adjustment using Metal
    func applyHSL(_ hsl: HSLAdjustment, to texture: MTLTexture) async -> MTLTexture? {
        guard let pipeline = hslPipeline,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }

        // Create output texture
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: texture.pixelFormat,
            width: texture.width,
            height: texture.height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]

        guard let outputTexture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(texture, index: 0)
        encoder.setTexture(outputTexture, index: 1)

        // Set HSL parameters
        var params = hsl.toMetalParams()
        encoder.setBytes(&params, length: MemoryLayout.size(ofValue: params), index: 0)

        // Dispatch
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (texture.width + 15) / 16,
            height: (texture.height + 15) / 16,
            depth: 1
        )
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return outputTexture
    }
}
```

---

## Implementation Phases

### Phase 1: Color Foundation (Week 1-2)

1. **Define ColorPipelineConfig** - Working space, log encoding
2. **Implement CameraProfile struct** - Data model
3. **Create built-in profiles** - Neutral, Vivid, Portrait
4. **Implement base tone curves** - Filmic neutral/vivid/soft
5. **Add highlight shoulder** - Soft roll-off logic
6. **Profile selector UI** - In Inspector panel

### Phase 2: Preview Architecture (Week 2-3)

1. **Implement PreviewPyramid** - Multi-resolution levels
2. **Implement IntermediateCache** - Stage-based caching
3. **Add draft/full quality modes** - Extend fastMode concept
4. **Implement RenderCoordinator** - Delay-based full render

### Phase 3: Tile System (Week 3-4)

1. **Implement TileRenderer** - Tile-based rendering
2. **Visible tile calculation** - Based on viewport
3. **Tile cache management** - LRU eviction
4. **Integrate with preview view** - Partial updates

### Phase 4: Metal Optimization (Week 4-5)

1. **Create Metal shaders** - HSL, tone curve, clarity
2. **Implement MetalProcessor** - GPU pipeline
3. **Integrate with ImagePipeline** - Conditional Metal path
4. **Performance profiling** - Instruments validation

### Phase 5: Integration & Polish (Week 5-6)

1. **UI integration** - Profile picker, quality indicator
2. **Memory management** - Pyramid + tile cache limits
3. **Error handling** - Graceful fallbacks
4. **Testing** - Various RAW formats, edge cases

---

## Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Exposure ±2 EV without clipping | ❌ Clips easily | ✅ Graceful roll-off |
| Slider responsiveness | ~200ms | <50ms (draft) |
| Full quality after scrub | N/A | <300ms |
| Memory usage (editing) | Unbounded | <800MB |
| Time to first preview | ~500ms | <100ms (embedded) |

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Metal shader complexity | Start with CIFilter fallback, add Metal incrementally |
| Memory pressure from pyramid | Aggressive LRU eviction, monitor with dispatch source |
| Profile color accuracy | Test with ColorChecker, iterate on curves |
| Tile boundary artifacts | Overlap tiles by 1px, blend edges |

---

## Files to Create/Modify

### New Files
- `Models/CameraProfile.swift` - Profile data model
- `Models/ColorPipelineConfig.swift` - Pipeline configuration
- `Services/PreviewPyramid.swift` - Multi-resolution cache
- `Services/TileRenderer.swift` - Tile-based rendering
- `Services/IntermediateCache.swift` - Stage cache
- `Services/RenderCoordinator.swift` - Draft/full coordination
- `Services/MetalProcessor.swift` - GPU acceleration
- `Shaders/ImageProcessing.metal` - Metal shaders
- `Components/ProfilePicker.swift` - Profile selector UI

### Modified Files
- `Services/ImagePipeline.swift` - Integrate new pipeline stages
- `Services/RenderQueue.swift` - Support quality levels
- `Views/PhotoView.swift` - Handle partial tile updates
- `Models/EditRecipe.swift` - Add profile selection
- `Views/Inspector/LightPanel.swift` - Profile picker integration

---

## Appendix: Reference Resources

- [ACES Color Management](https://acescolorspace.com/) - Industry standard pipeline
- [FilmLight Technical Papers](https://www.filmlight.ltd.uk/support/documents/technical_papers.php) - Color science
- [Apple Core Image Programming Guide](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/CoreImaging/ci_intro/ci_intro.html)
- [Metal Best Practices Guide](https://developer.apple.com/library/archive/documentation/Miscellaneous/Conceptual/MetalProgrammingGuide/)
