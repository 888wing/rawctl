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
@testable import rawctl

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
        guard let baselineImage = await ImagePipeline.shared.renderForExport(for: asset, recipe: EditRecipe()) else {
            throw TestError.imageRenderFailed
        }
        await ImagePipeline.shared.clearCache()
        guard let exposedImage = await ImagePipeline.shared.renderForExport(for: asset, recipe: exposed) else {
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
        guard let topCrop = await ImagePipeline.shared.renderForExport(for: asset, recipe: topHalfRecipe) else {
            throw TestError.imageRenderFailed
        }
        await ImagePipeline.shared.clearCache()
        guard let bottomCrop = await ImagePipeline.shared.renderForExport(for: asset, recipe: bottomHalfRecipe) else {
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
        guard let leftCrop = await ImagePipeline.shared.renderForExport(for: asset, recipe: leftHalfRecipe) else {
            throw TestError.imageRenderFailed
        }
        await ImagePipeline.shared.clearCache()
        guard let rightCrop = await ImagePipeline.shared.renderForExport(for: asset, recipe: rightHalfRecipe) else {
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

        // Warm-up once to reduce first-run noise in timing.
        _ = await ImagePipeline.shared.renderPreview(for: asset, recipe: heavyRecipe, maxSize: 1400, fastMode: true)
        _ = await ImagePipeline.shared.renderPreview(for: asset, recipe: heavyRecipe, maxSize: 1400, fastMode: false)

        var fastDurations: [Double] = []
        var fullDurations: [Double] = []

        for _ in 0..<3 {
            await ImagePipeline.shared.clearCache()
            fastDurations.append(try await renderPreviewSeconds(asset: asset, recipe: heavyRecipe, fastMode: true))

            await ImagePipeline.shared.clearCache()
            fullDurations.append(try await renderPreviewSeconds(asset: asset, recipe: heavyRecipe, fastMode: false))
        }

        let fastMedian = median(fastDurations)
        let fullMedian = median(fullDurations)
        print(String(format: "[ImagePipelineRegressionTests] fast median %.3fs, full median %.3fs", fastMedian, fullMedian))

        #expect(fastMedian < fullMedian)
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
        guard let baseline = await ImagePipeline.shared.renderForExport(for: asset, recipe: EditRecipe()) else {
            throw TestError.imageRenderFailed
        }
        await ImagePipeline.shared.clearCache()
        guard let grained = await ImagePipeline.shared.renderForExport(for: asset, recipe: recipe) else {
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

    private func renderPreviewSeconds(asset: PhotoAsset, recipe: EditRecipe, fastMode: Bool) async throws -> Double {
        let clock = ContinuousClock()
        let start = clock.now
        let rendered = await ImagePipeline.shared.renderPreview(for: asset, recipe: recipe, maxSize: 1400, fastMode: fastMode)
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
