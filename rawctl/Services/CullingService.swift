//
//  CullingService.swift
//  rawctl
//
//  On-device AI photo culling using Apple Vision framework.
//  Scores sharpness, composition, and detects duplicates — zero cloud dependency,
//  zero model download. ANE-accelerated on Apple Silicon.
//

import Foundation
import Vision
import CoreImage
import ImageIO

/// Score produced for a single photo by the culling pass.
struct CullingScore: Sendable {
    /// Sharpness/focus quality, 0 (blurry) – 1 (sharp).
    let sharpness: Double
    /// Composition quality from attention saliency map, 0 – 1.
    let saliency: Double
    /// True if a near-identical image was found in the same batch.
    let isDuplicate: Bool
    /// Suggested star rating (0–5) derived from combined score.
    let suggestedRating: Int
    /// Suggested flag derived from combined score.
    let suggestedFlag: Flag
}

/// On-device photo culling via Apple Vision framework.
///
/// Usage:
/// ```swift
/// let scores = await CullingService.shared.score(assets: appState.assets) { done, total in
///     // update progress
/// }
/// ```
actor CullingService {

    static let shared = CullingService()
    private init() {}

    /// Distance threshold below which two photos are considered duplicates.
    /// VNFeaturePrintObservation distances range 0 (identical) upward.
    private let duplicateDistanceThreshold: Float = 0.15

    // MARK: - Public API

    /// Score a batch of assets using Vision framework signals.
    ///
    /// Runs in two phases:
    /// 1. Generate image feature prints for all assets (duplicate detection).
    /// 2. Score each asset for sharpness and composition.
    ///
    /// - Parameters:
    ///   - assets: The photos to score.
    ///   - onProgress: Called with `(stepsCompleted, totalSteps)` after each step.
    ///     Total steps = `assets.count * 2` (two phases).
    /// - Returns: A dictionary mapping `PhotoAsset.id → CullingScore`.
    func score(
        assets: [PhotoAsset],
        onProgress: @escaping @Sendable (Int, Int) -> Void
    ) async -> [UUID: CullingScore] {
        guard !assets.isEmpty else { return [:] }

        let totalSteps = assets.count * 2

        // ── Phase 1: Feature prints for duplicate detection ──────────────────
        var featurePrints: [UUID: VNFeaturePrintObservation] = [:]
        featurePrints.reserveCapacity(assets.count)

        for (idx, asset) in assets.enumerated() {
            onProgress(idx, totalSteps)
            if let image = loadThumbnail(for: asset),
               let fp = generateFeaturePrint(from: image) {
                featurePrints[asset.id] = fp
            }
        }

        // ── Phase 2: Score each asset ─────────────────────────────────────────
        var results: [UUID: CullingScore] = [:]
        results.reserveCapacity(assets.count)

        for (idx, asset) in assets.enumerated() {
            onProgress(assets.count + idx, totalSteps)
            guard let image = loadThumbnail(for: asset) else { continue }

            let sharpness = scoreSharpness(image: image)
            let saliency  = scoreSaliency(image: image)
            let isDupe    = detectDuplicate(assetId: asset.id, in: featurePrints)

            results[asset.id] = computeFinalScore(
                sharpness: sharpness,
                saliency: saliency,
                isDuplicate: isDupe
            )
        }

        return results
    }

    // MARK: - Image Loading

    /// Load a ≤512 px thumbnail via ImageIO.
    /// Uses the embedded preview in RAW files when available (fast path).
    private func loadThumbnail(for asset: PhotoAsset) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(asset.url as CFURL, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 512
        ]

        // RAW files typically store an embedded preview at index 1.
        let count = CGImageSourceGetCount(source)
        if count > 1,
           let preview = CGImageSourceCreateThumbnailAtIndex(source, 1, options as CFDictionary) {
            return preview
        }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    // MARK: - Sharpness Scoring

    private func scoreSharpness(image: CGImage) -> Double {
        // Portraits: use VNDetectFaceCaptureQualityRequest (purpose-built for focus quality).
        if let faceQuality = faceCaptureQuality(image: image) {
            return Double(faceQuality)
        }
        // Landscapes / objects: Laplacian edge-variance via Core Image.
        return laplacianSharpness(image: image)
    }

    /// Returns `faceCaptureQuality` (0–1) for the primary detected face, or `nil` if none.
    private func faceCaptureQuality(image: CGImage) -> Float? {
        let request = VNDetectFaceCaptureQualityRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
            return request.results?.first?.faceCaptureQuality
        } catch {
            return nil
        }
    }

    /// Laplacian-based sharpness estimate (0 = blurry, 1 = sharp).
    private func laplacianSharpness(image: CGImage) -> Double {
        let ciImage = CIImage(cgImage: image)

        // Convert to grayscale before applying Laplacian (edge detector).
        let gray = ciImage.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.0
        ])

        guard let laplacian = CIFilter(name: "CIConvolution3X3") else { return 0.5 }
        let kernel: [CGFloat] = [0, -1, 0, -1, 4, -1, 0, -1, 0]
        laplacian.setValue(gray, forKey: kCIInputImageKey)
        laplacian.setValue(CIVector(values: kernel, count: 9), forKey: "inputWeights")
        laplacian.setValue(NSNumber(value: 0.0), forKey: "inputBias")

        guard let output = laplacian.outputImage else { return 0.5 }

        // Sample a 1×1 pixel from the centre — its brightness encodes mean edge energy.
        let context = CIContext(options: [.useSoftwareRenderer: false])
        var pixel = [UInt8](repeating: 0, count: 4)
        let samplePoint = CGRect(
            x: output.extent.midX,
            y: output.extent.midY,
            width: 1, height: 1
        )
        context.render(output, toBitmap: &pixel, rowBytes: 4,
                       bounds: samplePoint, format: .RGBA8,
                       colorSpace: CGColorSpaceCreateDeviceRGB())

        // Sharp images produce higher Laplacian values; scale to 0–1 range.
        let intensity = Double(pixel[0]) / 255.0
        return min(1.0, intensity * 4.0)
    }

    // MARK: - Saliency / Composition Scoring

    /// Returns a composition score (0–1) based on Vision attention saliency map.
    /// Well-composed photos tend to have larger, more concentrated salient regions.
    private func scoreSaliency(image: CGImage) -> Double {
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
            guard let result = request.results?.first as? VNSaliencyImageObservation else {
                return 0.5
            }
            // Sum of salient bounding-box areas (normalised 0–1 per axis).
            let totalArea = result.salientObjects?.reduce(0.0) {
                $0 + Double($1.boundingBox.width * $1.boundingBox.height)
            } ?? 0.3
            return min(1.0, totalArea * 2.5)
        } catch {
            return 0.5
        }
    }

    // MARK: - Duplicate Detection

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

    private func detectDuplicate(
        assetId: UUID,
        in prints: [UUID: VNFeaturePrintObservation]
    ) -> Bool {
        guard let mine = prints[assetId] else { return false }
        for (otherId, other) in prints where otherId != assetId {
            var distance: Float = 0
            if (try? mine.computeDistance(&distance, to: other)) != nil,
               distance < duplicateDistanceThreshold {
                return true
            }
        }
        return false
    }

    // MARK: - Score → Rating + Flag

    private func computeFinalScore(
        sharpness: Double,
        saliency: Double,
        isDuplicate: Bool
    ) -> CullingScore {
        let combined = sharpness * 0.6 + saliency * 0.4

        let (rating, flag): (Int, Flag)
        switch (isDuplicate, combined) {
        case (true, _):      (rating, flag) = (0, .reject)
        case (_, ..<0.20):   (rating, flag) = (0, .reject)
        case (_, ..<0.40):   (rating, flag) = (1, .none)
        case (_, ..<0.55):   (rating, flag) = (2, .none)
        case (_, ..<0.70):   (rating, flag) = (3, .none)
        case (_, ..<0.85):   (rating, flag) = (4, .pick)
        default:             (rating, flag) = (5, .pick)
        }

        return CullingScore(
            sharpness: sharpness,
            saliency: saliency,
            isDuplicate: isDuplicate,
            suggestedRating: rating,
            suggestedFlag: flag
        )
    }
}
