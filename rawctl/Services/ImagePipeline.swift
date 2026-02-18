//
//  ImagePipeline.swift
//  rawctl
//
//  Core Image based rendering pipeline with true RAW support
//

import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import AppKit

/// Image rendering pipeline using Core Image
actor ImagePipeline {
    static let shared = ImagePipeline()
    
    private let context: CIContext
    
    // Cache for RAW filter instances (preserves RAW data for adjustment)
    private var rawFilterCache: [String: CIFilter] = [:]
    // Cache of per-asset RAW defaults (needed to correctly restore "As Shot" when reusing filters)
    private var rawWhiteBalanceDefaults: [String: (temperature: Float, tint: Float)] = [:]
    // Cache for non-RAW images
    private var imageCache: [String: CIImage] = [:]
    private var cacheOrder: [String] = []
    private let maxCacheSize = 3  // Reduced from 5 for memory savings
    
    // Intermediate result cache (for differential rendering)
    private var intermediateCache: [String: CIImage] = [String: CIImage]()
    private var lastRecipeHash: [String: Int] = [String: Int]()

    // Camera profile filter cache (v1.2) - reuse filters during scrubbing
    private var profileToneCurveCache: [String: CIFilter] = [:]
    private var profileShoulderCache: [String: CIFilter] = [:]
    
    // Memory management
    private let maxMemoryMB: Int = 400  // Max cache memory in MB
    private var lastMemoryCheck: Date = .distantPast

    /// Filters to skip in fast mode (expensive operations)
    private let expensiveFilters: Set<String> = ["clarity", "dehaze", "texture", "grain", "noiseReduction", "hsl"]

    /// Concurrent render limiter for grid thumbnails (prevent GPU overload)
    private let concurrentGridRenderLimit = 4
    private var activeGridRenders = 0
    private var pendingGridRenders: [CheckedContinuation<Void, Never>] = []

    /// Acquire a grid render slot
    private func acquireGridRenderSlot() async {
        if activeGridRenders >= concurrentGridRenderLimit {
            await withCheckedContinuation { continuation in
                pendingGridRenders.append(continuation)
            }
        }
        activeGridRenders += 1
    }

    /// Release a grid render slot
    private func releaseGridRenderSlot() {
        activeGridRenders -= 1
        if let next = pendingGridRenders.first {
            pendingGridRenders.removeFirst()
            next.resume()
        }
    }
    
    init() {
        // Use Metal for GPU acceleration with optimized settings
        if let device = MTLCreateSystemDefaultDevice() {
            context = CIContext(mtlDevice: device, options: [
                .workingColorSpace: CGColorSpace(name: CGColorSpace.linearSRGB)!,
                .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                .cacheIntermediates: false,  // Reduce memory usage
                .priorityRequestLow: true     // Don't block other GPU work
            ])
        } else {
            context = CIContext()
        }
        
        // Monitor memory pressure
        setupMemoryPressureMonitoring()
    }
    
    /// Setup memory pressure monitoring using dispatch source
    nonisolated private func setupMemoryPressureMonitoring() {
        // Use dispatch source for memory pressure on macOS
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        source.setEventHandler { [weak self] in
            Task {
                await self?.handleMemoryPressure()
            }
        }
        source.resume()
    }
    
    /// Handle memory pressure by clearing caches
    private func handleMemoryPressure() {
        print("[ImagePipeline] Memory pressure detected, clearing caches")
        rawFilterCache.removeAll()
        rawWhiteBalanceDefaults.removeAll()
        imageCache.removeAll()
        intermediateCache.removeAll()
        lastRecipeHash.removeAll()
        cacheOrder.removeAll()
    }
    
    /// Check if we should reduce memory usage
    private func checkMemoryAndEvictIfNeeded() {
        // Only check every 2 seconds to avoid overhead
        guard Date().timeIntervalSince(lastMemoryCheck) > 2 else { return }
        lastMemoryCheck = Date()
        
        // Check available memory
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let usedMB = Int(info.resident_size / 1024 / 1024)
            if usedMB > maxMemoryMB {
                print("[ImagePipeline] Memory usage \(usedMB)MB exceeds \(maxMemoryMB)MB, evicting cache")
                // Evict oldest entries
                if !cacheOrder.isEmpty {
                    let keyToRemove = cacheOrder.removeFirst()
                    rawFilterCache.removeValue(forKey: keyToRemove)
                    rawWhiteBalanceDefaults.removeValue(forKey: keyToRemove)
                    imageCache.removeValue(forKey: keyToRemove)
                }
            }
        }
    }
    
    // MARK: - P0: Fast Embedded Preview Extraction
    
    /// Extract embedded JPEG preview from RAW file (instant, no decode)
    /// RAW files contain embedded JPEG previews (~200KB vs 25MB full decode)
    func extractEmbeddedPreview(for asset: PhotoAsset, maxSize: CGFloat = 1600) async -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(asset.url as CFURL, nil) else {
            return nil
        }
        
        // Options for fast thumbnail extraction
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxSize)
        ]
        
        // Extract embedded thumbnail (instant, no RAW decode)
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
    
    /// Quick preview for instant display (uses embedded JPEG if available)
    func quickPreview(for asset: PhotoAsset) async -> NSImage? {
        // First try embedded preview (fastest)
        if let embedded = await extractEmbeddedPreview(for: asset, maxSize: 1600) {
            return embedded
        }
        
        // Fallback: quick CIImage load without full RAW processing
        guard let ciImage = CIImage(contentsOf: asset.url) else {
            return nil
        }
        
        // Scale down for preview
        let scale = min(1.0, 1600.0 / max(ciImage.extent.width, ciImage.extent.height))
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
            return nil
        }
        
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
    
    /// Render preview with recipe applied (true RAW processing)
    /// - Parameters:
    ///   - asset: The photo asset to render
    ///   - recipe: Edit recipe to apply
    ///   - maxSize: Maximum dimension for output
    ///   - fastMode: If true, skip expensive filters (for slider dragging)
    func renderPreview(
        for asset: PhotoAsset,
        recipe: EditRecipe,
        maxSize: CGFloat = 1600,
        fastMode: Bool = false,
        localNodes: [ColorNode] = []
    ) async -> NSImage? {
        let cacheKey = asset.fingerprint
        let ext = asset.url.pathExtension.lowercased()
        let isRaw = PhotoAsset.rawExtensions.contains(ext)

        let signpostId = PerformanceSignposts.signposter.makeSignpostID()
        let signpostState = PerformanceSignposts.begin("renderPreview", id: signpostId)
        defer { PerformanceSignposts.end("renderPreview", signpostState) }

        // For grid thumbnails (fastMode), limit concurrent renders to prevent GPU overload
        if fastMode {
            await acquireGridRenderSlot()
        }
        defer {
            if fastMode {
                releaseGridRenderSlot()
            }
        }

        // RAW files: use CIRAWFilter for true RAW processing
        if isRaw {
            return await renderRAWPreview(
                for: asset,
                recipe: recipe,
                cacheKey: cacheKey,
                maxSize: maxSize,
                fastMode: fastMode,
                localNodes: localNodes
            )
        }

        // Non-RAW: use standard pipeline
        return await renderStandardPreview(
            for: asset,
            recipe: recipe,
            cacheKey: cacheKey,
            maxSize: maxSize,
            fastMode: fastMode,
            localNodes: localNodes
        )
    }
    
    /// True RAW processing - adjustments applied at RAW decode level
    private func renderRAWPreview(
        for asset: PhotoAsset,
        recipe: EditRecipe,
        cacheKey: String,
        maxSize: CGFloat,
        fastMode: Bool = false,
        localNodes: [ColorNode] = []
    ) async -> NSImage? {
        // Get or create RAW filter
        let rawFilter: CIFilter
        if let cached = rawFilterCache[cacheKey] {
            rawFilter = cached
        } else {
            guard let filter = CIFilter(imageURL: asset.url, options: nil) else {
                print("[ImagePipeline] Failed to create RAW filter for: \(asset.filename)")
                return nil
            }
            rawFilter = filter
            cacheRAWFilter(filter, for: cacheKey)
            
            // Capture "As Shot" WB defaults once, so switching back to As Shot works even with cached filters.
            // NOTE: `CIFilter(imageURL:options:)` returns an internal RAW filter (`CIRAWFilterImpl`), not `CIRAWFilter`,
            // so we capture defaults via KVC keys.
            if filter.inputKeys.contains("inputNeutralTemperature"),
               filter.inputKeys.contains("inputNeutralTint"),
               let temp = (filter.value(forKey: "inputNeutralTemperature") as? NSNumber)?.floatValue,
               let tint = (filter.value(forKey: "inputNeutralTint") as? NSNumber)?.floatValue {
                rawWhiteBalanceDefaults[cacheKey] = (temperature: temp, tint: tint)
            }
        }
        
        // Apply recipe parameters directly to RAW filter
        applyRecipeToRAWFilter(rawFilter, recipe: recipe, cacheKey: cacheKey)
        
        // Get output from RAW filter
        guard var outputImage = rawFilter.outputImage else {
            print("[ImagePipeline] RAW filter produced no output")
            return nil
        }
        
        // Scale for preview
        outputImage = scaleImage(outputImage, maxSize: maxSize)
        
        // Apply post-RAW adjustments (saturation, vibrance, crop, etc.)
        outputImage = applyPostRAWRecipe(recipe, to: outputImage, fastMode: fastMode)

        // Apply local node adjustments if any
        if !localNodes.isEmpty {
            outputImage = await renderLocalNodes(localNodes, baseImage: outputImage, originalImage: outputImage, fastMode: fastMode)
        }

        return renderToNSImage(outputImage)
    }
    
    /// Standard pipeline for non-RAW images
    private func renderStandardPreview(
        for asset: PhotoAsset,
        recipe: EditRecipe,
        cacheKey: String,
        maxSize: CGFloat,
        fastMode: Bool = false,
        localNodes: [ColorNode] = []
    ) async -> NSImage? {
        var baseImage: CIImage
        if let cached = imageCache[cacheKey] {
            baseImage = cached
        } else {
            guard let loaded = await loadImage(from: asset.url) else {
                return nil
            }
            baseImage = scaleImage(loaded, maxSize: maxSize)
            cacheImage(baseImage, for: cacheKey)
        }
        
        var processedImage = applyFullRecipe(recipe, to: baseImage, fastMode: fastMode)

        // Apply local node adjustments if any
        if !localNodes.isEmpty {
            processedImage = await renderLocalNodes(localNodes, baseImage: processedImage, originalImage: baseImage, fastMode: fastMode)
        }

        return renderToNSImage(processedImage)
    }
    
    /// Apply recipe parameters to RAW filter (true RAW adjustment)
    private func applyRecipeToRAWFilter(_ filter: CIFilter, recipe: EditRecipe, cacheKey: String? = nil) {
        // Exposure: Use RAW exposure value directly
        // CIRAWFilter uses EV adjustment
        filter.setValue(recipe.exposure, forKey: kCIInputEVKey)
        
        // NOTE: `CIFilter(imageURL:options:)` returns an internal `CIRAWFilterImpl` (not `CIRAWFilter`),
        // so drive RAW params via KVC keys instead of type-casting.
        
        // Shadow boost (RAW-level)
        if filter.inputKeys.contains("inputBoostShadowAmount") {
            // Map -100..100 to 0..1 (existing behavior: only lifts shadows)
            let shadowBoost = max(0, recipe.shadows / 100.0)
            filter.setValue(shadowBoost, forKey: "inputBoostShadowAmount")
        }
        
        // White balance (RAW-level)
        if filter.inputKeys.contains("inputNeutralTemperature"),
           filter.inputKeys.contains("inputNeutralTint") {
            if recipe.whiteBalance.hasEdits {
                filter.setValue(Float(recipe.whiteBalance.temperature), forKey: "inputNeutralTemperature")
                filter.setValue(Float(recipe.whiteBalance.tint), forKey: "inputNeutralTint")
            } else if let cacheKey, let defaults = rawWhiteBalanceDefaults[cacheKey] {
                // Important: cached RAW filters retain previous WB overrides unless we explicitly restore defaults.
                filter.setValue(defaults.temperature, forKey: "inputNeutralTemperature")
                filter.setValue(defaults.tint, forKey: "inputNeutralTint")
            }
        }
    }
    
    /// Post-RAW adjustments (contrast, vibrance, saturation, crop)
    /// - Parameters:
    ///   - recipe: Edit recipe to apply
    ///   - image: Input CIImage
    ///   - fastMode: Skip expensive filters for responsive scrubbing
    private func applyPostRAWRecipe(_ recipe: EditRecipe, to image: CIImage, fastMode: Bool = false) -> CIImage {
        var result = image

        // Apply camera profile (v1.2) - base look BEFORE user adjustments
        // Pipeline order: RAW Decode → Camera Profile → User Adjustments → Display Transform
        let profile = BuiltInProfile.profile(for: recipe.profileId) ?? BuiltInProfile.neutral.profile
        result = applyCameraProfile(profile, to: result)

        // Contrast - Enhanced S-curve for more natural, punchy contrast
        if recipe.contrast != 0 {
            result = applyEnhancedContrast(recipe.contrast, to: result)
        }
        
        // Highlights and Shadows - Enhanced with stronger effect
        if recipe.highlights != 0 || recipe.shadows != 0 {
            result = applyEnhancedHighlightsShadows(
                highlights: recipe.highlights,
                shadows: recipe.shadows,
                to: result
            )
        }
        
        // Vibrance
        if recipe.vibrance != 0 {
            let filter = CIFilter.vibrance()
            filter.inputImage = result
            filter.amount = Float(recipe.vibrance / 100.0)
            result = filter.outputImage ?? result
        }
        
        // Saturation
        if recipe.saturation != 0 {
            let filter = CIFilter.colorControls()
            filter.inputImage = result
            filter.saturation = Float(1.0 + recipe.saturation / 100.0)
            result = filter.outputImage ?? result
        }
        
        // Whites and Blacks (gamma approximation)
        if recipe.whites != 0 || recipe.blacks != 0 {
            let filter = CIFilter.gammaAdjust()
            filter.inputImage = result
            let gammaAdjust = 1.0 + (recipe.blacks - recipe.whites) / 200.0
            filter.power = Float(max(0.5, min(2.0, gammaAdjust)))
            result = filter.outputImage ?? result
        }
        
        // Rotation (90° + straighten + flips)
        result = applyRotation(recipe.crop, to: result)

        // Crop
        result = applyCrop(recipe.crop, to: result)

        // Tone Curve (luminance curve)
        if recipe.toneCurve.hasEdits {
            result = applyToneCurve(recipe.toneCurve, to: result)
        }

        // RGB Curves (per-channel)
        if recipe.rgbCurves.hasEdits {
            result = applyRGBCurves(recipe.rgbCurves, to: result)
        }

        // Vignette - skip in fast mode
        if recipe.vignette.hasEffect && !fastMode {
            result = applyVignette(recipe.vignette, to: result)
        }

        // Split Toning
        if recipe.splitToning.hasEffect {
            result = applySplitToning(recipe.splitToning, to: result)
        }

        // Sharpness
        if recipe.sharpness > 0 {
            let filter = CIFilter.sharpenLuminance()
            filter.inputImage = result
            filter.sharpness = Float(recipe.sharpness / 100.0 * 2.0)
            result = filter.outputImage ?? result
        }

        // Noise Reduction - skip in fast mode (expensive)
        if recipe.noiseReduction > 0 && !fastMode {
            let filter = CIFilter.noiseReduction()
            filter.inputImage = result
            filter.noiseLevel = Float(recipe.noiseReduction / 100.0 * 0.05)
            filter.sharpness = 0.4
            result = filter.outputImage ?? result
        }

        // HSL Adjustment - skip in fast mode (expensive)
        if recipe.hsl.hasEdits && !fastMode {
            result = applyHSL(recipe.hsl, to: result)
        }

        // Clarity - skip in fast mode (very expensive)
        if recipe.clarity != 0 && !fastMode {
            result = applyClarity(recipe.clarity, to: result)
        }

        // Dehaze - skip in fast mode (very expensive)
        if recipe.dehaze != 0 && !fastMode {
            result = applyDehaze(recipe.dehaze, to: result)
        }

        // Texture - skip in fast mode (expensive)
        if recipe.texture != 0 && !fastMode {
            result = applyTexture(recipe.texture, to: result)
        }

        // Grain - skip in fast mode
        if recipe.grain.hasEffect && !fastMode {
            result = applyGrain(recipe.grain, to: result)
        }

        // Chromatic Aberration Fix
        if recipe.chromaticAberration.hasEffect {
            result = fixChromaticAberration(recipe.chromaticAberration, to: result)
        }

        // Perspective Correction (Transform)
        if recipe.perspective.hasEdits {
            result = applyPerspective(recipe.perspective, to: result)
        }

        // Camera Calibration
        if recipe.calibration.hasEdits {
            result = applyCalibration(recipe.calibration, to: result)
        }

        return result
    }

    /// Apply all rotation transforms (90° increments, straighten, flips)
    private func applyRotation(_ crop: Crop, to image: CIImage) -> CIImage {
        var result = image

        // 1. Apply 90° rotation
        if crop.rotationDegrees != 0 {
            let radians = CGFloat(crop.rotationDegrees) * .pi / 180.0
            result = result.transformed(by: CGAffineTransform(rotationAngle: radians))
        }

        // 2. Apply straighten angle (fine rotation around center)
        if crop.straightenAngle != 0 {
            let radians = CGFloat(crop.straightenAngle) * .pi / 180.0
            let center = CGPoint(x: result.extent.midX, y: result.extent.midY)
            let transform = CGAffineTransform(translationX: center.x, y: center.y)
                .rotated(by: radians)
                .translatedBy(x: -center.x, y: -center.y)
            result = result.transformed(by: transform)
        }

        // 3. Apply flips
        if crop.flipHorizontal {
            let center = CGPoint(x: result.extent.midX, y: result.extent.midY)
            let transform = CGAffineTransform(translationX: center.x, y: center.y)
                .scaledBy(x: -1, y: 1)
                .translatedBy(x: -center.x, y: -center.y)
            result = result.transformed(by: transform)
        }
        if crop.flipVertical {
            let center = CGPoint(x: result.extent.midX, y: result.extent.midY)
            let transform = CGAffineTransform(translationX: center.x, y: center.y)
                .scaledBy(x: 1, y: -1)
                .translatedBy(x: -center.x, y: -center.y)
            result = result.transformed(by: transform)
        }

        return result
    }

    /// Apply normalized crop rect (top-left origin) to CIImage (bottom-left origin).
    private func applyCrop(_ crop: Crop, to image: CIImage) -> CIImage {
        guard crop.isEnabled else { return image }

        let extent = image.extent
        let x = max(0, min(0.99, crop.rect.x))
        let y = max(0, min(0.99, crop.rect.y))
        let w = max(0.01, min(1 - x, crop.rect.w))
        let h = max(0.01, min(1 - y, crop.rect.h))

        let cropRect = CGRect(
            x: extent.origin.x + extent.width * x,
            y: extent.origin.y + extent.height * (1 - y - h),
            width: extent.width * w,
            height: extent.height * h
        )

        return image.cropped(to: cropRect)
    }

    /// Apply resize settings to image (used at export time)
    /// - Parameters:
    ///   - resize: Resize settings from recipe
    ///   - image: Input CIImage
    ///   - originalSize: Original image dimensions for percentage/edge calculations
    /// - Returns: Resized CIImage
    func applyResize(_ resize: Resize, to image: CIImage, originalSize: CGSize? = nil) -> CIImage {
        guard resize.hasEffect else { return image }

        let extent = image.extent
        let currentWidth = extent.width
        let currentHeight = extent.height
        let sourceSize = originalSize ?? CGSize(width: currentWidth, height: currentHeight)

        var targetWidth: CGFloat = currentWidth
        var targetHeight: CGFloat = currentHeight

        switch resize.mode {
        case .pixels:
            if resize.width > 0 && resize.height > 0 {
                targetWidth = CGFloat(resize.width)
                targetHeight = CGFloat(resize.height)
            } else if resize.width > 0 {
                // Auto-calculate height maintaining aspect ratio
                targetWidth = CGFloat(resize.width)
                targetHeight = targetWidth * currentHeight / currentWidth
            } else if resize.height > 0 {
                // Auto-calculate width maintaining aspect ratio
                targetHeight = CGFloat(resize.height)
                targetWidth = targetHeight * currentWidth / currentHeight
            }

        case .percentage:
            let scale = resize.percentage / 100.0
            targetWidth = sourceSize.width * CGFloat(scale)
            targetHeight = sourceSize.height * CGFloat(scale)

        case .preset:
            if let dims = resize.preset.dimensions {
                targetWidth = CGFloat(dims.width)
                targetHeight = CGFloat(dims.height)
            }

        case .longEdge:
            guard resize.longEdge > 0 else { return image }
            let longEdge = CGFloat(resize.longEdge)
            if currentWidth >= currentHeight {
                targetWidth = longEdge
                targetHeight = longEdge * currentHeight / currentWidth
            } else {
                targetHeight = longEdge
                targetWidth = longEdge * currentWidth / currentHeight
            }

        case .shortEdge:
            guard resize.shortEdge > 0 else { return image }
            let shortEdge = CGFloat(resize.shortEdge)
            if currentWidth <= currentHeight {
                targetWidth = shortEdge
                targetHeight = shortEdge * currentHeight / currentWidth
            } else {
                targetHeight = shortEdge
                targetWidth = shortEdge * currentWidth / currentHeight
            }
        }

        // Apply scaling
        let scaleX = targetWidth / currentWidth
        let scaleY = targetHeight / currentHeight

        // Use Lanczos for high-quality resizing
        let filter = CIFilter.lanczosScaleTransform()
        filter.inputImage = image
        filter.scale = Float(min(scaleX, scaleY))  // Use uniform scale if maintaining aspect
        filter.aspectRatio = resize.maintainAspectRatio ? 1.0 : Float(scaleX / scaleY)

        return filter.outputImage ?? image
    }

    /// Full recipe for non-RAW images
    private func applyFullRecipe(_ recipe: EditRecipe, to image: CIImage, fastMode: Bool = false) -> CIImage {
        var result = image

        // Apply camera profile (v1.2) - base look BEFORE user adjustments
        // Pipeline order: Camera Profile → User Adjustments → Display Transform
        let profile = BuiltInProfile.profile(for: recipe.profileId) ?? BuiltInProfile.neutral.profile
        result = applyCameraProfile(profile, to: result)

        // Exposure
        if recipe.exposure != 0 {
            let filter = CIFilter.exposureAdjust()
            filter.inputImage = result
            filter.ev = Float(recipe.exposure)
            result = filter.outputImage ?? result
        }
        
        // Contrast
        if recipe.contrast != 0 {
            let filter = CIFilter.colorControls()
            filter.inputImage = result
            filter.contrast = Float(1.0 + recipe.contrast / 100.0 * 0.5)
            result = filter.outputImage ?? result
        }
        
        // Highlights and Shadows
        if recipe.highlights != 0 || recipe.shadows != 0 {
            let filter = CIFilter.highlightShadowAdjust()
            filter.inputImage = result
            filter.highlightAmount = Float(1.0 - recipe.highlights / 100.0)
            filter.shadowAmount = Float(recipe.shadows / 100.0)
            result = filter.outputImage ?? result
        }
        
        // White Balance (Temperature and Tint)
        if recipe.whiteBalance.hasEdits {
            let filter = CIFilter.temperatureAndTint()
            filter.inputImage = result
            filter.neutral = CIVector(x: 6500, y: 0)
            filter.targetNeutral = CIVector(
                x: CGFloat(recipe.whiteBalance.temperature),
                y: CGFloat(recipe.whiteBalance.tint)
            )
            result = filter.outputImage ?? result
        }
        
        // Vibrance
        if recipe.vibrance != 0 {
            let filter = CIFilter.vibrance()
            filter.inputImage = result
            filter.amount = Float(recipe.vibrance / 100.0)
            result = filter.outputImage ?? result
        }
        
        // Saturation
        if recipe.saturation != 0 {
            let filter = CIFilter.colorControls()
            filter.inputImage = result
            filter.saturation = Float(1.0 + recipe.saturation / 100.0)
            result = filter.outputImage ?? result
        }
        
        // Whites and Blacks
        if recipe.whites != 0 || recipe.blacks != 0 {
            let filter = CIFilter.gammaAdjust()
            filter.inputImage = result
            let gammaAdjust = 1.0 + (recipe.blacks - recipe.whites) / 200.0
            filter.power = Float(max(0.5, min(2.0, gammaAdjust)))
            result = filter.outputImage ?? result
        }
        
        // Rotation (90° + straighten + flips)
        result = applyRotation(recipe.crop, to: result)

        // Crop
        result = applyCrop(recipe.crop, to: result)

        // === P0 ADVANCED EFFECTS ===
        
        // Tone Curve (luminance curve)
        if recipe.toneCurve.hasEdits {
            result = applyToneCurve(recipe.toneCurve, to: result)
        }
        
        // RGB Curves (per-channel)
        if recipe.rgbCurves.hasEdits {
            result = applyRGBCurves(recipe.rgbCurves, to: result)
        }
        
        // Vignette - skip in fast mode
        if recipe.vignette.hasEffect && !fastMode {
            result = applyVignette(recipe.vignette, to: result)
        }
        
        // Split Toning
        if recipe.splitToning.hasEffect {
            result = applySplitToning(recipe.splitToning, to: result)
        }
        
        // Sharpness
        if recipe.sharpness > 0 {
            let filter = CIFilter.sharpenLuminance()
            filter.inputImage = result
            filter.sharpness = Float(recipe.sharpness / 100.0 * 2.0)
            result = filter.outputImage ?? result
        }
        
        // Noise Reduction - skip in fast mode (expensive)
        if recipe.noiseReduction > 0 && !fastMode {
            let filter = CIFilter.noiseReduction()
            filter.inputImage = result
            filter.noiseLevel = Float(recipe.noiseReduction / 100.0 * 0.05)
            filter.sharpness = 0.4
            result = filter.outputImage ?? result
        }
        
        // === PROFESSIONAL COLOR GRADING ===
        
        // HSL Adjustment - skip in fast mode (expensive)
        if recipe.hsl.hasEdits && !fastMode {
            result = applyHSL(recipe.hsl, to: result)
        }
        
        // Clarity - skip in fast mode (very expensive)
        if recipe.clarity != 0 && !fastMode {
            result = applyClarity(recipe.clarity, to: result)
        }
        
        // Dehaze - skip in fast mode (very expensive)
        if recipe.dehaze != 0 && !fastMode {
            result = applyDehaze(recipe.dehaze, to: result)
        }
        
        // Texture - skip in fast mode (expensive)
        if recipe.texture != 0 && !fastMode {
            result = applyTexture(recipe.texture, to: result)
        }
        
        // === NEW LIGHTROOM-COMPATIBLE EFFECTS ===
        
        // Grain - skip in fast mode
        if recipe.grain.hasEffect && !fastMode {
            result = applyGrain(recipe.grain, to: result)
        }
        
        // Chromatic Aberration Fix
        if recipe.chromaticAberration.hasEffect {
            result = fixChromaticAberration(recipe.chromaticAberration, to: result)
        }
        
        // Perspective Correction
        if recipe.perspective.hasEdits {
            result = applyPerspective(recipe.perspective, to: result)
        }
        
        // Camera Calibration
        if recipe.calibration.hasEdits {
            result = applyCalibration(recipe.calibration, to: result)
        }
        
        return result
    }
    
    // MARK: - Advanced Effects Processing
    
    /// Apply tone curve (luminance)
    private func applyToneCurve(_ curve: ToneCurve, to image: CIImage) -> CIImage {
        let filter = CIFilter.toneCurve()
        filter.inputImage = image
        
        // Get 5 points from tone curve (map to CIToneCurve's fixed format)
        let points = curve.points.sorted { $0.x < $1.x }
        
        func interpolate(at x: Double) -> CGPoint {
            for i in 0..<points.count - 1 {
                if points[i].x <= x && points[i + 1].x >= x {
                    let t = (x - points[i].x) / (points[i + 1].x - points[i].x + 0.0001)
                    let y = points[i].y + t * (points[i + 1].y - points[i].y)
                    return CGPoint(x: x, y: y)
                }
            }
            return CGPoint(x: x, y: x)
        }
        
        filter.point0 = interpolate(at: 0.0)
        filter.point1 = interpolate(at: 0.25)
        filter.point2 = interpolate(at: 0.5)
        filter.point3 = interpolate(at: 0.75)
        filter.point4 = interpolate(at: 1.0)
        
        return filter.outputImage ?? image
    }
    
    /// Apply RGB curves per-channel
    private func applyRGBCurves(_ curves: RGBCurves, to image: CIImage) -> CIImage {
        var result = image
        
        // Apply master curve
        if curves.master.count >= 2 {
            result = applySingleCurve(curves.master, to: result)
        }
        
        // For RGB channels, we need to use color matrix or separate into channels
        // Using CIColorCube for accurate per-channel adjustment
        if curves.red != [CurvePoint(x: 0, y: 0), CurvePoint(x: 1, y: 1)] ||
           curves.green != [CurvePoint(x: 0, y: 0), CurvePoint(x: 1, y: 1)] ||
           curves.blue != [CurvePoint(x: 0, y: 0), CurvePoint(x: 1, y: 1)] {
            result = applyColorCurves(curves, to: result)
        }
        
        return result
    }
    
    /// Apply single luminance curve
    private func applySingleCurve(_ points: [CurvePoint], to image: CIImage) -> CIImage {
        guard points.count >= 2 else { return image }
        
        let filter = CIFilter.toneCurve()
        filter.inputImage = image
        
        // Map curve points to CIToneCurve's 5-point format
        let sortedPoints = points.sorted { $0.x < $1.x }
        
        // Interpolate to 5 fixed points: 0, 0.25, 0.5, 0.75, 1.0
        filter.point0 = interpolateCurve(at: 0.0, points: sortedPoints)
        filter.point1 = interpolateCurve(at: 0.25, points: sortedPoints)
        filter.point2 = interpolateCurve(at: 0.5, points: sortedPoints)
        filter.point3 = interpolateCurve(at: 0.75, points: sortedPoints)
        filter.point4 = interpolateCurve(at: 1.0, points: sortedPoints)
        
        return filter.outputImage ?? image
    }
    
    /// Interpolate curve value at given x
    private func interpolateCurve(at x: Double, points: [CurvePoint]) -> CGPoint {
        guard points.count >= 2 else { return CGPoint(x: x, y: x) }
        
        // Find surrounding points
        var lower = points.first!
        var upper = points.last!
        
        for i in 0..<points.count-1 {
            if points[i].x <= x && points[i+1].x >= x {
                lower = points[i]
                upper = points[i+1]
                break
            }
        }
        
        // Linear interpolation
        let t = upper.x == lower.x ? 0 : (x - lower.x) / (upper.x - lower.x)
        let y = lower.y + t * (upper.y - lower.y)
        
        return CGPoint(x: x, y: y)
    }
    
    /// Apply per-channel color curves using lookup table
    private func applyColorCurves(_ curves: RGBCurves, to image: CIImage) -> CIImage {
        // Create 1D lookup tables for each channel
        let size = 64
        var cubeData = [Float](repeating: 0, count: size * size * size * 4)
        
        for b in 0..<size {
            for g in 0..<size {
                for r in 0..<size {
                    let rNorm = Float(r) / Float(size - 1)
                    let gNorm = Float(g) / Float(size - 1)
                    let bNorm = Float(b) / Float(size - 1)
                    
                    // Apply curves
                    let rOut = Float(interpolateCurveValue(at: Double(rNorm), points: curves.red))
                    let gOut = Float(interpolateCurveValue(at: Double(gNorm), points: curves.green))
                    let bOut = Float(interpolateCurveValue(at: Double(bNorm), points: curves.blue))
                    
                    let offset = (b * size * size + g * size + r) * 4
                    cubeData[offset] = rOut
                    cubeData[offset + 1] = gOut
                    cubeData[offset + 2] = bOut
                    cubeData[offset + 3] = 1.0
                }
            }
        }
        
        let data = Data(bytes: cubeData, count: cubeData.count * 4)
        
        guard let filter = CIFilter(name: "CIColorCubeWithColorSpace") else {
            return image
        }
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(size, forKey: "inputCubeDimension")
        filter.setValue(data, forKey: "inputCubeData")
        filter.setValue(CGColorSpaceCreateDeviceRGB(), forKey: "inputColorSpace")
        
        return filter.outputImage ?? image
    }
    
    /// Interpolate curve value
    private func interpolateCurveValue(at x: Double, points: [CurvePoint]) -> Double {
        guard points.count >= 2 else { return x }
        
        let sorted = points.sorted { $0.x < $1.x }
        
        for i in 0..<sorted.count-1 {
            if sorted[i].x <= x && sorted[i+1].x >= x {
                let t = sorted[i+1].x == sorted[i].x ? 0 : (x - sorted[i].x) / (sorted[i+1].x - sorted[i].x)
                return sorted[i].y + t * (sorted[i+1].y - sorted[i].y)
            }
        }
        
        return x
    }
    
    /// Apply vignette effect
    private func applyVignette(_ vignette: Vignette, to image: CIImage) -> CIImage {
        let filter = CIFilter.vignette()
        filter.inputImage = image
        
        // Map amount -100..100 to intensity 0..2 (negative = lighten center = same as reverse)
        filter.intensity = Float(abs(vignette.amount) / 100.0 * 2.0)
        
        // Map midpoint and feather to radius
        filter.radius = Float(vignette.midpoint / 100.0 * 2.0)
        
        return filter.outputImage ?? image
    }
    
    /// Apply split toning
    private func applySplitToning(_ toning: SplitToning, to image: CIImage) -> CIImage {
        // Use color polynomial for split toning effect
        // This is a simplified version - full implementation would need custom kernel
        
        guard let filter = CIFilter(name: "CIColorPolynomial") else {
            return image
        }
        
        // Convert hue to RGB components
        let shadowColor = hueToRGB(hue: toning.shadowHue, saturation: toning.shadowSaturation / 100.0)

        // Balance affects mix of highlight vs shadow. Current implementation applies shadow toning only.
        let shadowMix = 0.5 - toning.balance / 200.0     // 0-1
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: CGFloat(shadowColor.0 * shadowMix * 0.1), y: 0, z: 0, w: 1), forKey: "inputRedCoefficients")
        filter.setValue(CIVector(x: CGFloat(shadowColor.1 * shadowMix * 0.1), y: 0, z: 0, w: 1), forKey: "inputGreenCoefficients")
        filter.setValue(CIVector(x: CGFloat(shadowColor.2 * shadowMix * 0.1), y: 0, z: 0, w: 1), forKey: "inputBlueCoefficients")
        
        return filter.outputImage ?? image
    }
    
    /// Convert hue (0-360) to RGB
    private func hueToRGB(hue: Double, saturation: Double) -> (Double, Double, Double) {
        let h = hue / 60.0
        let c = saturation
        let x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1))
        
        var r = 0.0, g = 0.0, b = 0.0
        
        switch Int(h) {
        case 0: (r, g, b) = (c, x, 0)
        case 1: (r, g, b) = (x, c, 0)
        case 2: (r, g, b) = (0, c, x)
        case 3: (r, g, b) = (0, x, c)
        case 4: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        
        return (r, g, b)
    }
    
    // MARK: - Professional Color Grading
    
    /// Apply HSL adjustment per color channel
    private func applyHSL(_ hsl: HSLAdjustment, to image: CIImage) -> CIImage {
        // Use CIColorCube to create a 3D LUT for HSL adjustments
        let size = 32  // 32x32x32 cube
        var cubeData = [Float](repeating: 0, count: size * size * size * 4)
        
        for b in 0..<size {
            for g in 0..<size {
                for r in 0..<size {
                    let rNorm = Double(r) / Double(size - 1)
                    let gNorm = Double(g) / Double(size - 1)
                    let bNorm = Double(b) / Double(size - 1)
                    
                    // Convert RGB to HSL
                    let (h, s, l) = rgbToHSL(r: rNorm, g: gNorm, b: bNorm)
                    
                    // Calculate adjustment based on hue
                    let (hAdj, sAdj, lAdj) = getHSLAdjustment(hsl: hsl, hue: h)
                    
                    // Apply adjustments
                    var newH = h + hAdj * 30.0 / 360.0  // ±30 degree shift at ±100
                    var newS = s * (1.0 + sAdj / 100.0)
                    var newL = l * (1.0 + lAdj / 100.0)
                    
                    // Clamp values
                    newH = newH.truncatingRemainder(dividingBy: 1.0)
                    if newH < 0 { newH += 1.0 }
                    newS = max(0, min(1, newS))
                    newL = max(0, min(1, newL))
                    
                    // Convert back to RGB
                    let (rOut, gOut, bOut) = hslToRGB(h: newH, s: newS, l: newL)
                    
                    let offset = (b * size * size + g * size + r) * 4
                    cubeData[offset] = Float(rOut)
                    cubeData[offset + 1] = Float(gOut)
                    cubeData[offset + 2] = Float(bOut)
                    cubeData[offset + 3] = 1.0
                }
            }
        }
        
        let data = Data(bytes: cubeData, count: cubeData.count * 4)
        
        guard let filter = CIFilter(name: "CIColorCubeWithColorSpace") else {
            return image
        }
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(size, forKey: "inputCubeDimension")
        filter.setValue(data, forKey: "inputCubeData")
        filter.setValue(CGColorSpaceCreateDeviceRGB(), forKey: "inputColorSpace")
        
        return filter.outputImage ?? image
    }
    
    /// Get HSL adjustment values based on pixel hue
    private func getHSLAdjustment(hsl: HSLAdjustment, hue: Double) -> (h: Double, s: Double, l: Double) {
        let hueDeg = hue * 360.0
        
        // Calculate weights for each channel based on hue distance
        func weight(targetHue: Double, range: Double = 30.0) -> Double {
            var diff = abs(hueDeg - targetHue)
            if diff > 180 { diff = 360 - diff }
            return max(0, 1.0 - diff / range)
        }
        
        // Weighted sum of all channels
        var totalH = 0.0, totalS = 0.0, totalL = 0.0
        var totalWeight = 0.0
        
        for (_, channel, center) in hsl.allChannels {
            let w = weight(targetHue: center)
            if w > 0 {
                totalH += channel.hue * w
                totalS += channel.saturation * w
                totalL += channel.luminance * w
                totalWeight += w
            }
        }
        
        if totalWeight > 0 {
            return (totalH / totalWeight, totalS / totalWeight, totalL / totalWeight)
        }
        return (0, 0, 0)
    }
    
    /// RGB to HSL conversion
    private func rgbToHSL(r: Double, g: Double, b: Double) -> (h: Double, s: Double, l: Double) {
        let maxC = max(r, max(g, b))
        let minC = min(r, min(g, b))
        let l = (maxC + minC) / 2.0
        
        if maxC == minC {
            return (0, 0, l)
        }
        
        let d = maxC - minC
        let s = l > 0.5 ? d / (2.0 - maxC - minC) : d / (maxC + minC)
        
        var h: Double
        if maxC == r {
            h = (g - b) / d + (g < b ? 6 : 0)
        } else if maxC == g {
            h = (b - r) / d + 2
        } else {
            h = (r - g) / d + 4
        }
        h /= 6.0
        
        return (h, s, l)
    }
    
    /// HSL to RGB conversion
    private func hslToRGB(h: Double, s: Double, l: Double) -> (r: Double, g: Double, b: Double) {
        if s == 0 {
            return (l, l, l)
        }
        
        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q
        
        func hue2rgb(_ p: Double, _ q: Double, _ t: Double) -> Double {
            var t = t
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1/6 { return p + (q - p) * 6 * t }
            if t < 1/2 { return q }
            if t < 2/3 { return p + (q - p) * (2/3 - t) * 6 }
            return p
        }
        
        return (
            hue2rgb(p, q, h + 1/3),
            hue2rgb(p, q, h),
            hue2rgb(p, q, h - 1/3)
        )
    }
    
    /// Apply Clarity - Enhanced local contrast with multi-scale approach
    private func applyClarity(_ amount: Double, to image: CIImage) -> CIImage {
        guard amount != 0 else { return image }
        var result = image
        
        // Use multiple passes at different radii for more natural local contrast
        // Similar to Lightroom's Clarity implementation
        let absAmount = abs(amount)
        let sign = amount >= 0 ? 1.0 : -1.0
        
        // Pass 1: Large radius for overall local contrast
        let filter1 = CIFilter.unsharpMask()
        filter1.inputImage = result
        filter1.radius = 50.0
        filter1.intensity = Float(sign * absAmount / 100.0 * 0.4)
        result = filter1.outputImage ?? result
        
        // Pass 2: Medium radius for mid-tone definition
        let filter2 = CIFilter.unsharpMask()
        filter2.inputImage = result
        filter2.radius = 25.0
        filter2.intensity = Float(sign * absAmount / 100.0 * 0.3)
        result = filter2.outputImage ?? result
        
        // Pass 3: Subtle highlight/shadow adjustment to protect extremes
        if absAmount > 30 {
            let hsFilter = CIFilter.highlightShadowAdjust()
            hsFilter.inputImage = result
            hsFilter.highlightAmount = Float(1.0 + sign * absAmount / 500.0)
            hsFilter.shadowAmount = Float(sign * absAmount / 500.0)
            result = hsFilter.outputImage ?? result
        }
        
        return result
    }
    
    /// Apply Dehaze - Enhanced with dark channel prior approximation
    private func applyDehaze(_ amount: Double, to image: CIImage) -> CIImage {
        guard amount != 0 else { return image }
        var result = image
        let absAmount = abs(amount)
        let sign = amount >= 0 ? 1.0 : -1.0
        
        // Step 1: Adjust blacks/shadows to cut through haze
        let gammaFilter = CIFilter.gammaAdjust()
        gammaFilter.inputImage = result
        gammaFilter.power = Float(1.0 - sign * absAmount / 400.0)  // Lift midtones for dehaze
        result = gammaFilter.outputImage ?? result
        
        // Step 2: Increase contrast (haze reduces contrast)
        let contrastFilter = CIFilter.colorControls()
        contrastFilter.inputImage = result
        contrastFilter.contrast = Float(1.0 + sign * absAmount / 100.0 * 0.5)  // Stronger contrast
        contrastFilter.brightness = Float(-sign * absAmount / 100.0 * 0.05)  // Slight brightness cut
        result = contrastFilter.outputImage ?? result
        
        // Step 3: Boost saturation (haze desaturates)
        let satFilter = CIFilter.colorControls()
        satFilter.inputImage = result
        satFilter.saturation = Float(1.0 + sign * absAmount / 100.0 * 0.35)
        result = satFilter.outputImage ?? result
        
        // Step 4: Add clarity for local contrast punch
        if absAmount > 20 {
            result = applyClarity(sign * absAmount * 0.4, to: result)
        }
        
        // Step 5: Vibrance boost to restore color depth
        if absAmount > 30 {
            let vibranceFilter = CIFilter.vibrance()
            vibranceFilter.inputImage = result
            vibranceFilter.amount = Float(sign * absAmount / 100.0 * 0.2)
            result = vibranceFilter.outputImage ?? result
        }
        
        return result
    }
    
    /// Apply Texture - Enhanced fine detail with edge-aware sharpening
    private func applyTexture(_ amount: Double, to image: CIImage) -> CIImage {
        guard amount != 0 else { return image }
        var result = image
        let absAmount = abs(amount)
        let sign = amount >= 0 ? 1.0 : -1.0
        
        // Pass 1: Very fine detail (skin texture level)
        let filter1 = CIFilter.unsharpMask()
        filter1.inputImage = result
        filter1.radius = 1.5
        filter1.intensity = Float(sign * absAmount / 100.0 * 0.6)
        result = filter1.outputImage ?? result
        
        // Pass 2: Slightly larger for fabric/surface detail
        let filter2 = CIFilter.unsharpMask()
        filter2.inputImage = result
        filter2.radius = 4.0
        filter2.intensity = Float(sign * absAmount / 100.0 * 0.4)
        result = filter2.outputImage ?? result
        
        return result
    }
    
    // MARK: - Enhanced Adjustment Helpers
    
    /// Enhanced contrast using S-curve for more natural look
    private func applyEnhancedContrast(_ amount: Double, to image: CIImage) -> CIImage {
        guard amount != 0 else { return image }
        
        // For positive contrast: S-curve (darken shadows, brighten highlights)
        // For negative contrast: inverse S-curve (flatten)
        let strength = amount / 100.0
        
        // Use tone curve for S-curve contrast
        let filter = CIFilter.toneCurve()
        filter.inputImage = image
        
        if strength >= 0 {
            // S-curve: pull down shadows, push up highlights
            let shadowPull = 0.25 - strength * 0.15
            let highlightPush = 0.75 + strength * 0.15
            filter.point0 = CGPoint(x: 0, y: 0)
            filter.point1 = CGPoint(x: 0.25, y: shadowPull)
            filter.point2 = CGPoint(x: 0.5, y: 0.5)
            filter.point3 = CGPoint(x: 0.75, y: highlightPush)
            filter.point4 = CGPoint(x: 1, y: 1)
        } else {
            // Inverse S-curve: flatten contrast
            let absStrength = abs(strength)
            let shadowLift = 0.25 + absStrength * 0.12
            let highlightDrop = 0.75 - absStrength * 0.12
            filter.point0 = CGPoint(x: 0, y: absStrength * 0.1)
            filter.point1 = CGPoint(x: 0.25, y: shadowLift)
            filter.point2 = CGPoint(x: 0.5, y: 0.5)
            filter.point3 = CGPoint(x: 0.75, y: highlightDrop)
            filter.point4 = CGPoint(x: 1, y: 1 - absStrength * 0.1)
        }
        
        return filter.outputImage ?? image
    }
    
    /// Enhanced highlights and shadows with stronger, more natural effect
    private func applyEnhancedHighlightsShadows(highlights: Double, shadows: Double, to image: CIImage) -> CIImage {
        var result = image
        
        // Use CIHighlightShadowAdjust with amplified values
        let hsFilter = CIFilter.highlightShadowAdjust()
        hsFilter.inputImage = result
        
        // Highlights: -100 to +100 maps to 0 to 2 (1 is neutral)
        // Negative highlights = recover/reduce brightness
        // Amplified for stronger effect (was 1.0 ± 1.0, now 1.0 ± 1.5)
        hsFilter.highlightAmount = Float(1.0 - highlights / 100.0 * 1.5)
        
        // Shadows: -100 to +100 maps to -1 to 1
        // Positive shadows = lift/brighten shadows
        // Amplified for stronger effect (was ± 1.0, now ± 1.5)
        hsFilter.shadowAmount = Float(shadows / 100.0 * 1.5)
        
        result = hsFilter.outputImage ?? result
        
        // For extreme values, add a second pass with gamma for extra punch
        if abs(highlights) > 50 || abs(shadows) > 50 {
            let gammaFilter = CIFilter.gammaAdjust()
            gammaFilter.inputImage = result
            
            // Gamma affects midtones - use subtle adjustment
            let gammaShift = (shadows - highlights) / 800.0
            gammaFilter.power = Float(1.0 + gammaShift)
            result = gammaFilter.outputImage ?? result
        }
        
        return result
    }
    
    // MARK: - Lightroom-Compatible Effects
    
    /// Apply film grain effect
    private func applyGrain(_ grain: Grain, to image: CIImage) -> CIImage {
        guard grain.hasEffect else { return image }

        let amount = max(0.0, min(1.0, grain.amount / 100.0))
        let roughness = max(0.0, min(1.0, grain.roughness / 100.0))

        // Generate deterministic-strength noise and always clamp to image extent.
        guard var noise = CIFilter(name: "CIRandomGenerator")?.outputImage else { return image }

        // Small grain = finer details; large grain = chunkier texture.
        let sizeScale = 0.35 + (1.0 - grain.size / 100.0) * 1.85
        noise = noise
            .transformed(by: CGAffineTransform(scaleX: CGFloat(sizeScale), y: CGFloat(sizeScale)))
            .cropped(to: image.extent)

        // Keep grain mostly luminance-based to avoid color breakage.
        let controls = CIFilter.colorControls()
        controls.inputImage = noise
        controls.saturation = Float(roughness * 0.45)
        controls.contrast = Float(1.0 + roughness * 0.8)
        controls.brightness = -0.5
        noise = controls.outputImage?.cropped(to: image.extent) ?? noise

        // Compress noise around middle gray and cap strength.
        let matrix = CIFilter.colorMatrix()
        matrix.inputImage = noise
        let channelStrength = Float(0.02 + amount * 0.10)
        matrix.rVector = CIVector(x: CGFloat(channelStrength), y: 0, z: 0, w: 0)
        matrix.gVector = CIVector(x: 0, y: CGFloat(channelStrength), z: 0, w: 0)
        matrix.bVector = CIVector(x: 0, y: 0, z: CGFloat(channelStrength), w: 0)
        matrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        matrix.biasVector = CIVector(x: 0.5, y: 0.5, z: 0.5, w: 0)
        noise = matrix.outputImage?.cropped(to: image.extent) ?? noise

        // Soft-light keeps mid-tones stable and avoids hard artifacts.
        let blend = CIFilter.softLightBlendMode()
        blend.inputImage = noise
        blend.backgroundImage = image
        guard let textured = blend.outputImage?.cropped(to: image.extent) else { return image }

        // Cross-fade by user amount.
        let dissolve = CIFilter.dissolveTransition()
        dissolve.inputImage = textured
        dissolve.targetImage = image
        dissolve.time = Float(1.0 - amount)

        return dissolve.outputImage?.cropped(to: image.extent) ?? image
    }
    
    /// Fix chromatic aberration (purple/green fringing)
    private func fixChromaticAberration(_ ca: ChromaticAberration, to image: CIImage) -> CIImage {
        guard ca.hasEffect else { return image }
        
        // Chromatic aberration fix: slightly scale R and B channels toward center
        // This is a simplified version - full implementation would use radial scaling
        let strength = ca.amount / 100.0 * 0.003  // Max 0.3% scale difference
        let center = CGPoint(x: image.extent.midX, y: image.extent.midY)
        
        // Scale red channel slightly outward and blue slightly inward
        // Using affine clamp to prevent edge artifacts
        let clamp = CIFilter.affineClamp()
        clamp.inputImage = image
        clamp.transform = CGAffineTransform.identity
        guard let clamped = clamp.outputImage else { return image }
        
        // Apply slight radial blur to reduce color fringing at edges
        // This simulates the opposite of chromatic aberration
        let zoomFilter = CIFilter.zoomBlur()
        zoomFilter.inputImage = clamped
        zoomFilter.center = center
        zoomFilter.amount = Float(strength * 20)
        
        guard let zoomed = zoomFilter.outputImage?.cropped(to: image.extent) else { return image }
        
        // Blend based on strength
        let blend = CIFilter.dissolveTransition()
        blend.inputImage = zoomed
        blend.targetImage = image
        blend.time = Float(1.0 - ca.amount / 200.0)  // Subtle effect
        
        return blend.outputImage ?? image
    }
    
    /// Apply perspective correction (keystone / transform)
    private func applyPerspective(_ p: Perspective, to image: CIImage) -> CIImage {
        guard p.hasEdits else { return image }
        
        let extent = image.extent
        
        // Start with corner points
        var tl = CGPoint(x: extent.minX, y: extent.maxY)  // top-left
        var tr = CGPoint(x: extent.maxX, y: extent.maxY)  // top-right
        var bl = CGPoint(x: extent.minX, y: extent.minY)  // bottom-left
        var br = CGPoint(x: extent.maxX, y: extent.minY)  // bottom-right
        
        // Apply vertical perspective (keystone correction)
        // Positive = correct for shooting upward (building leaning back)
        let vShift = CGFloat(p.vertical / 100.0) * extent.width * 0.15
        tl.x += vShift
        tr.x -= vShift
        bl.x -= vShift
        br.x += vShift
        
        // Apply horizontal perspective
        let hShift = CGFloat(p.horizontal / 100.0) * extent.height * 0.15
        tl.y -= hShift
        bl.y += hShift
        tr.y -= hShift
        br.y += hShift
        
        // Apply perspective transform
        let perspFilter = CIFilter.perspectiveTransform()
        perspFilter.inputImage = image
        perspFilter.topLeft = tl
        perspFilter.topRight = tr
        perspFilter.bottomLeft = bl
        perspFilter.bottomRight = br
        
        var result = perspFilter.outputImage ?? image
        
        // Apply fine rotation
        if p.rotate != 0 {
            let radians = CGFloat(p.rotate) * .pi / 180.0
            let center = CGPoint(x: result.extent.midX, y: result.extent.midY)
            let rotateTransform = CGAffineTransform(translationX: center.x, y: center.y)
                .rotated(by: radians)
                .translatedBy(x: -center.x, y: -center.y)
            result = result.transformed(by: rotateTransform)
        }
        
        // Apply scale (zoom to fill after perspective correction)
        if p.scale != 100 {
            let scaleFactor = CGFloat(p.scale / 100.0)
            let center = CGPoint(x: result.extent.midX, y: result.extent.midY)
            let scaleTransform = CGAffineTransform(translationX: center.x, y: center.y)
                .scaledBy(x: scaleFactor, y: scaleFactor)
                .translatedBy(x: -center.x, y: -center.y)
            result = result.transformed(by: scaleTransform)
        }
        
        return result
    }
    
    /// Apply camera calibration (color primary adjustments)
    private func applyCalibration(_ cal: CameraCalibration, to image: CIImage) -> CIImage {
        guard cal.hasEdits else { return image }
        
        var result = image
        
        // Shadow tint (green-magenta shift in shadows)
        if cal.shadowTint != 0 {
            // Use gamma to target shadows, then apply tint
            let gamma = CIFilter.gammaAdjust()
            gamma.inputImage = result
            gamma.power = Float(1.0 + abs(cal.shadowTint) / 200.0)
            result = gamma.outputImage ?? result
        }
        
        // Per-primary hue/saturation adjustments using color matrix
        // This is a simplified version - full implementation would isolate each primary
        if cal.redHue != 0 || cal.redSaturation != 0 ||
           cal.greenHue != 0 || cal.greenSaturation != 0 ||
           cal.blueHue != 0 || cal.blueSaturation != 0 {
            
            // Apply hue rotation based on dominant channel
            let avgHueShift = (cal.redHue + cal.greenHue + cal.blueHue) / 3.0
            if avgHueShift != 0 {
                let hueFilter = CIFilter.hueAdjust()
                hueFilter.inputImage = result
                hueFilter.angle = Float(avgHueShift / 100.0 * .pi / 6)  // Max 30 degree shift
                result = hueFilter.outputImage ?? result
            }
            
            // Apply saturation adjustment
            let avgSatShift = (cal.redSaturation + cal.greenSaturation + cal.blueSaturation) / 3.0
            if avgSatShift != 0 {
                let satFilter = CIFilter.colorControls()
                satFilter.inputImage = result
                satFilter.saturation = Float(1.0 + avgSatShift / 100.0 * 0.5)
                result = satFilter.outputImage ?? result
            }
        }
        
        return result
    }
    
    // MARK: - Export
    
    /// Render full resolution with recipe for export (true RAW)
    /// - Parameters:
    ///   - asset: Photo asset to render
    ///   - recipe: Edit recipe to apply
    ///   - maxSize: Optional export-time size override (long edge)
    ///   - useRecipeResize: Whether to apply recipe's resize settings (default: true)
    func renderForExport(
        for asset: PhotoAsset,
        recipe: EditRecipe,
        maxSize: CGFloat? = nil,
        useRecipeResize: Bool = true,
        localNodes: [ColorNode] = []
    ) async -> CGImage? {
        let ext = asset.url.pathExtension.lowercased()

        var outputImage: CIImage?
        var localNodeBaseImage: CIImage?

        if PhotoAsset.rawExtensions.contains(ext) {
            // RAW export with full quality
            guard let filter = CIFilter(imageURL: asset.url, options: nil) else {
                print("[Export] Failed to create RAW filter")
                return nil
            }
            applyRecipeToRAWFilter(filter, recipe: recipe)
            guard let rawOutput = filter.outputImage else {
                print("[Export] RAW filter produced no output")
                return nil
            }
            let postRecipe = applyPostRAWRecipe(recipe, to: rawOutput)
            outputImage = postRecipe
            localNodeBaseImage = postRecipe
        } else {
            guard let loaded = await loadImage(from: asset.url) else {
                print("[Export] Failed to load image")
                return nil
            }
            localNodeBaseImage = loaded
            outputImage = applyFullRecipe(recipe, to: loaded)
        }

        guard var image = outputImage else { return nil }

        if !localNodes.isEmpty, let originalImage = localNodeBaseImage {
            image = await renderLocalNodes(
                localNodes,
                baseImage: image,
                originalImage: originalImage
            )
        }

        // Apply recipe resize settings only when requested
        if useRecipeResize && recipe.resize.hasEffect {
            image = applyResize(recipe.resize, to: image)
        }

        // Scale if needed (export-time override)
        if let maxSize = maxSize {
            image = scaleImage(image, maxSize: maxSize)
        }

        let extent = image.extent
        return context.createCGImage(image, from: extent)
    }
    
    // MARK: - Cache Management
    
    private func cacheRAWFilter(_ filter: CIFilter, for key: String) {
        if cacheOrder.count >= maxCacheSize {
            if let oldest = cacheOrder.first {
                rawFilterCache.removeValue(forKey: oldest)
                rawWhiteBalanceDefaults.removeValue(forKey: oldest)
                imageCache.removeValue(forKey: oldest)
                cacheOrder.removeFirst()
            }
        }
        rawFilterCache[key] = filter
        cacheOrder.append(key)
    }
    
    private func cacheImage(_ image: CIImage, for key: String) {
        if cacheOrder.count >= maxCacheSize {
            if let oldest = cacheOrder.first {
                rawFilterCache.removeValue(forKey: oldest)
                rawWhiteBalanceDefaults.removeValue(forKey: oldest)
                imageCache.removeValue(forKey: oldest)
                cacheOrder.removeFirst()
            }
        }
        imageCache[key] = image
        cacheOrder.append(key)
    }
    
    func clearCache() {
        rawFilterCache.removeAll()
        rawWhiteBalanceDefaults.removeAll()
        imageCache.removeAll()
        cacheOrder.removeAll()
        profileToneCurveCache.removeAll()
        profileShoulderCache.removeAll()
    }
    
    // MARK: - Utilities
    
    private func loadImage(from url: URL) async -> CIImage? {
        if let image = CIImage(contentsOf: url) {
            return image
        }
        
        if let nsImage = NSImage(contentsOf: url),
           let tiffData = nsImage.tiffRepresentation,
           let ciImage = CIImage(data: tiffData) {
            return ciImage
        }
        
        return nil
    }
    
    private func scaleImage(_ image: CIImage, maxSize: CGFloat) -> CIImage {
        let extent = image.extent
        let scale = min(maxSize / extent.width, maxSize / extent.height, 1.0)
        
        if scale >= 1.0 {
            return image
        }
        
        return image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }
    
    private func renderToNSImage(_ ciImage: CIImage) -> NSImage? {
        let extent = ciImage.extent
        guard let cgImage = context.createCGImage(ciImage, from: extent) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: extent.width, height: extent.height))
    }
    
    // MARK: - Local Node Rendering

    /// Apply local-adjustment nodes selectively using masks.
    /// Each enabled serial node blends its adjusted result onto `baseImage`
    /// according to the node's mask, density, and invert settings.
    func renderLocalNodes(
        _ nodes: [ColorNode],
        baseImage: CIImage,
        originalImage: CIImage,
        fastMode: Bool = false
    ) async -> CIImage {
        var result = baseImage

        for node in nodes {
            // Only process enabled serial nodes
            guard node.isEnabled && node.type == .serial else { continue }

            // 1. Apply node adjustments to the original (pre-composite) image.
            // originalImage already has the camera profile applied (it is the post-profile
            // base image), so we must NOT apply the camera profile again here.
            // Force neutral profile to make the camera profile step a no-op while
            // still applying all slider adjustments (exposure, contrast, etc.).
            var localRecipe = node.adjustments
            localRecipe.profileId = BuiltInProfile.neutral.rawValue
            let adjusted = applyFullRecipe(localRecipe, to: originalImage, fastMode: fastMode)

            // 2. Build mask image
            var maskImage: CIImage
            if let mask = node.mask {
                switch mask.type {
                case .radial(let cx, let cy, let radius):
                    maskImage = createRadialMask(
                        extent: result.extent,
                        centerX: cx,
                        centerY: cy,
                        radius: radius,
                        feather: mask.feather
                    )
                case .linear(let angle, let position, let falloff):
                    maskImage = createLinearMask(
                        extent: result.extent,
                        angle: angle,
                        position: position,
                        falloff: falloff
                    )
                case .luminosity, .color:
                    // Phase 2: return full-white mask for now
                    maskImage = CIImage(color: CIColor.white).cropped(to: result.extent)
                case .brush(let data):
                    maskImage = createBrushMask(from: data, targetExtent: result.extent)
                }

                // 3. Apply density (0–100) by scaling RGB channels.
                // CIBlendWithMask reads mask luminance (RGB), not alpha,
                // so we must scale the RGB vectors — not inputAVector.
                let densityFactor = CGFloat(mask.density) / 100.0
                if let densityFilter = CIFilter(name: "CIColorMatrix") {
                    densityFilter.setValue(maskImage, forKey: kCIInputImageKey)
                    densityFilter.setValue(CIVector(x: densityFactor, y: 0, z: 0, w: 0), forKey: "inputRVector")
                    densityFilter.setValue(CIVector(x: 0, y: densityFactor, z: 0, w: 0), forKey: "inputGVector")
                    densityFilter.setValue(CIVector(x: 0, y: 0, z: densityFactor, w: 0), forKey: "inputBVector")
                    maskImage = densityFilter.outputImage ?? maskImage
                }

                // 4. Invert mask if requested
                if mask.invert {
                    let invertFilter = CIFilter.colorInvert()
                    invertFilter.inputImage = maskImage
                    maskImage = invertFilter.outputImage ?? maskImage
                }
            } else {
                // No mask → full apply (solid white)
                maskImage = CIImage(color: CIColor.white).cropped(to: result.extent)
            }

            // 5. Compute node blend result (mode + opacity) before mask gating.
            let blendedNode = blendImages(
                background: result,
                foreground: adjusted,
                mode: node.blendMode,
                opacity: node.opacity,
                mask: nil
            )

            // 6. Apply spatial mask to mix blended node back to current composite.
            let blendFilter = CIFilter.blendWithMask()
            blendFilter.inputImage = blendedNode
            blendFilter.backgroundImage = result
            blendFilter.maskImage = maskImage
            result = blendFilter.outputImage ?? result
        }

        return result
    }

    // MARK: - Node Graph Rendering

    /// Render an image using a node graph pipeline
    func renderNodeGraph(
        _ graph: NodeGraph,
        baseImage: CIImage
    ) async -> CIImage {
        var result = baseImage
        
        // Get nodes in topological order
        let sortedNodes = graph.enabledNodes
        
        for node in sortedNodes {
            // Skip input/output nodes
            guard node.type == .serial || node.type == .parallel || node.type == .lut else {
                continue
            }
            
            // Process the node
            let nodeOutput = processNode(node, input: result)
            
            // Apply blend mode and opacity
            if node.blendMode != .normal || node.opacity < 1.0 {
                result = blendImages(
                    background: result,
                    foreground: nodeOutput,
                    mode: node.blendMode,
                    opacity: node.opacity,
                    mask: node.mask
                )
            } else if let mask = node.mask {
                // Apply mask only
                result = applyMask(mask, foreground: nodeOutput, background: result)
            } else {
                result = nodeOutput
            }
        }
        
        return result
    }
    
    /// Process a single node
    private func processNode(_ node: ColorNode, input: CIImage) -> CIImage {
        switch node.type {
        case .serial, .parallel:
            return applyFullRecipe(node.adjustments, to: input)
        case .lut:
            // LUT processing (future: load .cube files)
            return input
        case .input, .output:
            return input
        }
    }
    
    /// Blend two images with blend mode
    private func blendImages(
        background: CIImage,
        foreground: CIImage,
        mode: BlendMode,
        opacity: Double,
        mask: NodeMask?
    ) -> CIImage {
        var blendedForeground = foreground
        
        // Apply mask if present
        if let mask = mask {
            blendedForeground = applyMask(mask, foreground: foreground, background: background)
        }
        
        // Apply opacity
        if opacity < 1.0 {
            let alphaFilter = CIFilter(name: "CIColorMatrix")!
            alphaFilter.setValue(blendedForeground, forKey: kCIInputImageKey)
            alphaFilter.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputRVector")
            alphaFilter.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputGVector")
            alphaFilter.setValue(CIVector(x: 0, y: 0, z: 1, w: 0), forKey: "inputBVector")
            alphaFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: CGFloat(opacity)), forKey: "inputAVector")
            blendedForeground = alphaFilter.outputImage ?? blendedForeground
        }
        
        // Apply blend mode
        if let filterName = mode.ciFilterName,
           let blendFilter = CIFilter(name: filterName) {
            blendFilter.setValue(background, forKey: kCIInputBackgroundImageKey)
            blendFilter.setValue(blendedForeground, forKey: kCIInputImageKey)
            return blendFilter.outputImage ?? foreground
        }
        
        // Normal blend: use source-over compositing
        let compositeFilter = CIFilter.sourceOverCompositing()
        compositeFilter.inputImage = blendedForeground
        compositeFilter.backgroundImage = background
        return compositeFilter.outputImage ?? foreground
    }
    
    /// Apply a mask to blend foreground/background
    private func applyMask(_ mask: NodeMask, foreground: CIImage, background: CIImage) -> CIImage {
        // Generate mask image based on type
        let maskImage: CIImage
        
        switch mask.type {
        case .luminosity(let min, let max):
            maskImage = createLuminosityMask(from: background, min: min, max: max, feather: mask.feather)
        case .color(let hue, let hueRange, let satMin):
            maskImage = createColorMask(from: background, hue: hue, hueRange: hueRange, satMin: satMin, feather: mask.feather)
        case .radial(let centerX, let centerY, let radius):
            maskImage = createRadialMask(extent: background.extent, centerX: centerX, centerY: centerY, radius: radius, feather: mask.feather)
        case .linear(let angle, let position, let falloff):
            maskImage = createLinearMask(extent: background.extent, angle: angle, position: position, falloff: falloff)
        case .brush(let data):
            maskImage = createBrushMask(from: data, targetExtent: background.extent)
        }
        
        // Invert if needed
        var finalMask = maskImage
        if mask.invert {
            let invertFilter = CIFilter.colorInvert()
            invertFilter.inputImage = maskImage
            finalMask = invertFilter.outputImage ?? maskImage
        }
        
        // Blend using mask
        let blendFilter = CIFilter.blendWithMask()
        blendFilter.inputImage = foreground
        blendFilter.backgroundImage = background
        blendFilter.maskImage = finalMask
        
        return blendFilter.outputImage ?? foreground
    }
    
    /// Create luminosity-based mask
    private func createLuminosityMask(from image: CIImage, min: Double, max: Double, feather: Double) -> CIImage {
        // Convert to grayscale for luminosity
        let grayscale = CIFilter.colorControls()
        grayscale.inputImage = image
        grayscale.saturation = 0
        
        guard let lumImage = grayscale.outputImage else { return image }
        
        // Create threshold mask using color clamp
        let clampFilter = CIFilter(name: "CIColorClamp")!
        clampFilter.setValue(lumImage, forKey: kCIInputImageKey)
        clampFilter.setValue(CIVector(x: CGFloat(min), y: CGFloat(min), z: CGFloat(min), w: 0), forKey: "inputMinComponents")
        clampFilter.setValue(CIVector(x: CGFloat(max), y: CGFloat(max), z: CGFloat(max), w: 1), forKey: "inputMaxComponents")
        
        return clampFilter.outputImage ?? lumImage
    }
    
    /// Create color-based mask (select specific hue range)
    private func createColorMask(from image: CIImage, hue: Double, hueRange: Double, satMin: Double, feather: Double) -> CIImage {
        // For now, use a simple hue-based selection via color matrix
        // Full implementation would use CIColorCube for accurate hue selection
        return image
    }
    
    /// Create radial gradient mask
    private func createRadialMask(extent: CGRect, centerX: Double, centerY: Double, radius: Double, feather: Double) -> CIImage {
        // centerX/centerY are stored in SwiftUI convention (origin top-left, Y increases downward).
        // Core Image uses bottom-left origin (Y increases upward), so Y must be flipped.
        let center = CGPoint(
            x: extent.origin.x + extent.width * CGFloat(centerX),
            y: extent.origin.y + extent.height * CGFloat(1.0 - centerY)
        )
        
        let radiusPixels = min(extent.width, extent.height) * CGFloat(radius)
        let featherPixels = radiusPixels * CGFloat(feather / 100.0)
        
        let gradient = CIFilter.radialGradient()
        gradient.center = center
        gradient.radius0 = Float(max(0, radiusPixels - featherPixels))
        gradient.radius1 = Float(radiusPixels)
        gradient.color0 = CIColor.white
        gradient.color1 = CIColor.black
        
        guard let gradientImage = gradient.outputImage else {
            return CIImage.white.cropped(to: extent)
        }
        
        return gradientImage.cropped(to: extent)
    }
    
    /// Create linear gradient mask
    ///
    /// - Parameters:
    ///   - angle: Mask band orientation in degrees.
    ///   - position: Normalized centre position in SwiftUI space (0 = top, 1 = bottom).
    ///   - falloff: Transition width percentage of shorter image dimension.
    private func createLinearMask(extent: CGRect, angle: Double, position: Double, falloff: Double) -> CIImage {
        let size = CGSize(width: extent.width, height: extent.height)
        let points = LinearMaskGeometry.gradientPoints(
            in: size,
            angle: angle,
            position: position,
            falloff: falloff
        )
        let point0 = LinearMaskGeometry.toCoreImagePoint(points.point0, extent: extent)
        let point1 = LinearMaskGeometry.toCoreImagePoint(points.point1, extent: extent)
        
        let gradient = CIFilter.linearGradient()
        gradient.point0 = point0
        gradient.point1 = point1
        gradient.color0 = CIColor.white
        gradient.color1 = CIColor.black
        
        guard let gradientImage = gradient.outputImage else {
            return CIImage.white.cropped(to: extent)
        }
        
        return gradientImage.cropped(to: extent)
    }

    /// Create a brush mask CIImage from PNG data, scaled to the target extent.
    ///
    /// - Parameters:
    ///   - data: PNG image data of the brush mask (white = affected area, black = protected).
    ///   - targetExtent: The output extent the mask should be scaled to match.
    /// - Returns: A CIImage representing the mask at the target extent,
    ///            or a solid-black fallback if the data cannot be decoded.
    func createBrushMask(from data: Data, targetExtent: CGRect) -> CIImage {
        guard let sourceImage = CIImage(data: data) else {
            // Fallback: invalid data should behave as no-op, not full-image apply.
            return CIImage(color: CIColor.black).cropped(to: targetExtent)
        }

        let sourceExtent = sourceImage.extent
        guard sourceExtent.width > 0, sourceExtent.height > 0 else {
            return CIImage(color: CIColor.black).cropped(to: targetExtent)
        }

        // CIImage(data:) loads PNG data with row 0 mapped to the lowest Y in Core Image,
        // but the brush was painted in SwiftUI (row 0 = top). Flip vertically to match.
        // The flip transform: (x, y) → (x, h - y), implemented as scale(1,-1) + translate(0, h).
        let h = sourceExtent.height
        let flipTransform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: h)
        let flipped = sourceImage.transformed(by: flipTransform)

        // Scale to match target extent using an affine transform
        let flippedExtent = flipped.extent
        let scaleX = targetExtent.width / flippedExtent.width
        let scaleY = targetExtent.height / flippedExtent.height
        let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
            .translatedBy(x: targetExtent.origin.x / scaleX, y: targetExtent.origin.y / scaleY)

        return flipped
            .transformed(by: transform)
            .cropped(to: targetExtent)
    }

    // MARK: - Camera Profile Application (v1.2)

    /// Apply camera profile base tone curve and highlight shoulder
    /// Uses cached filters to avoid allocation during slider scrubbing
    private func applyCameraProfile(_ profile: CameraProfile, to image: CIImage) -> CIImage {
        var result = image

        // 1. Apply base tone curve (cached)
        result = applyFilmicToneCurve(profile.baseToneCurve, to: result, profileId: profile.id)

        // 2. Apply highlight shoulder (roll-off, cached)
        if profile.highlightShoulder.hasEffect {
            result = applyHighlightShoulder(profile.highlightShoulder, to: result, profileId: profile.id)
        }

        // 3. Apply profile look (saturation/contrast boost)
        if let look = profile.look {
            result = applyProfileLook(look, to: result)
        }

        return result
    }

    /// Apply filmic tone curve using CIToneCurve
    /// - Parameters:
    ///   - curve: The tone curve to apply
    ///   - image: Input image
    ///   - profileId: Optional profile ID for filter caching (improves scrubbing performance)
    private func applyFilmicToneCurve(_ curve: FilmicToneCurve, to image: CIImage, profileId: String? = nil) -> CIImage {
        guard curve.hasEdits else { return image }

        // Use cached filter if available (avoids allocation during scrubbing)
        let filter: CIFilter
        if let profileId = profileId, let cached = profileToneCurveCache[profileId] {
            filter = cached
        } else {
            // CIToneCurve requires exactly 5 points
            // Interpolate our 6 points to 5 for the filter
            let points = curve.points
            let p0 = points.first ?? CurvePoint(x: 0, y: 0)
            let p4 = points.last ?? CurvePoint(x: 1, y: 1)

            // Find points closest to 0.25, 0.5, 0.75
            let p1 = points.first { $0.x >= 0.15 && $0.x <= 0.35 } ?? CurvePoint(x: 0.25, y: 0.25)
            let p2 = points.first { $0.x >= 0.4 && $0.x <= 0.6 } ?? CurvePoint(x: 0.5, y: 0.5)
            let p3 = points.first { $0.x >= 0.7 && $0.x <= 0.9 } ?? CurvePoint(x: 0.75, y: 0.75)

            let newFilter = CIFilter.toneCurve()
            newFilter.point0 = CGPoint(x: p0.x, y: p0.y)
            newFilter.point1 = CGPoint(x: p1.x, y: p1.y)
            newFilter.point2 = CGPoint(x: p2.x, y: p2.y)
            newFilter.point3 = CGPoint(x: p3.x, y: p3.y)
            newFilter.point4 = CGPoint(x: p4.x, y: p4.y)

            if let profileId = profileId {
                profileToneCurveCache[profileId] = newFilter
            }
            filter = newFilter
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        return filter.outputImage ?? image
    }

    /// Apply highlight shoulder (soft roll-off to prevent clipping)
    /// - Parameters:
    ///   - shoulder: Highlight shoulder parameters
    ///   - image: Input image
    ///   - profileId: Optional profile ID for filter caching (improves scrubbing performance)
    private func applyHighlightShoulder(_ shoulder: HighlightShoulder, to image: CIImage, profileId: String? = nil) -> CIImage {
        // Use cached filter if available (avoids allocation during scrubbing)
        let filter: CIFilter
        if let profileId = profileId, let cached = profileShoulderCache[profileId] {
            filter = cached
        } else {
            let knee = shoulder.knee
            let whitePoint = shoulder.whitePoint
            let softness = shoulder.softness

            // Create monotonic shoulder curve:
            // - Linear from 0 to knee point
            // - Smooth roll-off from knee to whitePoint
            // Softness affects how early the roll-off begins (lower midpoint)
            let newFilter = CIFilter.toneCurve()
            newFilter.point0 = CGPoint(x: 0, y: 0)
            newFilter.point1 = CGPoint(x: 0.25, y: 0.25)
            // Softness pulls midpoint slightly down to start roll-off earlier
            newFilter.point2 = CGPoint(x: 0.5, y: 0.5 - softness * 0.03)
            // Knee point stays on y=x line to ensure monotonicity
            newFilter.point3 = CGPoint(x: knee, y: knee)
            // Final point compresses highlights to whitePoint
            newFilter.point4 = CGPoint(x: 1.0, y: whitePoint)

            if let profileId = profileId {
                profileShoulderCache[profileId] = newFilter
            }
            filter = newFilter
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        return filter.outputImage ?? image
    }

    /// Apply profile look adjustments
    private func applyProfileLook(_ look: ProfileLook, to image: CIImage) -> CIImage {
        var result = image

        // Apply saturation boost
        if look.saturationBoost != 0 {
            let filter = CIFilter.colorControls()
            filter.inputImage = result
            filter.saturation = Float(1.0 + look.saturationBoost)
            result = filter.outputImage ?? result
        }

        // Apply contrast boost using simple S-curve
        if look.contrastBoost != 0 {
            let filter = CIFilter.colorControls()
            filter.inputImage = result
            filter.contrast = Float(1.0 + look.contrastBoost * 0.5)
            result = filter.outputImage ?? result
        }

        // Apply warmth shift (temperature adjustment)
        if look.warmthShift != 0 {
            let filter = CIFilter.temperatureAndTint()
            filter.inputImage = result
            // Warmth: positive = warmer (higher temp), negative = cooler
            filter.neutral = CIVector(x: 6500 + CGFloat(look.warmthShift * 1000), y: 0)
            filter.targetNeutral = CIVector(x: 6500, y: 0)
            result = filter.outputImage ?? result
        }

        return result
    }
}
