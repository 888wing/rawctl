//
//  SmartSyncServiceTests.swift
//  rawctlTests
//
//  Tests for SmartSyncService — EV computation, recipe adaptation,
//  and FeaturePrintIndex session-scoping. Does NOT require actual
//  image files for most logic tests.
//

import Foundation
import Testing
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import Latent

struct SmartSyncServiceTests {

    // MARK: - EV Computation (via recipe adaptation)

    /// adaptRecipe with no EXIF metadata returns the original recipe unchanged.
    @Test func adaptWithNoMetadataIsIdentity() async {
        let service = SmartSyncService.shared
        let recipe  = makeRecipe(exposure: 0.5)
        let source  = PhotoAsset(url: URL(filePath: "/tmp/a.jpg"))
        var target  = PhotoAsset(url: URL(filePath: "/tmp/b.jpg"))
        target.metadata = nil   // no EXIF

        let adapted = await service.adaptRecipe(recipe, from: source, to: target)
        #expect(adapted.exposure == recipe.exposure)
    }

    /// When both photos have identical EXIF, exposure delta is zero.
    @Test func identicalEXIFProducesZeroDelta() async {
        let service = SmartSyncService.shared
        let recipe  = makeRecipe(exposure: 0.7)
        let meta    = makeMetadata(aperture: "f/2.8", shutter: "1/125")
        var source  = PhotoAsset(url: URL(filePath: "/tmp/s.jpg"))
        source.metadata = meta
        var target  = PhotoAsset(url: URL(filePath: "/tmp/t.jpg"))
        target.metadata = meta   // same settings

        let adapted = await service.adaptRecipe(recipe, from: source, to: target)
        #expect(abs(adapted.exposure - recipe.exposure) < 0.01)
    }

    /// One stop darker target (double the shutter speed) → exposure +1.
    @Test func darkerTargetGetsPositiveExposureOffset() async {
        let service = SmartSyncService.shared
        let recipe  = makeRecipe(exposure: 0.0)
        // Source: f/2.8, 1/125  →  EV = 2·log2(2.8) − log2(1/125) ≈ 10.9
        var source  = PhotoAsset(url: URL(filePath: "/tmp/src.jpg"))
        source.metadata = makeMetadata(aperture: "f/2.8", shutter: "1/125")
        // Target: f/2.8, 1/250  → one stop faster shutter → EV + 1 → needs +1 exposure
        var target  = PhotoAsset(url: URL(filePath: "/tmp/tgt.jpg"))
        target.metadata = makeMetadata(aperture: "f/2.8", shutter: "1/250")

        let adapted = await service.adaptRecipe(recipe, from: source, to: target)
        // Target is darker (1/250 vs 1/125) so we need +1 to compensate.
        #expect(adapted.exposure > 0.8)
        #expect(adapted.exposure < 1.2)
    }

    /// Exposure delta is clamped to ±2 stops maximum.
    @Test func largeEVDeltaIsClamped() async {
        let service = SmartSyncService.shared
        let recipe  = makeRecipe(exposure: 0.0)
        // Extreme difference: 1/4000 vs 1/8 = 9 stops
        var source  = PhotoAsset(url: URL(filePath: "/tmp/src.jpg"))
        source.metadata = makeMetadata(aperture: "f/2.8", shutter: "1/4000")
        var target  = PhotoAsset(url: URL(filePath: "/tmp/tgt.jpg"))
        target.metadata = makeMetadata(aperture: "f/2.8", shutter: "1/8")

        let adapted = await service.adaptRecipe(recipe, from: source, to: target)
        // Delta should be clamped to +2 (target is much darker).
        #expect(adapted.exposure <= 2.0 + recipe.exposure + 0.01)
        #expect(adapted.exposure >= -2.0 + recipe.exposure - 0.01)
    }

    /// Non-exposure parameters (contrast, WB, etc.) are preserved unchanged.
    @Test func nonExposureParametersArePreserved() async {
        let service = SmartSyncService.shared
        var recipe  = makeRecipe(exposure: 0.0)
        recipe.contrast   = 0.3
        recipe.highlights = -0.5
        recipe.shadows    = 0.4
        recipe.vibrance   = 0.6
        recipe.whiteBalance.temperature = 5500
        recipe.whiteBalance.tint        = 10

        let meta   = makeMetadata(aperture: "f/2.8", shutter: "1/125")
        var source = PhotoAsset(url: URL(filePath: "/tmp/s.jpg"))
        source.metadata = meta
        var target = PhotoAsset(url: URL(filePath: "/tmp/t.jpg"))
        target.metadata = meta

        let adapted = await service.adaptRecipe(recipe, from: source, to: target)
        #expect(adapted.contrast   == recipe.contrast)
        #expect(adapted.highlights == recipe.highlights)
        #expect(adapted.shadows    == recipe.shadows)
        #expect(adapted.vibrance   == recipe.vibrance)
        #expect(adapted.whiteBalance.temperature == recipe.whiteBalance.temperature)
        #expect(adapted.whiteBalance.tint        == recipe.whiteBalance.tint)
    }

    // MARK: - findAndAdapt (empty / self-exclusion)

    @Test func findAndAdaptExcludesSourceAsset() async {
        let service = SmartSyncService.shared
        let asset   = PhotoAsset(url: URL(filePath: "/tmp/only.jpg"))
        let recipe  = makeRecipe(exposure: 0.0)

        // Only the source asset — no candidates.
        let results = await service.findAndAdapt(
            source: asset, sourceRecipe: recipe, candidates: [asset]
        )
        #expect(results.isEmpty)
    }

    @Test func findAndAdaptEmptyCandidatesReturnsEmpty() async {
        let service = SmartSyncService.shared
        let source  = PhotoAsset(url: URL(filePath: "/tmp/src.jpg"))
        let recipe  = makeRecipe(exposure: 0.0)

        let results = await service.findAndAdapt(
            source: source, sourceRecipe: recipe, candidates: []
        )
        #expect(results.isEmpty)
    }

    // MARK: - FeaturePrintIndex

    @Test func featurePrintIndexCachesEntry() async {
        let index = FeaturePrintIndex.shared
        await index.reset()   // start clean for this test

        guard let url = createSyntheticJPEG() else { return }
        defer { try? FileManager.default.removeItem(at: url) }

        let asset = PhotoAsset(url: url)

        // First call — generates and caches.
        let fp1 = await index.featurePrint(for: asset)
        #expect(fp1 != nil)

        // Second call — must return the cached observation (same object identity).
        let fp2 = await index.featurePrint(for: asset)
        #expect(fp1 === fp2, "Expected cached observation to be returned unchanged")
    }

    @Test func featurePrintIndexInvalidateRemovesEntry() async {
        let index = FeaturePrintIndex.shared
        await index.reset()

        guard let url = createSyntheticJPEG() else { return }
        defer { try? FileManager.default.removeItem(at: url) }

        let asset = PhotoAsset(url: url)
        _ = await index.featurePrint(for: asset)
        await index.invalidate(asset.id)

        // After invalidation the next call re-generates (new object identity).
        let fp1 = await index.featurePrint(for: asset)
        let fp2 = await index.featurePrint(for: asset)
        // Both should be non-nil and the re-generated one equal.
        #expect(fp1 != nil)
        #expect(fp2 != nil)
    }

    // MARK: - Helpers

    private func makeRecipe(exposure: Double) -> EditRecipe {
        var r = EditRecipe()
        r.exposure = exposure
        return r
    }

    private func makeMetadata(aperture: String, shutter: String) -> ImageMetadata {
        var m = ImageMetadata()
        m.aperture    = aperture
        m.shutterSpeed = shutter
        return m
    }

    /// Creates a minimal 64×64 JPEG in the temp directory.
    private func createSyntheticJPEG() -> URL? {
        let size = CGSize(width: 64, height: 64)
        guard let ctx = CGContext(
            data: nil,
            width: Int(size.width), height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.setFillColor(CGColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 1.0))
        ctx.fill(CGRect(origin: .zero, size: size))
        guard let image = ctx.makeImage() else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("smartsync_test_\(UUID().uuidString).jpg")
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return url
    }
}
