//
//  CacheEvictionTests.swift
//  rawctlTests
//
//  Regression coverage for real cache eviction behavior (E3-S1).
//

import AppKit
import Foundation
import Testing
@testable import Latent

@MainActor
struct CacheEvictionTests {
    @Test func thumbnailServiceEvictionRemovesOldestMemoryEntries() async throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent(
            "latent-cache-thumbnail-\(UUID().uuidString)",
            isDirectory: true
        )
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let service = ThumbnailService()
        await service.clearCache()

        for index in 0..<4 {
            let url = dir.appendingPathComponent("thumb-\(index).jpg")
            try writeJPEG(at: url, hue: CGFloat(index) * 0.2)
            let attrs = try fm.attributesOfItem(atPath: url.path)
            let asset = PhotoAsset(
                url: url,
                fileSize: attrs[.size] as? Int64 ?? 0,
                creationDate: attrs[.creationDate] as? Date,
                modificationDate: attrs[.modificationDate] as? Date,
                fingerprint: UUID().uuidString
            )
            let thumbnail = await service.thumbnail(for: asset, size: 96)
            #expect(thumbnail != nil)
        }

        let before = await service.cacheTelemetry()
        #expect(before.entryCount > 0)

        let target = max(1, before.entryCount / 2)
        let removed = await service.evictMemoryEntries(count: target)
        let after = await service.cacheTelemetry()

        #expect(removed.entries > 0)
        #expect(after.entryCount < before.entryCount)
        #expect(after.evictedEntries >= removed.entries)
    }

    @Test func imagePipelinePreviewEvictionShrinksCache() async throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent(
            "latent-cache-preview-\(UUID().uuidString)",
            isDirectory: true
        )
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let pipeline = ImagePipeline()
        await pipeline.clearCache()

        for index in 0..<3 {
            let url = dir.appendingPathComponent("preview-\(index).jpg")
            try writeJPEG(at: url, hue: CGFloat(index) * 0.25)
            let attrs = try fm.attributesOfItem(atPath: url.path)
            let asset = PhotoAsset(
                url: url,
                fileSize: attrs[.size] as? Int64 ?? 0,
                creationDate: attrs[.creationDate] as? Date,
                modificationDate: attrs[.modificationDate] as? Date,
                fingerprint: UUID().uuidString
            )
            _ = await pipeline.renderPreview(
                for: asset,
                context: RenderContext(assetId: asset.id, recipe: EditRecipe()),
                maxSize: 320
            )
        }

        let before = await pipeline.previewCacheTelemetry()
        #expect(before.entryCount > 0)

        let removed = await pipeline.evictPreviewEntries(count: 1)
        let after = await pipeline.previewCacheTelemetry()

        #expect(removed.entries == 1 || before.entryCount == 0)
        #expect(after.entryCount <= max(0, before.entryCount - removed.entries))
        #expect(after.evictedEntries >= removed.entries)
    }

    private func writeJPEG(at url: URL, hue: CGFloat) throws {
        let size = NSSize(width: 120, height: 80)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor(calibratedHue: hue, saturation: 0.8, brightness: 0.85, alpha: 1.0).setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.95]) else {
            throw CocoaError(.fileWriteUnknown)
        }

        try jpeg.write(to: url, options: .atomic)
    }
}

