//
//  FeaturePrintIndex.swift
//  rawctl
//
//  Session-scoped cache of VNFeaturePrintObservation per asset.
//  Shared between SmartSyncService and (optionally) future services
//  that need visual-similarity comparisons without re-encoding images.
//

import Foundation
import Vision
import ImageIO

/// Thread-safe, session-scoped index of Apple Vision feature prints.
///
/// Feature prints are generated lazily and cached in memory for the
/// lifetime of the session. The index is automatically cleared when the
/// folder changes (call `reset()` from AppState on folder load).
///
/// `VNFeaturePrintObservation` encodes each image as a 512-element float
/// vector using the same model Photos.app uses for smart albums —
/// ANE-accelerated on Apple Silicon, < 100 ms per image on M1.
actor FeaturePrintIndex {

    static let shared = FeaturePrintIndex()
    private init() {}

    // MARK: - Storage

    private var prints: [UUID: VNFeaturePrintObservation] = [:]

    // MARK: - Public API

    /// Return the feature print for `asset`, generating and caching it if needed.
    /// Returns `nil` if the image cannot be loaded or Vision fails.
    func featurePrint(for asset: PhotoAsset) async -> VNFeaturePrintObservation? {
        if let cached = prints[asset.id] { return cached }
        guard let image = loadThumbnail(for: asset),
              let fp    = generateFeaturePrint(from: image) else { return nil }
        prints[asset.id] = fp
        return fp
    }

    /// Build (or warm) the index for a batch of assets.
    ///
    /// Skips assets already in the cache. Calls `onProgress(done, total)`
    /// after each asset is processed (including cache hits).
    ///
    /// - Returns: number of prints that are now in the index.
    @discardableResult
    func buildIndex(
        assets: [PhotoAsset],
        onProgress: @Sendable (Int, Int) -> Void
    ) async -> Int {
        let total = assets.count
        var indexed = 0
        for (idx, asset) in assets.enumerated() {
            onProgress(idx, total)
            if prints[asset.id] != nil {
                indexed += 1
            } else if let image = loadThumbnail(for: asset),
                      let fp    = generateFeaturePrint(from: image) {
                prints[asset.id] = fp
                indexed += 1
            }
        }
        onProgress(total, total)
        return indexed
    }

    /// A snapshot of all currently-cached prints.
    func allPrints() -> [UUID: VNFeaturePrintObservation] { prints }

    /// Remove a single cached print (e.g. after the source file changes).
    func invalidate(_ assetId: UUID) {
        prints.removeValue(forKey: assetId)
    }

    /// Clear the entire index (e.g. when a new folder is opened).
    func reset() {
        prints.removeAll()
    }

    // MARK: - Private Helpers

    /// Load a ≤512 px thumbnail via ImageIO.
    /// Uses the embedded RAW preview (index 1) when available for speed.
    private func loadThumbnail(for asset: PhotoAsset) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(asset.url as CFURL, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform:    true,
            kCGImageSourceThumbnailMaxPixelSize:           512,
        ]
        let count = CGImageSourceGetCount(source)
        if count > 1,
           let preview = CGImageSourceCreateThumbnailAtIndex(source, 1, options as CFDictionary) {
            return preview
        }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Run `VNGenerateImageFeaturePrintRequest` on a `CGImage`.
    private func generateFeaturePrint(from image: CGImage) -> VNFeaturePrintObservation? {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
            return request.results?.first as? VNFeaturePrintObservation
        } catch {
            return nil
        }
    }
}
