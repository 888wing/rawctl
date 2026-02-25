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
    /// Exposure quality from histogram analysis, 0 (severely clipped) – 1 (well exposed).
    let exposureScore: Double
    /// Non-nil when this photo belongs to a near-duplicate group.
    let duplicateGroupId: UUID?
    /// True if this photo is the chosen representative of its group (highest combined score).
    /// Always true for unique photos (duplicateGroupId == nil).
    let isGroupRepresentative: Bool
    /// Suggested star rating (0–5) derived from combined score.
    let suggestedRating: Int
    /// Suggested flag derived from combined score.
    let suggestedFlag: Flag
}

/// Single source of truth for all culling scoring parameters.
struct CullingConfig: Sendable {
    // MARK: - Signal Weights (must sum to 1.0)
    let sharpnessWeight: Double
    let saliencyWeight: Double
    let exposureWeight: Double

    // MARK: - Rating Boundaries (ascending combined-score thresholds)
    let rejectBelow: Double
    let rating1Below: Double
    let rating2Below: Double
    let rating3Below: Double
    let rating4Below: Double

    // MARK: - Exposure Thresholds
    let highlightClipFraction: Double
    let shadowClipFraction: Double
    let highlightPenaltyRate: Double
    let shadowPenaltyRate: Double

    // MARK: - Duplicate Detection
    let duplicateDistanceThreshold: Float

    static let `default` = CullingConfig(
        sharpnessWeight: 0.45,
        saliencyWeight: 0.30,
        exposureWeight: 0.25,

        rejectBelow: 0.20,
        rating1Below: 0.40,
        rating2Below: 0.55,
        rating3Below: 0.70,
        rating4Below: 0.85,

        highlightClipFraction: 0.03,
        shadowClipFraction: 0.05,
        highlightPenaltyRate: 8.0,
        shadowPenaltyRate: 5.0,

        duplicateDistanceThreshold: 0.15
    )
}

/// Rich culling output persisted in the sidecar JSON.
/// Replaces `CullingScore` as the primary culling result type.
struct CullingAnalysis: Codable, Sendable, Equatable {
    /// Schema version for forward compatibility.
    let version: Int
    /// Weighted combination of all signal scores, 0–1.
    let overallScore: Double
    /// Sharpness/focus quality, 0 (blurry) – 1 (sharp).
    let sharpnessScore: Double
    /// Composition quality from attention saliency, 0–1.
    let saliencyScore: Double
    /// Exposure quality from histogram analysis, 0–1.
    let exposureScore: Double
    /// Non-nil when this photo belongs to a near-duplicate group.
    let duplicateGroupId: UUID?
    /// Rank within duplicate group (1 = best). Nil if unique photo.
    let duplicateRank: Int?
    /// Suggested star rating (0–5) derived from overall score.
    let suggestedRating: Int
    /// Suggested flag derived from overall score.
    let suggestedFlag: Flag
    /// Human-readable reasons for rejection/downranking.
    /// Empty array for well-rated photos.
    let rejectedReasons: [String]

    static let currentVersion = 1
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

    let config: CullingConfig

    /// Shared CIContext for histogram and sharpness rendering (expensive to create).
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    private init(config: CullingConfig = .default) {
        self.config = config
    }

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

        // ── Phase 1: Feature prints + sharpness/saliency/exposure (single thumbnail load per photo) ──
        var featurePrints: [UUID: VNFeaturePrintObservation] = [:]
        var rawScores: [UUID: (sharpness: Double, saliency: Double, exposure: Double)] = [:]
        featurePrints.reserveCapacity(assets.count)
        rawScores.reserveCapacity(assets.count)

        for (idx, asset) in assets.enumerated() {
            onProgress(idx, totalSteps)
            guard let image = loadThumbnail(for: asset) else { continue }
            if let fp = generateFeaturePrint(from: image) {
                featurePrints[asset.id] = fp
            }
            rawScores[asset.id] = (
                sharpness: scoreSharpness(image: image),
                saliency:  scoreSaliency(image: image),
                exposure:  scoreExposure(image: image)
            )
        }

        // ── Phase 2: Build groups, then compute final scores ──────────────────────────────
        let groups = buildDuplicateGroups(prints: featurePrints, scores: rawScores)

        var results: [UUID: CullingScore] = [:]
        results.reserveCapacity(assets.count)

        for (idx, asset) in assets.enumerated() {
            onProgress(assets.count + idx, totalSteps)
            guard let raw = rawScores[asset.id] else { continue }
            let group = groups[asset.id] ?? (groupId: nil, isRepresentative: true)
            results[asset.id] = computeFinalScore(
                sharpness: raw.sharpness,
                saliency:  raw.saliency,
                exposure:  raw.exposure,
                groupId:   group.groupId,
                isRepresentative: group.isRepresentative
            )
        }

        return results
    }

    /// Score a batch of assets using pre-built feature prints from FeaturePrintIndex.
    ///
    /// Avoids regenerating feature prints when an index already exists (e.g., from SmartSync).
    /// Falls back to internal generation for assets missing from the index.
    ///
    /// - Parameters:
    ///   - assets: The photos to score.
    ///   - existingPrints: Pre-computed feature prints keyed by asset ID.
    ///   - onProgress: Called with `(stepsCompleted, totalSteps)` after each step.
    /// - Returns: A dictionary mapping `PhotoAsset.id -> CullingAnalysis`.
    func scoreWithAnalysis(
        assets: [PhotoAsset],
        existingPrints: [UUID: VNFeaturePrintObservation] = [:],
        onProgress: @escaping @Sendable (Int, Int) -> Void
    ) async -> [UUID: CullingAnalysis] {
        guard !assets.isEmpty else { return [:] }

        let totalSteps = assets.count * 2

        // ── Phase 1: Feature prints + sharpness/saliency/exposure ──
        var featurePrints: [UUID: VNFeaturePrintObservation] = existingPrints
        var rawScores: [UUID: (sharpness: Double, saliency: Double, exposure: Double)] = [:]
        featurePrints.reserveCapacity(assets.count)
        rawScores.reserveCapacity(assets.count)

        for (idx, asset) in assets.enumerated() {
            onProgress(idx, totalSteps)
            guard let image = loadThumbnail(for: asset) else { continue }
            // Reuse existing print if available; generate only if missing.
            if featurePrints[asset.id] == nil {
                if let fp = generateFeaturePrint(from: image) {
                    featurePrints[asset.id] = fp
                }
            }
            rawScores[asset.id] = (
                sharpness: scoreSharpness(image: image),
                saliency:  scoreSaliency(image: image),
                exposure:  scoreExposure(image: image)
            )
        }

        // ── Phase 2: Build groups with rank, then build analysis ──
        let groups = buildDuplicateGroupsWithRank(prints: featurePrints, scores: rawScores)

        var results: [UUID: CullingAnalysis] = [:]
        results.reserveCapacity(assets.count)

        for (idx, asset) in assets.enumerated() {
            onProgress(assets.count + idx, totalSteps)
            guard let raw = rawScores[asset.id] else { continue }
            let group = groups[asset.id] ?? (groupId: nil, rank: nil, isRepresentative: true)
            results[asset.id] = buildAnalysis(
                sharpness: raw.sharpness,
                saliency:  raw.saliency,
                exposure:  raw.exposure,
                groupId:   group.groupId,
                duplicateRank: group.rank,
                isRepresentative: group.isRepresentative
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
        let context = ciContext
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

    // MARK: - Exposure Quality Scoring

    /// Returns an exposure quality score (0–1) based on luminance histogram clipping.
    ///
    /// Uses CIAreaHistogram to compute a 256-bin luminance histogram.
    /// Penalizes photos with clipped highlights (blown whites) or crushed shadows
    /// beyond configurable thresholds. Includes an artistic tolerance band so
    /// intentionally low-key or high-key images aren't over-penalized.
    ///
    /// - Returns: 1.0 for well-exposed images, decreasing toward 0 for severe clipping.
    private func scoreExposure(image: CGImage) -> Double {
        let ciImage = CIImage(cgImage: image)

        // Convert to grayscale luminance for histogram analysis.
        let gray = ciImage.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.0
        ])

        // CIAreaHistogram: 256 bins across the full image extent.
        guard let histFilter = CIFilter(name: "CIAreaHistogram") else { return 0.8 }
        histFilter.setValue(gray, forKey: kCIInputImageKey)
        histFilter.setValue(CIVector(cgRect: gray.extent), forKey: "inputExtent")
        histFilter.setValue(NSNumber(value: 256), forKey: "inputCount")
        histFilter.setValue(NSNumber(value: 1.0), forKey: "inputScale")

        guard let histImage = histFilter.outputImage else { return 0.8 }

        // Read the 256×1 histogram as float pixels.
        let context = ciContext
        var bins = [Float](repeating: 0, count: 256 * 4) // RGBA float
        context.render(
            histImage,
            toBitmap: &bins,
            rowBytes: 256 * 4 * MemoryLayout<Float>.size,
            bounds: CGRect(x: 0, y: 0, width: 256, height: 1),
            format: .RGBAf,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        // Extract the red channel (luminance in grayscale) counts.
        var luminanceBins = [Float](repeating: 0, count: 256)
        for i in 0..<256 {
            luminanceBins[i] = bins[i * 4] // R channel
        }

        let totalPixels = luminanceBins.reduce(0, +)
        guard totalPixels > 0 else { return 0.8 }

        // Fraction of pixels in shadow bin (0) and highlight bin (255).
        let shadowFraction  = Double(luminanceBins[0]) / Double(totalPixels)
        let highlightFraction = Double(luminanceBins[255]) / Double(totalPixels)

        // Also check near-black (0–4) and near-white (251–255) for broader clipping.
        let nearBlack = Double(luminanceBins[0...4].reduce(0, +)) / Double(totalPixels)
        let nearWhite = Double(luminanceBins[251...255].reduce(0, +)) / Double(totalPixels)

        let cfg = config

        // Compute penalties only beyond the artistic tolerance thresholds.
        let highlightExcess = max(0, highlightFraction - cfg.highlightClipFraction)
        let shadowExcess    = max(0, shadowFraction - cfg.shadowClipFraction)

        // Broader clipping is weighted at half rate (near-black/white bands).
        let broadHighlightExcess = max(0, nearWhite - cfg.highlightClipFraction * 2)
        let broadShadowExcess    = max(0, nearBlack - cfg.shadowClipFraction * 2)

        let highlightPenalty = highlightExcess * cfg.highlightPenaltyRate
                             + broadHighlightExcess * cfg.highlightPenaltyRate * 0.5
        let shadowPenalty    = shadowExcess * cfg.shadowPenaltyRate
                             + broadShadowExcess * cfg.shadowPenaltyRate * 0.5

        let score = max(0.0, 1.0 - highlightPenalty - shadowPenalty)
        return score
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

    /// Build duplicate groups from feature prints using pairwise distance.
    /// Returns a dict mapping assetId → (groupId, isRepresentative).
    /// Photos with no near-duplicates map to (nil, true).
    private func buildDuplicateGroups(
        prints: [UUID: VNFeaturePrintObservation],
        scores: [UUID: (sharpness: Double, saliency: Double, exposure: Double)]
    ) -> [UUID: (groupId: UUID?, isRepresentative: Bool)] {
        // Union-Find: parent[id] = id means it's a root.
        var parent: [UUID: UUID] = Dictionary(uniqueKeysWithValues: prints.keys.map { ($0, $0) })

        func find(_ id: UUID) -> UUID {
            // Pass 1: walk up to the root.
            var root = id
            while parent[root] != root { root = parent[root] ?? root }
            // Pass 2: point every node on the path directly to root.
            var node = id
            while node != root {
                let next = parent[node] ?? root
                parent[node] = root
                node = next
            }
            return root
        }

        func union(_ a: UUID, _ b: UUID) {
            let ra = find(a), rb = find(b)
            if ra != rb { parent[ra] = rb }
        }

        // Pairwise distance; O(n²) — acceptable for typical batch sizes.
        let ids = Array(prints.keys)
        for i in 0..<ids.count {
            guard let pi = prints[ids[i]] else { continue }
            for j in (i + 1)..<ids.count {
                guard let pj = prints[ids[j]] else { continue }
                var distance: Float = 0
                if (try? pi.computeDistance(&distance, to: pj)) != nil,
                   distance < config.duplicateDistanceThreshold {
                    union(ids[i], ids[j])
                }
            }
        }

        // Collect groups: root → [members]
        var groups: [UUID: [UUID]] = [:]
        for id in ids {
            let root = find(id)
            groups[root, default: []].append(id)
        }

        // Assign representative per group (highest combined score).
        var result: [UUID: (groupId: UUID?, isRepresentative: Bool)] = [:]
        for (_, members) in groups {
            if members.count == 1 {
                // Unique photo — not a duplicate.
                result[members[0]] = (groupId: nil, isRepresentative: true)
            } else {
                let groupId = UUID()
                let rep = members.max(by: { a, b in
                    let cfg = CullingConfig.default
                    let sa = (scores[a]?.sharpness ?? 0) * cfg.sharpnessWeight
                           + (scores[a]?.saliency ?? 0)  * cfg.saliencyWeight
                    let sb = (scores[b]?.sharpness ?? 0) * cfg.sharpnessWeight
                           + (scores[b]?.saliency ?? 0)  * cfg.saliencyWeight
                    return sa < sb
                })
                for member in members {
                    result[member] = (groupId: groupId, isRepresentative: member == rep)
                }
            }
        }
        return result
    }

    /// Build duplicate groups with ranked members (1 = best in group).
    /// Returns dict mapping assetId -> (groupId, rank, isRepresentative).
    private func buildDuplicateGroupsWithRank(
        prints: [UUID: VNFeaturePrintObservation],
        scores: [UUID: (sharpness: Double, saliency: Double, exposure: Double)]
    ) -> [UUID: (groupId: UUID?, rank: Int?, isRepresentative: Bool)] {
        // Union-Find: same algorithm as buildDuplicateGroups.
        var parent: [UUID: UUID] = Dictionary(uniqueKeysWithValues: prints.keys.map { ($0, $0) })

        func find(_ id: UUID) -> UUID {
            var root = id
            while parent[root] != root { root = parent[root] ?? root }
            var node = id
            while node != root {
                let next = parent[node] ?? root
                parent[node] = root
                node = next
            }
            return root
        }

        func union(_ a: UUID, _ b: UUID) {
            let ra = find(a), rb = find(b)
            if ra != rb { parent[ra] = rb }
        }

        let ids = Array(prints.keys)
        for i in 0..<ids.count {
            guard let pi = prints[ids[i]] else { continue }
            for j in (i + 1)..<ids.count {
                guard let pj = prints[ids[j]] else { continue }
                var distance: Float = 0
                if (try? pi.computeDistance(&distance, to: pj)) != nil,
                   distance < config.duplicateDistanceThreshold {
                    union(ids[i], ids[j])
                }
            }
        }

        var groups: [UUID: [UUID]] = [:]
        for id in ids {
            let root = find(id)
            groups[root, default: []].append(id)
        }

        let cfg = CullingConfig.default
        var result: [UUID: (groupId: UUID?, rank: Int?, isRepresentative: Bool)] = [:]

        for (_, members) in groups {
            if members.count == 1 {
                result[members[0]] = (groupId: nil, rank: nil, isRepresentative: true)
            } else {
                let groupId = UUID()
                // Sort by combined score descending to assign rank.
                let sorted = members.sorted { a, b in
                    let sa = (scores[a]?.sharpness ?? 0) * cfg.sharpnessWeight
                           + (scores[a]?.saliency ?? 0)  * cfg.saliencyWeight
                           + (scores[a]?.exposure ?? 0)   * cfg.exposureWeight
                    let sb = (scores[b]?.sharpness ?? 0) * cfg.sharpnessWeight
                           + (scores[b]?.saliency ?? 0)  * cfg.saliencyWeight
                           + (scores[b]?.exposure ?? 0)   * cfg.exposureWeight
                    return sa > sb
                }
                for (rank, member) in sorted.enumerated() {
                    result[member] = (
                        groupId: groupId,
                        rank: rank + 1,  // 1-indexed
                        isRepresentative: rank == 0
                    )
                }
            }
        }
        return result
    }

    // MARK: - Score → Rating + Flag

    nonisolated func computeFinalScore(
        sharpness: Double,
        saliency: Double,
        exposure: Double = 1.0,
        groupId: UUID?,
        isRepresentative: Bool
    ) -> CullingScore {
        // Uses CullingConfig.default directly because this method is nonisolated
        // and cannot access actor-isolated self.config. Safe because init is private
        // and shared singleton always uses .default.
        let cfg = CullingConfig.default
        let combined = sharpness * cfg.sharpnessWeight
                     + saliency  * cfg.saliencyWeight
                     + exposure  * cfg.exposureWeight
        let isNonRepDuplicate = groupId != nil && !isRepresentative

        let (rating, flag): (Int, Flag)
        switch (isNonRepDuplicate, combined) {
        case (true, _):               (rating, flag) = (0, .reject)
        case (_, ..<cfg.rejectBelow):  (rating, flag) = (0, .reject)
        case (_, ..<cfg.rating1Below): (rating, flag) = (1, .none)
        case (_, ..<cfg.rating2Below): (rating, flag) = (2, .none)
        case (_, ..<cfg.rating3Below): (rating, flag) = (3, .none)
        case (_, ..<cfg.rating4Below): (rating, flag) = (4, .pick)
        default:                       (rating, flag) = (5, .pick)
        }

        return CullingScore(
            sharpness: sharpness,
            saliency:  saliency,
            exposureScore: exposure,
            duplicateGroupId: groupId,
            isGroupRepresentative: isRepresentative,
            suggestedRating: rating,
            suggestedFlag:   flag
        )
    }

    /// Build a full CullingAnalysis with rejection reasons derived from signal scores.
    nonisolated func buildAnalysis(
        sharpness: Double,
        saliency: Double,
        exposure: Double,
        groupId: UUID?,
        duplicateRank: Int?,
        isRepresentative: Bool
    ) -> CullingAnalysis {
        // Uses CullingConfig.default directly because this method is nonisolated.
        let cfg = CullingConfig.default
        let combined = sharpness * cfg.sharpnessWeight
                     + saliency  * cfg.saliencyWeight
                     + exposure  * cfg.exposureWeight
        let isNonRepDuplicate = groupId != nil && !isRepresentative

        let (rating, flag): (Int, Flag)
        switch (isNonRepDuplicate, combined) {
        case (true, _):               (rating, flag) = (0, .reject)
        case (_, ..<cfg.rejectBelow):  (rating, flag) = (0, .reject)
        case (_, ..<cfg.rating1Below): (rating, flag) = (1, .none)
        case (_, ..<cfg.rating2Below): (rating, flag) = (2, .none)
        case (_, ..<cfg.rating3Below): (rating, flag) = (3, .none)
        case (_, ..<cfg.rating4Below): (rating, flag) = (4, .pick)
        default:                       (rating, flag) = (5, .pick)
        }

        var reasons: [String] = []
        if isNonRepDuplicate {
            reasons.append("duplicate_non_best")
        }
        if sharpness < 0.25 {
            reasons.append("blurry")
        }
        if saliency < 0.20 {
            reasons.append("poor_composition")
        }
        if exposure < 0.40 {
            reasons.append("exposure_clipped")
        }

        return CullingAnalysis(
            version: CullingAnalysis.currentVersion,
            overallScore: combined,
            sharpnessScore: sharpness,
            saliencyScore: saliency,
            exposureScore: exposure,
            duplicateGroupId: groupId,
            duplicateRank: duplicateRank,
            suggestedRating: rating,
            suggestedFlag: flag,
            rejectedReasons: reasons
        )
    }
}
