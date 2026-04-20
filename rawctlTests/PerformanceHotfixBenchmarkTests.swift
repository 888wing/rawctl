//
//  PerformanceHotfixBenchmarkTests.swift
//  rawctlTests
//
//  Benchmarks for the v1.4.2 performance hotfix work.
//

import AppKit
import Foundation
import Testing
@testable import Latent

@MainActor
struct PerformanceHotfixBenchmarkTests {
    @Test func stagedFolderOpenReturnsBeforeFullScanCompletes() async throws {
        let folder = try makeTemporaryFolder(name: "perf-hotfix-folder")
        defer { try? FileManager.default.removeItem(at: folder) }

        let imageCount = 1_200
        for index in 0..<imageCount {
            let url = folder.appendingPathComponent(String(format: "IMG_%04d.ARW", index))
            FileManager.default.createFile(atPath: url.path, contents: Data([0x00, 0x01, 0x02, 0x03]))
        }

        let isolated = makeIsolatedPerfDefaults()
        defer { isolated.reset() }

        let folderManager = FolderManager(
            userDefaults: isolated.defaults,
            namespace: "latent-perf-\(UUID().uuidString)",
            legacyNamespaces: []
        )
        let appState = AppState(userDefaults: isolated.defaults, folderManager: folderManager)
        let clock = ContinuousClock()

        let fullScanStart = clock.now
        let fullyScannedAssets = try await FileSystemService.scanFolder(folder)
        let fullScanMs = durationMilliseconds(fullScanStart.duration(to: clock.now))

        let stagedOpenStart = clock.now
        let didOpen = await appState.openFolderFromPath(folder.path, registerInFolderHistory: false)
        let stagedOpenMs = durationMilliseconds(stagedOpenStart.duration(to: clock.now))

        #expect(didOpen == true)
        #expect(fullyScannedAssets.count == imageCount)
        #expect(appState.assets.count > 0)
        #expect(appState.assets.count < fullyScannedAssets.count)

        print(
            "[Perf][FolderOpen] full_scan_ms=\(fullScanMs) staged_open_ms=\(stagedOpenMs) initial_visible=\(appState.assets.count)"
        )

        for _ in 0..<200 where appState.isFolderScanInProgress {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        #expect(appState.isFolderScanInProgress == false)
        #expect(appState.assets.count == fullyScannedAssets.count)
        #expect(stagedOpenMs < appState.e2eFolderScanCompletionMs)

        print(
            "[Perf][FolderOpen] staged_scan_complete_ms=\(appState.e2eFolderScanCompletionMs) total_assets=\(appState.assets.count)"
        )

        appState.cancelBackgroundAssetLoading(resetThumbnailProgress: true, cancelStagedScan: true)
        try? await Task.sleep(nanoseconds: 150_000_000)
    }

    @Test func interactivePreviewPathOutrunsFullPreviewPath() async throws {
        let folder = try makeTemporaryFolder(name: "perf-hotfix-render")
        defer { try? FileManager.default.removeItem(at: folder) }

        let imageURL = folder.appendingPathComponent("stress.png")
        try writeSyntheticStressImage(to: imageURL, width: 2800, height: 1800)

        let asset = PhotoAsset(url: imageURL)
        var recipe = EditRecipe()
        recipe.exposure = 0.95
        recipe.contrast = 34
        recipe.highlights = -42
        recipe.shadows = 38
        recipe.whites = 16
        recipe.blacks = -22
        recipe.vibrance = 25
        recipe.saturation = 12
        recipe.whiteBalance = WhiteBalance(preset: .custom, temperature: 7200, tint: 18)
        recipe.toneCurve = ToneCurve(points: [
            .init(x: 0.0, y: 0.0),
            .init(x: 0.18, y: 0.10),
            .init(x: 0.50, y: 0.55),
            .init(x: 0.78, y: 0.88),
            .init(x: 1.0, y: 1.0),
        ])
        recipe.rgbCurves.red[2].y = 0.58
        recipe.rgbCurves.blue[1].y = 0.20
        recipe.vignette = Vignette(amount: -28, midpoint: 42, feather: 64)
        recipe.splitToning = SplitToning(
            highlightHue: 42,
            highlightSaturation: 18,
            shadowHue: 220,
            shadowSaturation: 24,
            balance: -12
        )
        recipe.sharpness = 54
        recipe.noiseReduction = 28
        recipe.clarity = 30
        recipe.dehaze = 24
        recipe.texture = 32
        recipe.grain = Grain(amount: 22, size: 30, roughness: 58)
        recipe.hsl.red.saturation = 18
        recipe.hsl.green.hue = -14
        recipe.hsl.blue.luminance = -10
        recipe.chromaticAberration = ChromaticAberration(amount: 24)
        recipe.perspective = Perspective(vertical: 8, horizontal: -6, rotate: 1.5, scale: 104)
        recipe.calibration = CameraCalibration(
            shadowTint: 10,
            redHue: -8,
            redSaturation: 6,
            greenHue: 4,
            greenSaturation: -6,
            blueHue: 12,
            blueSaturation: 10
        )

        let fullContext = RenderContext(assetId: asset.id, recipe: recipe)
        let interactiveContext = RenderContext(
            assetId: asset.id,
            recipe: recipe.quantizedForInteractivePreview()
        )
        let clock = ContinuousClock()

        await ImagePipeline.shared.clearCache()
        let fullStart = clock.now
        let fullPreview = await ImagePipeline.shared.renderPreview(
            for: asset,
            context: fullContext,
            maxSize: 1600,
            fastMode: false,
            interactivePreview: false
        )
        let fullPreviewMs = durationMilliseconds(fullStart.duration(to: clock.now))

        await ImagePipeline.shared.clearCache()
        let interactiveStart = clock.now
        let interactivePreview = await ImagePipeline.shared.renderPreview(
            for: asset,
            context: interactiveContext,
            maxSize: 576,
            fastMode: true,
            interactivePreview: true
        )
        let interactivePreviewMs = durationMilliseconds(interactiveStart.duration(to: clock.now))

        #expect(fullPreview != nil)
        #expect(interactivePreview != nil)
        #expect(interactivePreviewMs < fullPreviewMs)

        print(
            "[Perf][Preview] full_preview_ms=\(fullPreviewMs) interactive_preview_ms=\(interactivePreviewMs)"
        )
    }
}

private func makeIsolatedPerfDefaults() -> (suiteName: String, defaults: UserDefaults, reset: () -> Void) {
    let suiteName = "rawctl.tests.performance.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return (
        suiteName: suiteName,
        defaults: defaults,
        reset: {
            defaults.removePersistentDomain(forName: suiteName)
        }
    )
}

private func makeTemporaryFolder(name: String) throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("latent-perf-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent(name, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

private func durationMilliseconds(_ duration: Duration) -> Int {
    let components = duration.components
    let secondsMs = Int(components.seconds) * 1_000
    let attosecondsMs = Int(components.attoseconds / 1_000_000_000_000_000)
    return max(0, secondsMs + attosecondsMs)
}

private func writeSyntheticStressImage(to url: URL, width: Int, height: Int) throws {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw CocoaError(.fileWriteUnknown)
    }

    for y in 0..<height {
        let progress = CGFloat(y) / CGFloat(max(1, height - 1))
        context.setFillColor(
            CGColor(
                red: progress * 0.9,
                green: 0.15 + progress * 0.55,
                blue: 0.3 + progress * 0.45,
                alpha: 1
            )
        )
        context.fill(CGRect(x: 0, y: y, width: width, height: 1))
    }

    context.setStrokeColor(CGColor(red: 0.95, green: 0.92, blue: 0.25, alpha: 0.85))
    context.setLineWidth(10)
    for index in stride(from: 120, to: width, by: 220) {
        context.strokeEllipse(in: CGRect(x: index, y: 180, width: 180, height: 180))
    }

    context.setFillColor(CGColor(red: 0.12, green: 0.08, blue: 0.04, alpha: 0.35))
    for index in stride(from: 0, to: width, by: 160) {
        context.fill(CGRect(x: index, y: 0, width: 48, height: height))
    }

    guard let cgImage = context.makeImage() else {
        throw CocoaError(.fileWriteUnknown)
    }

    let rep = NSBitmapImageRep(cgImage: cgImage)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try data.write(to: url)
}
