//
//  ThumbnailService.swift
//  rawctl
//
//  Thumbnail generation and caching with timeout and progress tracking
//

import Foundation
import AppKit
import CoreImage

/// Thumbnail generation timeout error
enum ThumbnailError: Error {
    case timeout
    case generationFailed
}

/// Service for generating and caching thumbnails
actor ThumbnailService {
    static let shared = ThumbnailService()

    private let cacheDirectory: URL
    private let thumbnailSize: CGFloat = 300
    private var memoryCache: [String: NSImage] = [:]
    private var inFlightLoads: [String: Task<NSImage?, Never>] = [:]
    private let maxMemoryCacheSize = 200
    nonisolated private static let diskIOQueue = DispatchQueue(
        label: "Shacoworkshop.rawctl.thumbnail.diskio",
        qos: .utility
    )

    /// Default timeout for thumbnail generation (seconds)
    private let defaultTimeout: TimeInterval = 5.0

    /// Concurrent load limiter to prevent system overload
    private let concurrentLoadLimit = 6
    private var activeLoads = 0
    private var pendingLoads: [CheckedContinuation<Void, Never>] = []

    init() {
        // Set up cache directory
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = caches
            .appendingPathComponent("Shacoworkshop.rawctl", isDirectory: true)
            .appendingPathComponent("thumbnails", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    /// Acquire a load slot (waits if at limit)
    private func acquireLoadSlot() async {
        if activeLoads >= concurrentLoadLimit {
            await withCheckedContinuation { continuation in
                pendingLoads.append(continuation)
            }
        }
        activeLoads += 1
    }

    /// Release a load slot
    private func releaseLoadSlot() {
        activeLoads -= 1
        if let next = pendingLoads.first {
            pendingLoads.removeFirst()
            next.resume()
        }
    }

    /// Get thumbnail for an asset with timeout protection
    /// - Parameters:
    ///   - asset: The photo asset to generate thumbnail for
    ///   - size: Target thumbnail size (default 300px)
    ///   - timeout: Maximum time to wait for generation (default 5 seconds)
    /// - Returns: Generated thumbnail or nil if failed/timeout
    func thumbnail(for asset: PhotoAsset, size: CGFloat = 300, timeout: TimeInterval? = nil) async -> NSImage? {
        let cacheKey = Self.makeCacheKey(for: asset, size: size)
        let effectiveTimeout = timeout ?? defaultTimeout
        let signpostId = PerformanceSignposts.signposter.makeSignpostID()

        // Check memory cache first (instant, no slot needed)
        if let cached = memoryCache[cacheKey] {
            PerformanceSignposts.event("thumbnailCacheHitMemory", id: signpostId)
            return cached
        }

        // Check disk cache (fast, no slot needed)
        let cacheFile = cacheDirectory.appendingPathComponent("\(cacheKey).jpg")
        if FileManager.default.fileExists(atPath: cacheFile.path),
           let image = NSImage(contentsOf: cacheFile) {
            await cacheInMemory(image, for: cacheKey)
            PerformanceSignposts.event("thumbnailCacheHitDisk", id: signpostId)
            return image
        }

        if let inFlight = inFlightLoads[cacheKey] {
            PerformanceSignposts.event("thumbnailJoinInFlight", id: signpostId)
            return await inFlight.value
        }

        let generationTask = Task<NSImage?, Never> { [asset, size, effectiveTimeout] in
            let taskSignpostId = PerformanceSignposts.signposter.makeSignpostID()
            let signpostState = PerformanceSignposts.begin("thumbnailGenerate", id: taskSignpostId)
            defer { PerformanceSignposts.end("thumbnailGenerate", signpostState) }

            await self.acquireLoadSlot()
            let generated = await self.generateWithTimeout(for: asset, size: size, timeout: effectiveTimeout)
            self.releaseLoadSlot()
            return generated
        }
        inFlightLoads[cacheKey] = generationTask
        defer {
            inFlightLoads.removeValue(forKey: cacheKey)
        }

        // Generate thumbnail with timeout
        let result = await generationTask.value

        guard let thumbnail = result else {
            // Generation failed or timed out
            PerformanceSignposts.event("thumbnailFailed", id: signpostId)
            return nil
        }

        // Cache in memory
        await cacheInMemory(thumbnail, for: cacheKey)
        
        // Save to disk cache asynchronously on a dedicated queue.
        // Keep disk I/O off the actor to avoid blocking inflight thumbnail work.
        Self.enqueueDiskWrite(thumbnail, at: cacheFile)

        return thumbnail
    }
    
    /// Generate thumbnail with timeout protection
    private func generateWithTimeout(for asset: PhotoAsset, size: CGFloat, timeout: TimeInterval) async -> NSImage? {
        // Use task group to race between generation and timeout
        return await withTaskGroup(of: NSImage?.self) { group in
            // Task 1: Actual thumbnail generation
            group.addTask {
                await self.generateThumbnailSafe(for: asset, size: size)
            }
            
            // Task 2: Timeout
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                return nil
            }
            
            // Return first completed result
            if let result = await group.next() {
                group.cancelAll()
                return result
            }
            return nil
        }
    }
    
    /// Generate thumbnail safely (catches any errors)
    private func generateThumbnailSafe(for asset: PhotoAsset, size: CGFloat) async -> NSImage? {
        // For RAW files, try embedded preview first (much faster)
        if asset.isRAW {
            if let embedded = extractEmbeddedPreview(for: asset, size: size) {
                return embedded
            }
        }
        
        // Standard ImageIO thumbnail generation
        return generateThumbnail(for: asset, size: size)
    }
    
    /// Extract embedded JPEG preview from RAW file (instant, no decode)
    private func extractEmbeddedPreview(for asset: PhotoAsset, size: CGFloat) -> NSImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(size)
        ]
        
        guard let source = CGImageSourceCreateWithURL(asset.url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
    
    /// Generate thumbnail from image file using ImageIO
    private func generateThumbnail(for asset: PhotoAsset, size: CGFloat) -> NSImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(size),
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        
        guard let source = CGImageSourceCreateWithURL(asset.url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
    
    private func cacheInMemory(_ image: NSImage, for key: String) async {
        // Simple LRU-ish eviction
        if memoryCache.count >= maxMemoryCacheSize {
            // Remove oldest entries (simple approach)
            let keysToRemove = Array(memoryCache.keys.prefix(maxMemoryCacheSize / 4))
            for key in keysToRemove {
                memoryCache.removeValue(forKey: key)
            }
        }
        memoryCache[key] = image
    }
    
    nonisolated private static func enqueueDiskWrite(_ image: NSImage, at url: URL) {
        diskIOQueue.async {
            guard let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
                return
            }
            try? jpegData.write(to: url, options: .atomic)
        }
    }
    
    /// Clear all caches
    func clearCache() async {
        memoryCache.removeAll()
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    /// Check if thumbnail is cached (memory or disk)
    func isCached(for asset: PhotoAsset, size: CGFloat = 300) -> Bool {
        let cacheKey = Self.makeCacheKey(for: asset, size: size)
        
        if memoryCache[cacheKey] != nil {
            return true
        }
        
        let cacheFile = cacheDirectory.appendingPathComponent("\(cacheKey).jpg")
        return FileManager.default.fileExists(atPath: cacheFile.path)
    }

    /// Build a stable cache key that is unique per file path and invalidates on content change.
    nonisolated private static func makeCacheKey(for asset: PhotoAsset, size: CGFloat) -> String {
        let normalizedPath = asset.url.standardizedFileURL.path
        let pathHash = fnv1a64(normalizedPath)
        return "\(pathHash)_\(asset.fingerprint)_\(Int(size))"
    }

    /// Deterministic 64-bit FNV-1a hash (stable across launches).
    nonisolated private static func fnv1a64(_ text: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return String(hash, radix: 16)
    }
}
