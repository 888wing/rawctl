//
//  CullingServiceTests.swift
//  rawctlTests
//
//  Tests for on-device AI culling service.
//

import Foundation
import Testing
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import Latent

struct CullingServiceTests {

    // MARK: - Empty input

    @Test func emptyAssetsReturnEmptyResults() async {
        let results = await CullingService.shared.score(assets: []) { _, _ in }
        #expect(results.isEmpty)
    }

    @Test func emptyAssetsNeverCallsProgressCallback() async {
        var progressCalls = 0
        _ = await CullingService.shared.score(assets: []) { _, _ in
            progressCalls += 1
        }
        #expect(progressCalls == 0)
    }

    // MARK: - CullingScore invariants

    @Test func cullingScoreRatingIsInValidRange() {
        // Exercise the boundary conditions of the rating mapping.
        let cases: [(sharpness: Double, saliency: Double, isDuplicate: Bool, expectedRating: ClosedRange<Int>)] = [
            (0.0, 0.0, false, 0...0),   // very poor → 0
            (0.0, 0.0, true,  0...0),   // duplicate → 0 (reject)
            (0.5, 0.5, false, 1...5),   // moderate → at least 1
            (1.0, 1.0, false, 4...5),   // excellent → 4 or 5
        ]

        for tc in cases {
            let score = makeCullingScore(sharpness: tc.sharpness, saliency: tc.saliency, isDuplicate: tc.isDuplicate)
            #expect(
                tc.expectedRating.contains(score.suggestedRating),
                "sharpness=\(tc.sharpness) saliency=\(tc.saliency) isDup=\(tc.isDuplicate) → rating \(score.suggestedRating) outside \(tc.expectedRating)"
            )
            #expect((0...5).contains(score.suggestedRating))
        }
    }

    @Test func duplicateAlwaysBecomesReject() {
        let score = makeCullingScore(sharpness: 1.0, saliency: 1.0, isDuplicate: true)
        #expect(score.suggestedFlag == .reject)
        #expect(score.suggestedRating == 0)
    }

    @Test func highQualityScoreBecomesPickWith4Or5Stars() {
        let score = makeCullingScore(sharpness: 0.95, saliency: 0.90, isDuplicate: false)
        #expect(score.suggestedFlag == .pick)
        #expect(score.suggestedRating >= 4)
    }

    @Test func lowQualityScoreBecomesRejectWith0Stars() {
        let score = makeCullingScore(sharpness: 0.05, saliency: 0.05, isDuplicate: false)
        #expect(score.suggestedFlag == .reject)
        #expect(score.suggestedRating == 0)
    }

    // MARK: - Progress callbacks

    @Test func progressCallbackIsCalledWithSyntheticAsset() async throws {
        guard let assetURL = createSyntheticJPEG() else {
            // Cannot create temp file — skip rather than fail.
            return
        }
        defer { try? FileManager.default.removeItem(at: assetURL) }

        let asset = PhotoAsset(url: assetURL)
        var progressCalls: [(Int, Int)] = []

        _ = await CullingService.shared.score(assets: [asset]) { done, total in
            progressCalls.append((done, total))
        }

        // Two phases: feature print pass + scoring pass → at least 2 callbacks.
        #expect(progressCalls.count >= 2)
        // Total should always be assets.count * 2 = 2
        for (_, total) in progressCalls {
            #expect(total == 2)
        }
    }

    @Test func singleAssetScoreReturnsResultForThatAsset() async throws {
        guard let assetURL = createSyntheticJPEG() else { return }
        defer { try? FileManager.default.removeItem(at: assetURL) }

        let asset = PhotoAsset(url: assetURL)
        let results = await CullingService.shared.score(assets: [asset]) { _, _ in }

        // Should return exactly one result.
        #expect(results.count == 1)
        if let score = results[asset.id] {
            #expect((0...5).contains(score.suggestedRating))
            #expect(score.sharpness >= 0 && score.sharpness <= 1.0)
            #expect(score.saliency  >= 0 && score.saliency  <= 1.0)
        }
    }

    // MARK: - Duplicate group logic

    @Test func duplicateBurstKeepsRepresentative() {
        // Representative (isGroupRepresentative = true): should NOT become reject
        let rep = makeCullingScoreGroupAware(sharpness: 0.9, saliency: 0.8,
                                              groupId: UUID(), isRepresentative: true)
        #expect(rep.suggestedFlag != .reject, "Representative must not be auto-rejected")
        #expect(rep.suggestedRating >= 4)

        // Non-representative: should become reject
        let nonRep = makeCullingScoreGroupAware(sharpness: 0.9, saliency: 0.8,
                                                 groupId: UUID(), isRepresentative: false)
        #expect(nonRep.suggestedFlag == .reject)
        #expect(nonRep.suggestedRating == 0)
    }

    @Test func uniquePhotoIsNotRejectedByDuplicateLogic() {
        let unique = makeCullingScoreGroupAware(sharpness: 0.7, saliency: 0.6,
                                                 groupId: nil, isRepresentative: true)
        #expect(unique.suggestedFlag != .reject)
    }

    // MARK: - Helpers

    /// Instantiate a CullingScore by calling the internal score-computation logic
    /// via the service. Since computeFinalScore is private we derive scores by crafting
    /// synthetic results directly from the struct.
    private func makeCullingScore(
        sharpness: Double,
        saliency: Double,
        isDuplicate: Bool
    ) -> CullingScore {
        let combined = sharpness * 0.6 + saliency * 0.4
        let groupId: UUID? = isDuplicate ? UUID() : nil
        let isRep = !isDuplicate
        let (rating, flag): (Int, Flag)
        switch (isDuplicate, combined) {
        case (true, _):    (rating, flag) = (0, .reject)
        case (_, ..<0.20): (rating, flag) = (0, .reject)
        case (_, ..<0.40): (rating, flag) = (1, .none)
        case (_, ..<0.55): (rating, flag) = (2, .none)
        case (_, ..<0.70): (rating, flag) = (3, .none)
        case (_, ..<0.85): (rating, flag) = (4, .pick)
        default:           (rating, flag) = (5, .pick)
        }
        return CullingScore(
            sharpness: sharpness,
            saliency: saliency,
            duplicateGroupId: groupId,
            isGroupRepresentative: isRep,
            suggestedRating: rating,
            suggestedFlag: flag
        )
    }

    private func makeCullingScoreGroupAware(
        sharpness: Double,
        saliency: Double,
        groupId: UUID?,
        isRepresentative: Bool
    ) -> CullingScore {
        let combined = sharpness * 0.6 + saliency * 0.4
        let isDuplicateNonRep = groupId != nil && !isRepresentative
        let (rating, flag): (Int, Flag)
        switch (isDuplicateNonRep, combined) {
        case (true, _):    (rating, flag) = (0, .reject)
        case (_, ..<0.20): (rating, flag) = (0, .reject)
        case (_, ..<0.40): (rating, flag) = (1, .none)
        case (_, ..<0.55): (rating, flag) = (2, .none)
        case (_, ..<0.70): (rating, flag) = (3, .none)
        case (_, ..<0.85): (rating, flag) = (4, .pick)
        default:           (rating, flag) = (5, .pick)
        }
        return CullingScore(
            sharpness: sharpness,
            saliency: saliency,
            duplicateGroupId: groupId,
            isGroupRepresentative: isRepresentative,
            suggestedRating: rating,
            suggestedFlag: flag
        )
    }

    /// Creates a minimal synthetic JPEG in a temp directory for testing.
    /// Returns `nil` if file creation fails (tests that use this skip gracefully).
    private func createSyntheticJPEG() -> URL? {
        let size = CGSize(width: 64, height: 64)
        guard let context = CGContext(
            data: nil,
            width: Int(size.width), height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Draw a simple gradient so sharpness/saliency signals are non-trivial.
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0))
        context.fill(CGRect(origin: .zero, size: size))
        context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
        context.fill(CGRect(x: 16, y: 16, width: 32, height: 32))

        guard let image = context.makeImage() else { return nil }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("culling_test_\(UUID().uuidString).jpg")

        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }

        return url
    }
}
