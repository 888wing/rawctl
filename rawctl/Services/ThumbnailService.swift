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
    private let maxMemoryCacheSize = 200
    
    /// Default timeout for thumbnail generation (seconds)
    private let defaultTimeout: TimeInterval = 5.0
    
    init() {
        // Set up cache directory
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = caches
            .appendingPathComponent("Shacoworkshop.rawctl", isDirectory: true)
            .appendingPathComponent("thumbnails", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    /// Get thumbnail for an asset with timeout protection
    /// - Parameters:
    ///   - asset: The photo asset to generate thumbnail for
    ///   - size: Target thumbnail size (default 300px)
    ///   - timeout: Maximum time to wait for generation (default 5 seconds)
    /// - Returns: Generated thumbnail or nil if failed/timeout
    func thumbnail(for asset: PhotoAsset, size: CGFloat = 300, timeout: TimeInterval? = nil) async -> NSImage? {
        let cacheKey = "\(asset.fingerprint)_\(Int(size))"
        let effectiveTimeout = timeout ?? defaultTimeout
        
        // Check memory cache first (instant)
        if let cached = memoryCache[cacheKey] {
            return cached
        }
        
        // Check disk cache (fast)
        let cacheFile = cacheDirectory.appendingPathComponent("\(cacheKey).jpg")
        if FileManager.default.fileExists(atPath: cacheFile.path),
           let image = NSImage(contentsOf: cacheFile) {
            await cacheInMemory(image, for: cacheKey)
            return image
        }
        
        // Generate thumbnail with timeout
        let result = await generateWithTimeout(for: asset, size: size, timeout: effectiveTimeout)
        
        guard let thumbnail = result else {
            // Generation failed or timed out
            return nil
        }
        
        // Save to disk cache (async, don't wait)
        Task {
            await saveToDisk(thumbnail, at: cacheFile)
        }
        
        // Cache in memory
        await cacheInMemory(thumbnail, for: cacheKey)
        
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
    
    private func saveToDisk(_ image: NSImage, at url: URL) async {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
            return
        }
        try? jpegData.write(to: url)
    }
    
    /// Clear all caches
    func clearCache() async {
        memoryCache.removeAll()
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    /// Check if thumbnail is cached (memory or disk)
    func isCached(for asset: PhotoAsset, size: CGFloat = 300) -> Bool {
        let cacheKey = "\(asset.fingerprint)_\(Int(size))"
        
        if memoryCache[cacheKey] != nil {
            return true
        }
        
        let cacheFile = cacheDirectory.appendingPathComponent("\(cacheKey).jpg")
        return FileManager.default.fileExists(atPath: cacheFile.path)
    }
}
