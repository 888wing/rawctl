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
            (0.0, 0.0, false, 1...1),   // zero sharpness/saliency but default exposure → 1
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
        // With 3-signal model, pass exposure=0.0 to test true low-quality boundary.
        // combined = 0.05*0.45 + 0.05*0.30 + 0.0*0.25 = 0.0375, below rejectBelow (0.20).
        let score = makeCullingScore(sharpness: 0.05, saliency: 0.05, exposure: 0.0, isDuplicate: false)
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

    // MARK: - Exposure scoring via computeFinalScore

    @Test func wellExposedPhotoGetsHighExposureContribution() {
        // exposure=1.0 (perfect) should contribute full weight to combined score
        let score = makeCullingScore(sharpness: 0.7, saliency: 0.6, exposure: 1.0, isDuplicate: false)
        // combined = 0.7*0.45 + 0.6*0.30 + 1.0*0.25 = 0.315 + 0.18 + 0.25 = 0.745
        #expect(score.suggestedRating >= 3, "Well-exposed photo with good quality should rate >= 3")
    }

    @Test func severelyUnderexposedPhotoPenalized() {
        // exposure=0.0 (worst) should drag combined score down significantly
        let score = makeCullingScore(sharpness: 0.7, saliency: 0.6, exposure: 0.0, isDuplicate: false)
        // combined = 0.7*0.45 + 0.6*0.30 + 0.0*0.25 = 0.315 + 0.18 + 0 = 0.495
        #expect(score.suggestedRating <= 2, "Severely underexposed should rate <= 2")
    }

    @Test func moderateExposureIssueReducesRatingByOne() {
        // Compare perfect exposure vs moderate issue
        let perfect  = makeCullingScore(sharpness: 0.8, saliency: 0.7, exposure: 1.0, isDuplicate: false)
        let moderate = makeCullingScore(sharpness: 0.8, saliency: 0.7, exposure: 0.5, isDuplicate: false)
        #expect(perfect.suggestedRating > moderate.suggestedRating,
                "Moderate exposure issue should reduce rating vs perfect exposure")
    }

    @Test func exposureScoreStoredInCullingScore() {
        let score = makeCullingScore(sharpness: 0.5, saliency: 0.5, exposure: 0.75, isDuplicate: false)
        #expect(score.exposureScore == 0.75, "exposureScore should be stored verbatim")
    }

    // MARK: - Helpers

    private func makeCullingScore(
        sharpness: Double,
        saliency: Double,
        exposure: Double = 1.0,
        isDuplicate: Bool
    ) -> CullingScore {
        CullingService.shared.computeFinalScore(
            sharpness: sharpness,
            saliency: saliency,
            exposure: exposure,
            groupId: isDuplicate ? UUID() : nil,
            isRepresentative: !isDuplicate
        )
    }

    private func makeCullingScoreGroupAware(
        sharpness: Double,
        saliency: Double,
        exposure: Double = 1.0,
        groupId: UUID?,
        isRepresentative: Bool
    ) -> CullingScore {
        CullingService.shared.computeFinalScore(
            sharpness: sharpness,
            saliency: saliency,
            exposure: exposure,
            groupId: groupId,
            isRepresentative: isRepresentative
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
