//
//  ImagePipelineRegressionTests.swift
//  rawctlTests
//
//  Real image-processing regression coverage:
//  - adjustment correctness
//  - crop coordinate correctness
//  - fast-vs-full render responsiveness
//

import AppKit
import Foundation
import Testing
@testable import Latent

struct ImagePipelineRegressionTests {

    private enum TestError: Error {
        case bitmapContextCreationFailed
        case imageEncodingFailed
        case imageRenderFailed
    }

    @Test func exposureAdjustmentBrightensRenderedOutput() async throws {
        let fm = FileManager.default
        let dir = try makeTempDirectory(prefix: "rawctl-pipeline-exposure")
        defer { try? fm.removeItem(at: dir) }

        let imageURL = dir.appendingPathComponent("uniform-gray.png")
        try writePNG(at: imageURL, width: 320, height: 240) { context, width, height in
            context.setFillColor(NSColor(calibratedRed: 0.25, green: 0.25, blue: 0.25, alpha: 1.0).cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }

        let asset = PhotoAsset(url: imageURL)
        var exposed = EditRecipe()
        exposed.exposure = 1.5

        await ImagePipeline.shared.clearCache()
        guard let baselineImage = await ImagePipeline.shared.renderForExport(
            for: asset,
            context: makeContext(asset: asset)
        ) else {
            throw TestError.imageRenderFailed
        }
        await ImagePipeline.shared.clearCache()
        guard let exposedImage = await ImagePipeline.shared.renderForExport(
            for: asset,
            context: makeContext(asset: asset, recipe: exposed)
        ) else {
            throw TestError.imageRenderFailed
        }

        let baselineLuma = averageLuminance(of: baselineImage)
        let exposedLuma = averageLuminance(of: exposedImage)

        #expect(exposedLuma > baselineLuma + 0.10)
    }

    @Test func cropRectYUsesTopLeftOriginMapping() async throws {
        let fm = FileManager.default
        let dir = try makeTempDirectory(prefix: "rawctl-pipeline-crop-y")
        defer { try? fm.removeItem(at: dir) }

        let imageURL = dir.appendingPathComponent("top-bright-bottom-dark.png")
        try writePNG(at: imageURL, width: 300, height: 200) { context, width, height in
            context.setFillColor(NSColor.black.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.setFillColor(NSColor.white.cgColor)
            context.fill(CGRect(x: 0, y: height / 2, width: width, height: height / 2))
        }

        let asset = PhotoAsset(url: imageURL)

        var topHalfRecipe = EditRecipe()
        topHalfRecipe.crop = Crop(isEnabled: true, aspect: .free, rect: CropRect(x: 0.0, y: 0.0, w: 1.0, h: 0.5))

        var bottomHalfRecipe = EditRecipe()
        bottomHalfRecipe.crop = Crop(isEnabled: true, aspect: .free, rect: CropRect(x: 0.0, y: 0.5, w: 1.0, h: 0.5))

        await ImagePipeline.shared.clearCache()
        guard let topCrop = await ImagePipeline.shared.renderForExport(
            for: asset,
            context: makeContext(asset: asset, recipe: topHalfRecipe)
        ) else {
            throw TestError.imageRenderFailed
        }
        await ImagePipeline.shared.clearCache()
        guard let bottomCrop = await ImagePipeline.shared.renderForExport(
            for: asset,
            context: makeContext(asset: asset, recipe: bottomHalfRecipe)
        ) else {
            throw TestError.imageRenderFailed
        }

        #expect(topCrop.width == 300)
        #expect(abs(topCrop.height - 100) <= 1)
        #expect(bottomCrop.width == 300)
        #expect(abs(bottomCrop.height - 100) <= 1)

        let topLuma = averageLuminance(of: topCrop)
        let bottomLuma = averageLuminance(of: bottomCrop)
        #expect(topLuma > bottomLuma + 0.35)
    }

    @Test func cropRectXUsesLeftOriginMapping() async throws {
        let fm = FileManager.default
        let dir = try makeTempDirectory(prefix: "rawctl-pipeline-crop-x")
        defer { try? fm.removeItem(at: dir) }

        let imageURL = dir.appendingPathComponent("left-bright-right-dark.png")
        try writePNG(at: imageURL, width: 300, height: 200) { context, width, height in
            context.setFillColor(NSColor.black.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.setFillColor(NSColor.white.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        }

        let asset = PhotoAsset(url: imageURL)

        var leftHalfRecipe = EditRecipe()
        leftHalfRecipe.crop = Crop(isEnabled: true, aspect: .free, rect: CropRect(x: 0.0, y: 0.0, w: 0.5, h: 1.0))

        var rightHalfRecipe = EditRecipe()
        rightHalfRecipe.crop = Crop(isEnabled: true, aspect: .free, rect: CropRect(x: 0.5, y: 0.0, w: 0.5, h: 1.0))

        await ImagePipeline.shared.clearCache()
        guard let leftCrop = await ImagePipeline.shared.renderForExport(
            for: asset,
            context: makeContext(asset: asset, recipe: leftHalfRecipe)
        ) else {
            throw TestError.imageRenderFailed
        }
        await ImagePipeline.shared.clearCache()
        guard let rightCrop = await ImagePipeline.shared.renderForExport(
            for: asset,
            context: makeContext(asset: asset, recipe: rightHalfRecipe)
        ) else {
            throw TestError.imageRenderFailed
        }

        #expect(abs(leftCrop.width - 150) <= 1)
        #expect(leftCrop.height == 200)
        #expect(abs(rightCrop.width - 150) <= 1)
        #expect(rightCrop.height == 200)

        let leftLuma = averageLuminance(of: leftCrop)
        let rightLuma = averageLuminance(of: rightCrop)
        #expect(leftLuma > rightLuma + 0.35)
    }

    @Test func fastModeRenderIsFasterThanFullRenderForHeavyRecipe() async throws {
        let fm = FileManager.default
        let dir = try makeTempDirectory(prefix: "rawctl-pipeline-fastmode")
        defer { try? fm.removeItem(at: dir) }

        let imageURL = dir.appendingPathComponent("high-detail.png")
        try writePNG(at: imageURL, width: 1400, height: 900) { context, width, height in
            context.setFillColor(NSColor.black.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))

            // Deterministic detail pattern to exercise expensive filters.
            for y in stride(from: 0, to: height, by: 12) {
                for x in stride(from: 0, to: width, by: 12) {
                    let r = CGFloat((x * 13 + y * 7) % 255) / 255.0
                    let g = CGFloat((x * 3 + y * 17) % 255) / 255.0
                    let b = CGFloat((x * 19 + y * 5) % 255) / 255.0
                    context.setFillColor(NSColor(calibratedRed: r, green: g, blue: b, alpha: 1.0).cgColor)
                    context.fill(CGRect(x: x, y: y, width: 12, height: 12))
                }
            }
        }

        let asset = PhotoAsset(url: imageURL)
        var heavyRecipe = EditRecipe()
        heavyRecipe.exposure = 0.4
        heavyRecipe.contrast = 35
        heavyRecipe.vibrance = 40
        heavyRecipe.clarity = 80
        heavyRecipe.dehaze = 70
        heavyRecipe.texture = 75
        heavyRecipe.noiseReduction = 65
        heavyRecipe.hsl.blue.saturation = 80
        heavyRecipe.hsl.red.luminance = -40
        heavyRecipe.grain.amount = 40
        heavyRecipe.vignette.amount = -30

        let heavyContext = makeContext(asset: asset, recipe: heavyRecipe)

        // Warm-up once to reduce first-run noise in timing.
        _ = await ImagePipeline.shared.renderPreview(
            for: asset,
            context: heavyContext,
            maxSize: 1400,
            fastMode: true
        )
        _ = await ImagePipeline.shared.renderPreview(
            for: asset,
            context: heavyContext,
            maxSize: 1400,
            fastMode: false
        )

        var fastDurations: [Double] = []
        var fullDurations: [Double] = []

        for _ in 0..<3 {
            await ImagePipeline.shared.clearCache()
            fastDurations.append(try await renderPreviewSeconds(asset: asset, renderContext: heavyContext, fastMode: true))

            await ImagePipeline.shared.clearCache()
            fullDurations.append(try await renderPreviewSeconds(asset: asset, renderContext: heavyContext, fastMode: false))
        }

        let fastMedian = median(fastDurations)
        let fullMedian = median(fullDurations)
        print(String(format: "[ImagePipelineRegressionTests] fast median %.3fs, full median %.3fs", fastMedian, fullMedian))

        #expect(fastMedian < fullMedian)
    }

    @Test func benchmarkRenderStagesReturnsOrderedStageSamples() async throws {
        let fm = FileManager.default
        let dir = try makeTempDirectory(prefix: "rawctl-pipeline-stage-benchmark")
        defer { try? fm.removeItem(at: dir) }

        let imageURL = dir.appendingPathComponent("benchmark-input.png")
        try writePNG(at: imageURL, width: 320, height: 240) { context, width, height in
            context.setFillColor(NSColor(calibratedRed: 0.35, green: 0.35, blue: 0.35, alpha: 1.0).cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }

        let asset = PhotoAsset(url: imageURL)
        var recipe = EditRecipe()
        recipe.exposure = 0.4
        recipe.contrast = 12

        var localNode = ColorNode(name: "Benchmark Node", type: .serial)
        localNode.adjustments.exposure = 0.2

        let context = makeContext(asset: asset, recipe: recipe, localNodes: [localNode])
        let samples = await ImagePipeline.shared.benchmarkRenderStages(
            for: asset,
            context: context,
            maxSize: 900,
            fastMode: false
        )

        #expect(samples != nil)
        let stageNames = samples?.map(\.stage) ?? []
        #expect(stageNames.first == "globalRecipe")
        #expect(stageNames.contains("localNodes"))
        #expect((samples ?? []).allSatisfy { $0.milliseconds >= 0 })
    }

    @Test func grainEffectDoesNotBreakImageAtHighStrength() async throws {
        let fm = FileManager.default
        let dir = try makeTempDirectory(prefix: "rawctl-pipeline-grain-stability")
        defer { try? fm.removeItem(at: dir) }

        let imageURL = dir.appendingPathComponent("mid-gray.png")
        try writePNG(at: imageURL, width: 480, height: 320) { context, width, height in
            context.setFillColor(NSColor(calibratedRed: 0.5, green: 0.5, blue: 0.5, alpha: 1.0).cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }

        let asset = PhotoAsset(url: imageURL)
        var recipe = EditRecipe()
        recipe.grain = Grain(amount: 100, size: 60, roughness: 80)

        await ImagePipeline.shared.clearCache()
        guard let baseline = await ImagePipeline.shared.renderForExport(
            for: asset,
            context: makeContext(asset: asset)
        ) else {
            throw TestError.imageRenderFailed
        }
        await ImagePipeline.shared.clearCache()
        guard let grained = await ImagePipeline.shared.renderForExport(
            for: asset,
            context: makeContext(asset: asset, recipe: recipe)
        ) else {
            throw TestError.imageRenderFailed
        }

        let baselineLuma = averageLuminance(of: baseline)
        let grainedLuma = averageLuminance(of: grained)
        let meanDiff = meanAbsoluteDifference(baseline, grained)

        // Grain should be visible but remain stable (no catastrophic degradation).
        #expect(abs(grainedLuma - baselineLuma) < 0.18)
        #expect(meanDiff > 0.005)
        #expect(meanDiff < 0.22)
    }

    @Test func renderContextPreviewAndExportAreAligned() async throws {
        let fm = FileManager.default
        let dir = try makeTempDirectory(prefix: "rawctl-pipeline-render-context")
        defer { try? fm.removeItem(at: dir) }

        let imageURL = dir.appendingPathComponent("context-baseline.png")
        try writePNG(at: imageURL, width: 420, height: 280) { context, width, height in
            context.setFillColor(NSColor.black.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.setFillColor(NSColor(calibratedRed: 0.7, green: 0.35, blue: 0.25, alpha: 1.0).cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
            context.setFillColor(NSColor(calibratedRed: 0.2, green: 0.6, blue: 0.8, alpha: 1.0).cgColor)
            context.fill(CGRect(x: width / 2, y: 0, width: width / 2, height: height))
        }

        let asset = PhotoAsset(url: imageURL)
        var recipe = EditRecipe()
        recipe.exposure = 0.6
        recipe.contrast = 18
        recipe.highlights = -20

        var localNode = ColorNode(name: "Context Local", type: .serial)
        localNode.adjustments.exposure = 0.25
        localNode.adjustments.shadows = 12
        let localNodes = [localNode]

        let renderContext = RenderContext(
            assetId: asset.id,
            recipe: recipe,
            localNodes: localNodes
        )

        await ImagePipeline.shared.clearCache()
        guard let contextExport = await ImagePipeline.shared.renderForExport(
            for: asset,
            context: renderContext
        ) else {
            throw TestError.imageRenderFailed
        }

        await ImagePipeline.shared.clearCache()
        guard let contextPreviewImage = await ImagePipeline.shared.renderPreview(
            for: asset,
            context: renderContext,
            maxSize: 1000,
            fastMode: false
        ),
        let contextPreview = cgImage(from: contextPreviewImage) else {
            throw TestError.imageRenderFailed
        }

        #expect(meanAbsoluteDifference(contextExport, contextPreview) < 0.0001)
    }

    @Test func aiLayerCompositingAffectsRenderWhenVisible() async throws {
        let fm = FileManager.default
        let dir = try makeTempDirectory(prefix: "rawctl-pipeline-ai-layer")

        let imageURL = dir.appendingPathComponent("ai-base.png")
        try writePNG(at: imageURL, width: 320, height: 240) { context, width, height in
            context.setFillColor(NSColor(calibratedRed: 0.25, green: 0.25, blue: 0.25, alpha: 1.0).cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }

        let asset = PhotoAsset(url: imageURL)
        let layerId = UUID()
        let layerURL = CacheManager.shared.aiResultPath(
            assetFingerprint: asset.fingerprint,
            editId: layerId
        )
        try writeJPEG(at: layerURL, width: 320, height: 240, quality: 1.0) { context, width, height in
            context.setFillColor(NSColor(calibratedRed: 0.9, green: 0.2, blue: 0.2, alpha: 1.0).cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }

        defer { try? fm.removeItem(at: dir) }

        let baselineContext = RenderContext(assetId: asset.id, recipe: EditRecipe())
        var visibleLayer = AILayer(
            id: layerId,
            type: .enhance,
            prompt: "Enhance",
            originalPrompt: "Enhance",
            generatedImagePath: layerURL.lastPathComponent,
            creditsUsed: 1
        )
        visibleLayer.opacity = 0.8
        visibleLayer.blendMode = .normal
        visibleLayer.isVisible = true

        let visibleContext = RenderContext(
            assetId: asset.id,
            recipe: EditRecipe(),
            aiLayers: [visibleLayer]
        )

        var hiddenLayer = visibleLayer
        hiddenLayer.isVisible = false
        let hiddenContext = RenderContext(
            assetId: asset.id,
            recipe: EditRecipe(),
            aiLayers: [hiddenLayer]
        )

        await ImagePipeline.shared.clearCache()
        guard let baseline = await ImagePipeline.shared.renderForExport(
            for: asset,
            context: baselineContext
        ) else {
            throw TestError.imageRenderFailed
        }

        await ImagePipeline.shared.clearCache()
        guard let visible = await ImagePipeline.shared.renderForExport(
            for: asset,
            context: visibleContext
        ) else {
            throw TestError.imageRenderFailed
        }

        await ImagePipeline.shared.clearCache()
        guard let hidden = await ImagePipeline.shared.renderForExport(
            for: asset,
            context: hiddenContext
        ) else {
            throw TestError.imageRenderFailed
        }

        let visibleDiff = meanAbsoluteDifference(baseline, visible)
        let hiddenDiff = meanAbsoluteDifference(baseline, hidden)

        #expect(visibleDiff > 0.02)
        #expect(hiddenDiff < 0.0001)
        await CacheManager.shared.deleteAICache(for: asset.fingerprint)
    }

    @Test func aiEditCompositingAffectsRenderWhenEnabled() async throws {
        let fm = FileManager.default
        let dir = try makeTempDirectory(prefix: "rawctl-pipeline-ai-edit")

        let imageURL = dir.appendingPathComponent("ai-edit-base.png")
        try writePNG(at: imageURL, width: 320, height: 240) { context, width, height in
            context.setFillColor(NSColor(calibratedRed: 0.22, green: 0.22, blue: 0.22, alpha: 1.0).cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }

        let asset = PhotoAsset(url: imageURL)
        let editId = UUID()
        let resultURL = CacheManager.shared.aiResultPath(
            assetFingerprint: asset.fingerprint,
            editId: editId
        )
        try writeJPEG(at: resultURL, width: 320, height: 240, quality: 1.0) { context, width, height in
            context.setFillColor(NSColor(calibratedRed: 0.88, green: 0.25, blue: 0.25, alpha: 1.0).cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }

        defer { try? fm.removeItem(at: dir) }

        let baselineContext = RenderContext(assetId: asset.id, recipe: EditRecipe())
        let enabledEdit = AIEdit(
            id: editId,
            operation: .enhance,
            resultPath: resultURL.lastPathComponent,
            enabled: true
        )
        let enabledContext = RenderContext(
            assetId: asset.id,
            recipe: EditRecipe(),
            aiEdits: [enabledEdit]
        )

        var disabledEdit = enabledEdit
        disabledEdit.enabled = false
        let disabledContext = RenderContext(
            assetId: asset.id,
            recipe: EditRecipe(),
            aiEdits: [disabledEdit]
        )

        await ImagePipeline.shared.clearCache()
        guard let baseline = await ImagePipeline.shared.renderForExport(
            for: asset,
            context: baselineContext
        ) else {
            throw TestError.imageRenderFailed
        }

        await ImagePipeline.shared.clearCache()
        guard let enabled = await ImagePipeline.shared.renderForExport(
            for: asset,
            context: enabledContext
        ) else {
            throw TestError.imageRenderFailed
        }

        await ImagePipeline.shared.clearCache()
        guard let disabled = await ImagePipeline.shared.renderForExport(
            for: asset,
            context: disabledContext
        ) else {
            throw TestError.imageRenderFailed
        }

        let enabledDiff = meanAbsoluteDifference(baseline, enabled)
        let disabledDiff = meanAbsoluteDifference(baseline, disabled)

        #expect(enabledDiff > 0.02)
        #expect(disabledDiff < 0.0001)
        await CacheManager.shared.deleteAICache(for: asset.fingerprint)
    }

    // MARK: - Helpers

    private func makeTempDirectory(prefix: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func writePNG(
        at url: URL,
        width: Int,
        height: Int,
        draw: (_ context: CGContext, _ width: Int, _ height: Int) -> Void
    ) throws {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw TestError.bitmapContextCreationFailed
        }

        context.interpolationQuality = .none
        draw(context, width, height)

        guard let cgImage = context.makeImage() else {
            throw TestError.imageEncodingFailed
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw TestError.imageEncodingFailed
        }
        try data.write(to: url, options: .atomic)
    }

    private func writeJPEG(
        at url: URL,
        width: Int,
        height: Int,
        quality: Double,
        draw: (_ context: CGContext, _ width: Int, _ height: Int) -> Void
    ) throws {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw TestError.bitmapContextCreationFailed
        }

        context.interpolationQuality = .none
        draw(context, width, height)

        guard let cgImage = context.makeImage() else {
            throw TestError.imageEncodingFailed
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = rep.representation(using: .jpeg, properties: [
            .compressionFactor: quality
        ]) else {
            throw TestError.imageEncodingFailed
        }
        try data.write(to: url, options: .atomic)
    }

    private func averageLuminance(of image: CGImage) -> Double {
        let rep = NSBitmapImageRep(cgImage: image)
        let width = rep.pixelsWide
        let height = rep.pixelsHigh
        let step = max(1, min(width, height) / 64)

        var sum = 0.0
        var count = 0
        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                let luminance = 0.2126 * Double(color.redComponent) +
                    0.7152 * Double(color.greenComponent) +
                    0.0722 * Double(color.blueComponent)
                sum += luminance
                count += 1
            }
        }

        return count > 0 ? sum / Double(count) : 0
    }

    private func cgImage(from image: NSImage) -> CGImage? {
        if let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return cg
        }
        guard let data = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: data) else {
            return nil
        }
        return rep.cgImage
    }

    private func makeContext(
        asset: PhotoAsset,
        recipe: EditRecipe = EditRecipe(),
        localNodes: [ColorNode] = [],
        aiLayers: [AILayer] = [],
        aiEdits: [AIEdit] = []
    ) -> RenderContext {
        RenderContext(
            assetId: asset.id,
            recipe: recipe,
            localNodes: localNodes,
            aiLayers: aiLayers,
            aiEdits: aiEdits
        )
    }

    private func renderPreviewSeconds(
        asset: PhotoAsset,
        renderContext: RenderContext,
        fastMode: Bool
    ) async throws -> Double {
        let clock = ContinuousClock()
        let start = clock.now
        let rendered = await ImagePipeline.shared.renderPreview(
            for: asset,
            context: renderContext,
            maxSize: 1400,
            fastMode: fastMode
        )
        let duration = start.duration(to: clock.now)
        #expect(rendered != nil)
        return durationSeconds(duration)
    }

    private func durationSeconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }

    private func meanAbsoluteDifference(_ lhs: CGImage, _ rhs: CGImage) -> Double {
        let lhsRep = NSBitmapImageRep(cgImage: lhs)
        let rhsRep = NSBitmapImageRep(cgImage: rhs)
        let width = min(lhsRep.pixelsWide, rhsRep.pixelsWide)
        let height = min(lhsRep.pixelsHigh, rhsRep.pixelsHigh)
        let step = max(1, min(width, height) / 64)

        var totalDiff = 0.0
        var count = 0

        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                guard let c1 = lhsRep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                      let c2 = rhsRep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                    continue
                }
                totalDiff += abs(Double(c1.redComponent - c2.redComponent))
                totalDiff += abs(Double(c1.greenComponent - c2.greenComponent))
                totalDiff += abs(Double(c1.blueComponent - c2.blueComponent))
                count += 3
            }
        }

        return count > 0 ? totalDiff / Double(count) : 0
    }

    private func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }
}

// MARK: - renderLocalNodes Tests

extension ImagePipelineRegressionTests {

    // Helper: create a 1x1 solid-colour CIImage
    private func solidCIImage(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1.0) -> CIImage {
        CIImage(color: CIColor(red: red, green: green, blue: blue, alpha: alpha))
            .cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    @Test func test_renderLocalNodes_emptyArray_returnsBaseUnchanged() async {
        let base = solidCIImage(red: 0.5, green: 0.5, blue: 0.5)
        let result = await ImagePipeline.shared.renderLocalNodes([], baseImage: base, originalImage: base)
        #expect(result.extent == base.extent)

        // Pixel-level check: empty node list must leave pixel values untouched.
        let ciContext = CIContext()
        var basePixel = [UInt8](repeating: 0, count: 4)
        var resultPixel = [UInt8](repeating: 0, count: 4)

        ciContext.render(base,
                         toBitmap: &basePixel,
                         rowBytes: 4,
                         bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                         format: .RGBA8,
                         colorSpace: CGColorSpaceCreateDeviceRGB())

        ciContext.render(result,
                         toBitmap: &resultPixel,
                         rowBytes: 4,
                         bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                         format: .RGBA8,
                         colorSpace: CGColorSpaceCreateDeviceRGB())

        #expect(basePixel[0] == resultPixel[0])
        #expect(basePixel[1] == resultPixel[1])
        #expect(basePixel[2] == resultPixel[2])
    }

    @Test func test_renderLocalNodes_disabledNode_isSkipped() async {
        let base = solidCIImage(red: 0.2, green: 0.2, blue: 0.2)

        // Build a node that would dramatically brighten the image, but mark it disabled.
        var recipe = EditRecipe()
        recipe.exposure = 10.0
        var mutableNode = ColorNode(id: UUID(), name: "Disabled", type: .serial, adjustments: recipe)
        mutableNode.isEnabled = false

        let result = await ImagePipeline.shared.renderLocalNodes(
            [mutableNode],
            baseImage: base,
            originalImage: base
        )

        // Extent should be unchanged
        #expect(result.extent == base.extent)

        // Sample the pixel — since node is skipped, result should match base
        let ciContext = CIContext()
        var basePixel = [UInt8](repeating: 0, count: 4)
        var resultPixel = [UInt8](repeating: 0, count: 4)

        ciContext.render(base,
                         toBitmap: &basePixel,
                         rowBytes: 4,
                         bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                         format: .RGBA8,
                         colorSpace: CGColorSpaceCreateDeviceRGB())

        ciContext.render(result,
                         toBitmap: &resultPixel,
                         rowBytes: 4,
                         bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                         format: .RGBA8,
                         colorSpace: CGColorSpaceCreateDeviceRGB())

        #expect(basePixel[0] == resultPixel[0])
        #expect(basePixel[1] == resultPixel[1])
        #expect(basePixel[2] == resultPixel[2])
    }

    @Test func test_renderLocalNodes_radialMask_doesNotCrash() async {
        let base = solidCIImage(red: 0.3, green: 0.4, blue: 0.5)
        let original = solidCIImage(red: 0.3, green: 0.4, blue: 0.5)

        var recipe = EditRecipe()
        recipe.exposure = 1.0

        let mask = NodeMask(
            type: .radial(centerX: 0.5, centerY: 0.5, radius: 0.3),
            feather: 20.0,
            density: 80.0,
            invert: false
        )

        var node = ColorNode(id: UUID(), name: "Radial Node", type: .serial, adjustments: recipe)
        node.mask = mask

        let result = await ImagePipeline.shared.renderLocalNodes(
            [node],
            baseImage: base,
            originalImage: original
        )

        // Must not crash and must return a non-empty image
        #expect(result.extent.width > 0)
        #expect(result.extent.height > 0)
    }

    /// Regression: createBrushMask must not crash with empty data and should return black no-op mask.
    @Test func test_createBrushMask_emptyData_returnsBlackNoOpFallback() async {
        let extent = CGRect(x: 0, y: 0, width: 400, height: 300)
        let result = await ImagePipeline.shared.createBrushMask(from: Data(), targetExtent: extent)
        #expect(result.extent == extent)

        let ciContext = CIContext(options: nil)
        var pixel = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            result,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        #expect(pixel[0] < 2)
        #expect(pixel[1] < 2)
        #expect(pixel[2] < 2)
    }

    /// Regression: createBrushMask with valid PNG data must return image at target extent.
    @Test func test_createBrushMask_validPNG_returnsTargetExtent() async {
        // Create a minimal 2x2 PNG programmatically
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
        guard let ctx = CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8,
                                  bytesPerRow: 8, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: bitmapInfo.rawValue),
              let cgImg = ctx.makeImage(),
              let png = NSBitmapImageRep(cgImage: cgImg).representation(using: .png, properties: [:])
        else { return }

        let target = CGRect(x: 0, y: 0, width: 400, height: 300)
        let result = await ImagePipeline.shared.createBrushMask(from: png, targetExtent: target)
        #expect(abs(result.extent.width - target.width) < 1)
        #expect(abs(result.extent.height - target.height) < 1)
    }

    /// Regression: radial mask Y-flip — a mask with centerY=0 (SwiftUI top) must not crash
    /// and must produce a valid result extent.
    @Test func test_radialMask_yFlip_doesNotCrash() async {
        let base = solidCIImage(red: 0.2, green: 0.2, blue: 0.2)
        let original = solidCIImage(red: 0.2, green: 0.2, blue: 0.2)
        var recipe = EditRecipe()
        recipe.exposure = 2.0
        var node = ColorNode(id: UUID(), name: "TopMask", type: .serial, adjustments: recipe)
        node.mask = NodeMask(type: .radial(centerX: 0.5, centerY: 0.0, radius: 0.5),
                             feather: 0, density: 100, invert: false)
        let result = await ImagePipeline.shared.renderLocalNodes(
            [node], baseImage: base, originalImage: original)
        #expect(result.extent.width > 0)
        #expect(result.extent.height > 0)
    }
}
