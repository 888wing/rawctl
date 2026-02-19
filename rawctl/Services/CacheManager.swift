//
//  CacheManager.swift
//  rawctl
//
//  Unified cache management with memory pressure monitoring
//

import Foundation
import AppKit

/// Unified cache manager for controlling memory usage across the app
actor CacheManager {
    static let shared = CacheManager()
    
    // MARK: - Memory Limits
    
    private let memoryLimitBytes: Int = 500_000_000  // 500MB total
    private let thumbnailCacheLimit = 200
    private let previewCacheLimit = 20
    private let exifCacheLimit = 500
    
    // MARK: - Cache Statistics
    
    struct CacheStats {
        var thumbnailCount: Int = 0
        var previewCount: Int = 0
        var exifCount: Int = 0
        var estimatedMemoryBytes: Int = 0
        var thumbnailMemoryHits: Int = 0
        var thumbnailDiskHits: Int = 0
        var thumbnailMisses: Int = 0
        var previewHits: Int = 0
        var previewMisses: Int = 0
        var evictedBytes: Int64 = 0
        var evictedEntries: Int = 0
        var evictionEvents: Int = 0
        var churnRatio: Double {
            let denominator = max(1, thumbnailCount + previewCount + evictedEntries)
            return Double(evictedEntries) / Double(denominator)
        }
    }
    
    private var stats = CacheStats()
    private var lastPressureCheck = Date()
    
    // MARK: - Memory Pressure Monitoring
    
    init() {
        setupMemoryPressureMonitoring()
    }
    
    nonisolated private func setupMemoryPressureMonitoring() {
        // Monitor memory pressure using dispatch source
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .global()
        )
        
        source.setEventHandler { [weak self] in
            Task {
                await self?.handleMemoryPressure(source.data)
            }
        }
        
        source.resume()
    }
    
    private func handleMemoryPressure(_ pressure: DispatchSource.MemoryPressureEvent) {
        print("[CacheManager] Memory pressure: \(pressure)")
        
        switch pressure {
        case .warning:
            // Clear 50% of caches
            Task {
                await evictCaches(targetReduction: 0.5)
            }
        case .critical:
            // Emergency clear - drop everything non-essential
            Task {
                await emergencyClear()
            }
        default:
            break
        }
    }
    
    // MARK: - Cache Eviction

    private func refreshStatsFromServices() async {
        let thumbnailTelemetry = await ThumbnailService.shared.cacheTelemetry()
        let previewTelemetry = await ImagePipeline.shared.previewCacheTelemetry()

        stats.thumbnailCount = thumbnailTelemetry.entryCount
        stats.previewCount = previewTelemetry.entryCount
        stats.estimatedMemoryBytes = Int(
            thumbnailTelemetry.estimatedMemoryBytes + previewTelemetry.estimatedMemoryBytes
        )
        stats.thumbnailMemoryHits = thumbnailTelemetry.memoryHits
        stats.thumbnailDiskHits = thumbnailTelemetry.diskHits
        stats.thumbnailMisses = thumbnailTelemetry.misses
        stats.previewHits = previewTelemetry.hits
        stats.previewMisses = previewTelemetry.misses
        stats.evictedEntries = thumbnailTelemetry.evictedEntries + previewTelemetry.evictedEntries
        stats.evictedBytes = thumbnailTelemetry.evictedBytes + previewTelemetry.evictedBytes
    }
    
    /// Evict caches to reduce memory usage
    func evictCaches(targetReduction: Double) async {
        await refreshStatsFromServices()
        let clampedReduction = min(max(targetReduction, 0), 1)
        print("[CacheManager] Evicting \(Int(clampedReduction * 100))% of caches")
        
        // Priority: evict thumbnails more aggressively; keep preview cache warmer unless pressure is high.
        let thumbnailReduction = clampedReduction
        let previewReduction = max(0, clampedReduction - 0.25)
        let thumbnailsToRemove = Int(Double(stats.thumbnailCount) * thumbnailReduction)
        let previewsToRemove = Int(Double(stats.previewCount) * previewReduction)
        
        let removedThumbnails = await ThumbnailService.shared.evictMemoryEntries(count: thumbnailsToRemove)
        let removedPreviews = await ImagePipeline.shared.evictPreviewEntries(count: previewsToRemove)
        
        let removedEntries = removedThumbnails.entries + removedPreviews.entries
        let removedBytes = removedThumbnails.estimatedBytes + removedPreviews.estimatedBytes
        stats.evictionEvents += 1
        stats.evictedEntries += removedEntries
        stats.evictedBytes += removedBytes

        await refreshStatsFromServices()
    }
    
    /// Emergency clear all caches
    func emergencyClear() async {
        print("[CacheManager] Emergency clear!")
        
        let removedThumbnails = await ThumbnailService.shared.clearInMemoryCache()
        let removedPreviews = await ImagePipeline.shared.clearAllPreviewCaches()
        await EXIFService.shared.clearCache()
        
        stats.evictionEvents += 1
        stats.evictedEntries += removedThumbnails.entries + removedPreviews.entries
        stats.evictedBytes += removedThumbnails.estimatedBytes + removedPreviews.estimatedBytes
        stats.exifCount = 0
        await refreshStatsFromServices()
    }
    
    // MARK: - Cache Registration
    
    /// Register thumbnail cache entry
    func registerThumbnail(sizeBytes: Int) {
        stats.thumbnailCount += 1
        stats.estimatedMemoryBytes += sizeBytes
        checkMemoryLimit()
    }
    
    /// Register preview cache entry
    func registerPreview(sizeBytes: Int) {
        stats.previewCount += 1
        stats.estimatedMemoryBytes += sizeBytes
        checkMemoryLimit()
    }
    
    /// Register EXIF cache entry
    func registerEXIF() {
        stats.exifCount += 1
        stats.estimatedMemoryBytes += 1000  // ~1KB per EXIF entry
    }
    
    /// Unregister cache entries
    func unregisterThumbnails(count: Int, sizeBytes: Int) {
        stats.thumbnailCount = max(0, stats.thumbnailCount - count)
        stats.estimatedMemoryBytes = max(0, stats.estimatedMemoryBytes - sizeBytes)
    }
    
    // MARK: - Memory Checking
    
    private func checkMemoryLimit() {
        // Only check every 5 seconds to avoid overhead
        guard Date().timeIntervalSince(lastPressureCheck) > 5 else { return }
        lastPressureCheck = Date()
        
        if stats.estimatedMemoryBytes > memoryLimitBytes {
            let overageRatio = Double(stats.estimatedMemoryBytes - memoryLimitBytes) / Double(memoryLimitBytes)
            let targetReduction = min(0.5, overageRatio + 0.1)  // At least 10% reduction
            
            Task {
                await evictCaches(targetReduction: targetReduction)
            }
        }
    }
    
    // MARK: - Status
    
    /// Get current cache statistics
    func getStats() -> CacheStats {
        return stats
    }

    /// Refresh and return current cache statistics (includes live hit/miss + eviction telemetry).
    func currentStats() async -> CacheStats {
        await refreshStatsFromServices()
        return stats
    }
    
    /// Get memory usage as percentage of limit
    var memoryUsagePercent: Double {
        Double(stats.estimatedMemoryBytes) / Double(memoryLimitBytes) * 100
    }
    
    // MARK: - AI Cache Management
    
    /// Base directory for AI caches
    nonisolated var aiCacheBaseURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("rawctl/cache/ai", isDirectory: true)
    }
    
    /// Get cache directory for a specific asset
    nonisolated func aiCacheDirectory(for assetFingerprint: String) -> URL {
        let dir = aiCacheBaseURL.appendingPathComponent(assetFingerprint, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    /// Get path for an AI edit result
    nonisolated func aiResultPath(assetFingerprint: String, editId: UUID) -> URL {
        aiCacheDirectory(for: assetFingerprint).appendingPathComponent("\(editId.uuidString)_result.jpg")
    }
    
    /// Get path for an AI edit mask
    nonisolated func aiMaskPath(assetFingerprint: String, editId: UUID) -> URL {
        aiCacheDirectory(for: assetFingerprint).appendingPathComponent("\(editId.uuidString)_mask.png")
    }
    
    /// Get path for an AI edit reference image
    nonisolated func aiReferencePath(assetFingerprint: String, editId: UUID) -> URL {
        aiCacheDirectory(for: assetFingerprint).appendingPathComponent("\(editId.uuidString)_reference.jpg")
    }
    
    /// Clean up old AI caches (older than specified days)
    func cleanupOldAICaches(olderThanDays: Int = 30) async {
        let fileManager = FileManager.default
        let cutoffDate = Date().addingTimeInterval(-Double(olderThanDays) * 24 * 60 * 60)
        
        guard let enumerator = fileManager.enumerator(
            at: aiCacheBaseURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        
        var filesToDelete: [URL] = []
        var totalSize: Int64 = 0
        
        // Avoid `DirectoryEnumerator` Sequence iteration in async context (Swift 6 `noasync`).
        while let fileURL = enumerator.nextObject() as? URL {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                  let modificationDate = resourceValues.contentModificationDate,
                  modificationDate < cutoffDate else {
                continue
            }
            
            filesToDelete.append(fileURL)
            totalSize += Int64(resourceValues.fileSize ?? 0)
        }
        
        // Delete old files
        for fileURL in filesToDelete {
            try? fileManager.removeItem(at: fileURL)
        }
        
        // Remove empty directories
        cleanupEmptyDirectories(in: aiCacheBaseURL)
        
        if !filesToDelete.isEmpty {
            print("[CacheManager] Cleaned up \(filesToDelete.count) old AI cache files (\(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)))")
        }
    }
    
    /// Remove empty directories recursively
    private nonisolated func cleanupEmptyDirectories(in directory: URL) {
        let fileManager = FileManager.default
        
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        
        for item in contents {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory), isDirectory.boolValue {
                cleanupEmptyDirectories(in: item)
                
                // Check if directory is now empty
                if let subContents = try? fileManager.contentsOfDirectory(atPath: item.path), subContents.isEmpty {
                    try? fileManager.removeItem(at: item)
                }
            }
        }
    }
    
    /// Get total AI cache size
    func getAICacheSize() -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0
        
        guard let enumerator = fileManager.enumerator(
            at: aiCacheBaseURL,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(size)
            }
        }
        
        return totalSize
    }
    
    /// Delete AI cache for a specific asset
    func deleteAICache(for assetFingerprint: String) {
        let dir = aiCacheDirectory(for: assetFingerprint)
        try? FileManager.default.removeItem(at: dir)
    }
    
    /// Delete a specific AI edit's cache files
    func deleteAIEditCache(assetFingerprint: String, editId: UUID) {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: aiResultPath(assetFingerprint: assetFingerprint, editId: editId))
        try? fileManager.removeItem(at: aiMaskPath(assetFingerprint: assetFingerprint, editId: editId))
        try? fileManager.removeItem(at: aiReferencePath(assetFingerprint: assetFingerprint, editId: editId))
    }
}
