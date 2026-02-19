//
//  SmartSyncService.swift
//  rawctl
//
//  Scene-aware recipe synchronisation via Apple Vision feature prints.
//
//  "You edit one photo; Smart Sync handles the rest."
//
//  How it works:
//    1. Build Vision feature prints for all assets (VNGenerateImageFeaturePrintRequest).
//    2. Rank candidates by feature-print distance from the source photo.
//    3. For each similar candidate, adapt the source recipe:
//       - Exposure is offset by the computed EV difference (from EXIF).
//       - All other parameters (WB, contrast, vignette, …) are preserved as-is.
//    4. Return SmartSyncMatch results for the user to confirm before committing.
//
//  Everything runs on-device via ANE-accelerated Vision. Zero cloud dependency.
//

import Foundation
import Vision

// MARK: - Match Result

/// A single candidate that matched the source scene, with an already-adapted recipe.
struct SmartSyncMatch: Identifiable, Sendable {
    /// Matches the candidate's `PhotoAsset.id`.
    let id: UUID
    let asset: PhotoAsset
    /// Vision feature-print distance (lower = more visually similar).
    let distance: Float
    /// The source recipe adapted to this target's exposure characteristics.
    let adaptedRecipe: EditRecipe
}

// MARK: - Service

/// Scene-aware recipe synchronisation.
///
/// Usage:
/// ```swift
/// let matches = await SmartSyncService.shared.findAndAdapt(
///     source: selectedAsset,
///     sourceRecipe: appState.recipes[selectedAsset.id] ?? EditRecipe(),
///     candidates: appState.assets,
///     onProgress: { done, total in … }
/// )
/// // Present confirmation sheet → on confirm:
/// for match in userConfirmedMatches {
///     // save match.adaptedRecipe via SidecarService
/// }
/// ```
actor SmartSyncService {

    static let shared = SmartSyncService()
    private init() {}

    // MARK: - Configuration

    /// Vision distance threshold for scene matching.
    /// Typical same-scene shots (same framing / lighting): 0.05 – 0.35.
    /// Different scenes / very different lighting:          > 0.50.
    ///
    /// Lower values = stricter similarity required.
    var similarityThreshold: Float = 0.40

    // MARK: - Public API

    /// Find visually similar assets and produce per-target adapted recipes.
    ///
    /// - Parameters:
    ///   - source: The reference photo whose recipe will be synchronised.
    ///   - sourceRecipe: The recipe to adapt.
    ///   - candidates: All photos to search (source is excluded automatically).
    ///   - onProgress: Called with `(stepsCompleted, total)` during index building.
    /// - Returns: Matches sorted by ascending distance (most similar first).
    func findAndAdapt(
        source: PhotoAsset,
        sourceRecipe: EditRecipe,
        candidates: [PhotoAsset],
        onProgress: @escaping @Sendable (Int, Int) -> Void = { _, _ in }
    ) async -> [SmartSyncMatch] {
        let others = candidates.filter { $0.id != source.id }
        guard !others.isEmpty else { return [] }

        // Build / warm the shared feature print index.
        let allAssets = [source] + others
        await FeaturePrintIndex.shared.buildIndex(assets: allAssets, onProgress: onProgress)

        guard let sourcePrint = await FeaturePrintIndex.shared.featurePrint(for: source) else {
            return []
        }

        var matches: [SmartSyncMatch] = []
        for asset in others {
            guard let targetPrint = await FeaturePrintIndex.shared.featurePrint(for: asset) else {
                continue
            }
            var distance: Float = .infinity
            if (try? sourcePrint.computeDistance(&distance, to: targetPrint)) != nil,
               distance < similarityThreshold {
                let adapted = adaptRecipe(sourceRecipe, from: source, to: asset)
                matches.append(SmartSyncMatch(
                    id: asset.id,
                    asset: asset,
                    distance: distance,
                    adaptedRecipe: adapted
                ))
            }
        }
        return matches.sorted { $0.distance < $1.distance }
    }

    // MARK: - Recipe Adaptation

    /// Adapt `recipe` from `source` to `target`, compensating for exposure differences.
    ///
    /// **Exposure** is shifted by the EV delta computed from EXIF (clamped ±2 stops).
    /// All other parameters reflect the photographer's creative intent and are unchanged.
    ///
    /// If EXIF is missing or unparseable, the recipe is returned unmodified.
    func adaptRecipe(
        _ recipe: EditRecipe,
        from source: PhotoAsset,
        to target: PhotoAsset
    ) -> EditRecipe {
        var result = recipe
        if let srcEV = computeEV(from: source.metadata),
           let tgtEV = computeEV(from: target.metadata) {
            let delta       = tgtEV - srcEV
            let clamped     = max(-2.0, min(2.0, delta))
            let newExposure = recipe.exposure + clamped
            // Keep within EditRecipe's physical range (typically −5 … +5).
            result.exposure = max(-5.0, min(5.0, newExposure))
        }
        return result
    }

    // MARK: - Private: EV Computation

    /// Compute Exposure Value from EXIF strings.
    ///
    /// Formula: EV = 2·log₂(N) − log₂(t)
    ///   where N = f-number, t = exposure time in seconds.
    ///
    /// Parses aperture strings like "f/2.8" or "2.8"
    /// and shutter strings like "1/125", "0.5", or "2".
    private func computeEV(from metadata: ImageMetadata?) -> Double? {
        guard let metadata else { return nil }
        guard let apertureStr = metadata.aperture,
              let shutterStr  = metadata.shutterSpeed else { return nil }

        // ── f-number ─────────────────────────────────────────────────────────
        let fStr = apertureStr.hasPrefix("f/") ? String(apertureStr.dropFirst(2)) : apertureStr
        guard let fNum = Double(fStr), fNum > 0 else { return nil }

        // ── Exposure time ─────────────────────────────────────────────────────
        let tSec: Double
        if shutterStr.contains("/") {
            let parts = shutterStr.split(separator: "/")
            guard parts.count == 2,
                  let num = Double(parts[0]),
                  let den = Double(parts[1]),
                  den > 0 else { return nil }
            tSec = num / den
        } else if let t = Double(shutterStr) {
            tSec = t
        } else {
            return nil
        }
        guard tSec > 0 else { return nil }

        return 2.0 * log2(fNum) - log2(tSec)
    }
}
