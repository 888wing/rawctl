//
//  LayerCompositingOrderTests.swift
//  rawctlTests
//
//  Regression coverage for AI layer compositing order and skip rules.
//

import AppKit
import Foundation
import Testing
@testable import Latent

struct LayerCompositingOrderTests {

    private enum TestError: Error {
        case bitmapContextCreationFailed
        case imageEncodingFailed
        case imageRenderFailed
        case centerColorSamplingFailed
    }

    @Test func aiLayerCompositingRespectsStackOrderAndIsDeterministic() async throws {
        let fileManager = FileManager.default
        let dir = try makeTempDirectory(prefix: "latent-layer-order")
        defer { try? fileManager.removeItem(at: dir) }

        let baseURL = dir.appendingPathComponent("base.png")
        try writePNG(at: baseURL, width: 320, height: 240) { context, width, height in
            context.setFillColor(NSColor(calibratedRed: 0.18, green: 0.18, blue: 0.18, alpha: 1.0).cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }

        let asset = try makeAssetWithUniqueFingerprint(at: baseURL)
        defer { Task { await CacheManager.shared.deleteAICache(for: asset.fingerprint) } }

        let redLayerId = UUID()
        let greenLayerId = UUID()
        let redLayerURL = CacheManager.shared.aiResultPath(
            assetFingerprint: asset.fingerprint,
            editId: redLayerId
        )
        let greenLayerURL = CacheManager.shared.aiResultPath(
            assetFingerprint: asset.fingerprint,
            editId: greenLayerId
        )

        try writeJPEG(at: redLayerURL, width: 320, height: 240, quality: 1.0) { context, width, height in
            context.setFillColor(NSColor(calibratedRed: 0.95, green: 0.1, blue: 0.1, alpha: 1.0).cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        try writeJPEG(at: greenLayerURL, width: 320, height: 240, quality: 1.0) { context, width, height in
            context.setFillColor(NSColor(calibratedRed: 0.1, green: 0.95, blue: 0.1, alpha: 1.0).cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }

        var redLayer = AILayer(
            id: redLayerId,
            type: .transform,
            prompt: "red",
            originalPrompt: "red",
            generatedImagePath: redLayerURL.lastPathComponent,
            creditsUsed: 1,
            createdAt: Date(timeIntervalSince1970: 10),
            opacity: 0.75,
            blendMode: .normal
        )
        redLayer.isVisible = true

        var greenLayer = AILayer(
            id: greenLayerId,
            type: .transform,
            prompt: "green",
            originalPrompt: "green",
            generatedImagePath: greenLayerURL.lastPathComponent,
            creditsUsed: 1,
            createdAt: Date(timeIntervalSince1970: 20),
            opacity: 0.75,
            blendMode: .normal
        )
        greenLayer.isVisible = true

        // Stack contract: index 0 is top-most.
        let redTopContext = RenderContext(
            assetId: asset.id,
            recipe: EditRecipe(),
            aiLayers: [redLayer, greenLayer]
        )
        let greenTopContext = RenderContext(
            assetId: asset.id,
            recipe: EditRecipe(),
            aiLayers: [greenLayer, redLayer]
        )

        await ImagePipeline.shared.clearCache()
        guard let redTop = await ImagePipeline.shared.renderForExport(
            for: asset,
            context: redTopContext
        ) else {
            throw TestError.imageRenderFailed
        }

        await ImagePipeline.shared.clearCache()
        guard let greenTop = await ImagePipeline.shared.renderForExport(
            for: asset,
            context: greenTopContext
        ) else {
            throw TestError.imageRenderFailed
        }

        let redTopColor = try centerColor(of: redTop)
        let greenTopColor = try centerColor(of: greenTop)
        #expect(redTopColor.redComponent > redTopColor.greenComponent + 0.15)
        #expect(greenTopColor.greenComponent > greenTopColor.redComponent + 0.15)
        #expect(meanAbsoluteDifference(redTop, greenTop) > 0.12)

        await ImagePipeline.shared.clearCache()
        guard let redTopSecondRun = await ImagePipeline.shared.renderForExport(
            for: asset,
            context: redTopContext
        ) else {
            throw TestError.imageRenderFailed
        }

        #expect(meanAbsoluteDifference(redTop, redTopSecondRun) < 0.0001)
    }

    @Test func aiLayerCompositingSkipsHiddenAndZeroOpacityLayers() async throws {
        let fileManager = FileManager.default
        let dir = try makeTempDirectory(prefix: "latent-layer-skip")
        defer { try? fileManager.removeItem(at: dir) }

        let baseURL = dir.appendingPathComponent("base.png")
        try writePNG(at: baseURL, width: 320, height: 240) { context, width, height in
            context.setFillColor(NSColor(calibratedRed: 0.22, green: 0.22, blue: 0.22, alpha: 1.0).cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }

        let asset = try makeAssetWithUniqueFingerprint(at: baseURL)
        defer { Task { await CacheManager.shared.deleteAICache(for: asset.fingerprint) } }

        let hiddenLayerId = UUID()
        let transparentLayerId = UUID()
        let hiddenLayerURL = CacheManager.shared.aiResultPath(
            assetFingerprint: asset.fingerprint,
            editId: hiddenLayerId
        )
        let transparentLayerURL = CacheManager.shared.aiResultPath(
            assetFingerprint: asset.fingerprint,
            editId: transparentLayerId
        )

        try writeJPEG(at: hiddenLayerURL, width: 320, height: 240, quality: 1.0) { context, width, height in
            context.setFillColor(NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.95, alpha: 1.0).cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        try writeJPEG(at: transparentLayerURL, width: 320, height: 240, quality: 1.0) { context, width, height in
            context.setFillColor(NSColor(calibratedRed: 0.95, green: 0.95, blue: 0.15, alpha: 1.0).cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }

        var hiddenLayer = AILayer(
            id: hiddenLayerId,
            type: .enhance,
            prompt: "hidden",
            originalPrompt: "hidden",
            generatedImagePath: hiddenLayerURL.lastPathComponent,
            creditsUsed: 1
        )
        hiddenLayer.isVisible = false
        hiddenLayer.opacity = 1.0

        var transparentLayer = AILayer(
            id: transparentLayerId,
            type: .enhance,
            prompt: "transparent",
            originalPrompt: "transparent",
            generatedImagePath: transparentLayerURL.lastPathComponent,
            creditsUsed: 1
        )
        transparentLayer.isVisible = true
        transparentLayer.opacity = 0.0

        let baselineContext = RenderContext(assetId: asset.id, recipe: EditRecipe())
        let skippedLayersContext = RenderContext(
            assetId: asset.id,
            recipe: EditRecipe(),
            aiLayers: [hiddenLayer, transparentLayer]
        )

        await ImagePipeline.shared.clearCache()
        guard let baseline = await ImagePipeline.shared.renderForExport(
            for: asset,
            context: baselineContext
        ) else {
            throw TestError.imageRenderFailed
        }

        await ImagePipeline.shared.clearCache()
        guard let skipped = await ImagePipeline.shared.renderForExport(
            for: asset,
            context: skippedLayersContext
        ) else {
            throw TestError.imageRenderFailed
        }

        #expect(meanAbsoluteDifference(baseline, skipped) < 0.0001)
    }

    @Test func aiLayerStackMoveLayerReordersCorrectly() {
        let idA = UUID()
        let idB = UUID()
        let idC = UUID()

        let stack = AILayerStack(documentId: UUID())
        stack.layers = [
            AILayer(id: idA, type: .transform, prompt: "A", originalPrompt: "A",
                    generatedImagePath: "a.jpg", creditsUsed: 1),
            AILayer(id: idB, type: .transform, prompt: "B", originalPrompt: "B",
                    generatedImagePath: "b.jpg", creditsUsed: 1),
            AILayer(id: idC, type: .transform, prompt: "C", originalPrompt: "C",
                    generatedImagePath: "c.jpg", creditsUsed: 1),
        ]

        // Move A (index 0) to C's position (index 2) — "move down"
        stack.moveLayer(from: idA, to: idC)
        // After remove(0): [B,C] targetIndex was 2 → adjusted to 1 → insert at 1 → [B,A,C]
        #expect(stack.layers.map(\.id) == [idB, idA, idC])

        // Move C (now index 2) to B's position (index 0) — "move up"
        stack.moveLayer(from: idC, to: idB)
        // remove(2): [B,A] targetIndex=0, source>target so no shift → insert at 0 → [C,B,A]
        #expect(stack.layers.map(\.id) == [idC, idB, idA])
    }

    // MARK: - Helpers

    private func makeTempDirectory(prefix: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeAssetWithUniqueFingerprint(at url: URL) throws -> PhotoAsset {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        return PhotoAsset(
            url: url,
            fileSize: attrs[.size] as? Int64 ?? 0,
            creationDate: attrs[.creationDate] as? Date,
            modificationDate: attrs[.modificationDate] as? Date,
            fingerprint: UUID().uuidString
        )
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

    private func centerColor(of image: CGImage) throws -> NSColor {
        let rep = NSBitmapImageRep(cgImage: image)
        let x = max(0, rep.pixelsWide / 2)
        let y = max(0, rep.pixelsHigh / 2)
        guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
            throw TestError.centerColorSamplingFailed
        }
        return color
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
}
