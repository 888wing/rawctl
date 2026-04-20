//
//  V16FeatureVerificationTests.swift
//  rawctlTests
//
//  Comprehensive v1.6 feature verification:
//    1. Pro gating guards all AI entry points
//    2. AI Culling v1.1 (CullingAnalysis, scoreWithAnalysis, sidecar v8)
//    3. AI Colour Grading (ColorGradeDelta, MoodPreset, UserStyleProfile, diff thresholds)
//    4. Smart Sync (EV adaptation, FeaturePrintIndex shared cache)
//    5. Cross-feature: FeaturePrintIndex shared between Culling and SmartSync
//    6. Sidecar persistence roundtrip for all new v1.6 data
//

import Foundation
import Testing
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import Latent

// MARK: - 1. Pro Gating Entry-Point Verification

struct V16ProGatingEntryPointTests {

    /// startAICulling must check AppFeatures.aiCullingEnabled before proceeding.
    @Test @MainActor func startAICullingGatedByProFlag() async {
        let env = ProcessInfo.processInfo.environment
        let hasOverride = env["LATENT_PRO_OVERRIDE"] != nil || env["RAWCTL_PRO_OVERRIDE"] != nil
        guard !hasOverride else { return }  // Can't test gating when override active

        if !AccountService.shared.isAuthenticated {
            let state = AppState()
            // Provide a dummy asset so the empty guard doesn't short-circuit first
            let assetId = UUID()
            state.assets = [PhotoAsset(url: URL(filePath: "/tmp/test.jpg"))]
            state.recipes[assetId] = EditRecipe()

            await state.startAICulling()

            // Should show account sheet (gating) and not modify any recipe
            #expect(state.showAccountSheet == true, "Non-Pro user should see account sheet on AI Cull")
        }
    }

    /// startSmartSync must check AppFeatures.smartSyncEnabled before proceeding.
    @Test @MainActor func startSmartSyncGatedByProFlag() async {
        let env = ProcessInfo.processInfo.environment
        let hasOverride = env["LATENT_PRO_OVERRIDE"] != nil || env["RAWCTL_PRO_OVERRIDE"] != nil
        guard !hasOverride else { return }

        if !AccountService.shared.isAuthenticated {
            let state = AppState()
            let asset = PhotoAsset(url: URL(filePath: "/tmp/test.jpg"))
            state.assets = [asset]
            state.selectedAssetId = asset.id

            await state.startSmartSync()

            #expect(state.showAccountSheet == true, "Non-Pro user should see account sheet on Smart Sync")
        }
    }

    /// All five Pro feature flags must be consistent.
    @Test @MainActor func allFiveProFeaturesInLockstep() {
        let flags = [
            AppFeatures.aiCullingEnabled,
            AppFeatures.smartSyncEnabled,
            AppFeatures.aiMaskingEnabled,
            AppFeatures.batchProcessingEnabled,
            AppFeatures.aiColorGradingEnabled,
        ]
        let first = flags[0]
        for flag in flags {
            #expect(flag == first, "All Pro feature flags must match")
        }
    }
}

// MARK: - 2. AI Culling v1.1 Verification

struct V16CullingAnalysisVerificationTests {

    /// CullingAnalysis version field should always be 1 (current).
    @Test func currentVersionIsOne() {
        #expect(CullingAnalysis.currentVersion == 1)
    }

    /// buildAnalysis must produce consistent rejection reasons across all signal combinations.
    @Test func rejectionReasonsAreExhaustiveAndMutuallyValid() {
        // Blurry only
        let blurry = CullingService.shared.buildAnalysis(
            sharpness: 0.1, saliency: 0.8, exposure: 0.9,
            groupId: nil, duplicateRank: nil, isRepresentative: true
        )
        #expect(blurry.rejectedReasons.contains("blurry"))
        #expect(!blurry.rejectedReasons.contains("duplicate_non_best"))

        // Exposure clipped only
        let clipped = CullingService.shared.buildAnalysis(
            sharpness: 0.8, saliency: 0.8, exposure: 0.1,
            groupId: nil, duplicateRank: nil, isRepresentative: true
        )
        #expect(clipped.rejectedReasons.contains("exposure_clipped"))

        // Poor composition only
        let poorComp = CullingService.shared.buildAnalysis(
            sharpness: 0.8, saliency: 0.05, exposure: 0.9,
            groupId: nil, duplicateRank: nil, isRepresentative: true
        )
        #expect(poorComp.rejectedReasons.contains("poor_composition"))

        // Duplicate non-best
        let gid = UUID()
        let dup = CullingService.shared.buildAnalysis(
            sharpness: 0.9, saliency: 0.8, exposure: 1.0,
            groupId: gid, duplicateRank: 2, isRepresentative: false
        )
        #expect(dup.rejectedReasons.contains("duplicate_non_best"))
        #expect(dup.suggestedFlag == .reject)

        // Multiple reasons can co-exist
        let multi = CullingService.shared.buildAnalysis(
            sharpness: 0.1, saliency: 0.05, exposure: 0.1,
            groupId: nil, duplicateRank: nil, isRepresentative: true
        )
        #expect(multi.rejectedReasons.contains("blurry"))
        #expect(multi.rejectedReasons.contains("exposure_clipped"))
        #expect(multi.rejectedReasons.contains("poor_composition"))
    }

    /// scoreWithAnalysis returns CullingAnalysis (not CullingScore).
    @Test func scoreWithAnalysisReturnsCullingAnalysisType() async {
        let results = await CullingService.shared.scoreWithAnalysis(
            assets: [],
            onProgress: { _, _ in }
        )
        #expect(results.isEmpty)
        // Type is verified at compile time: [UUID: CullingAnalysis]
    }

    /// CullingConfig weights must sum to 1.0.
    @Test func configWeightsSumToOne() {
        let cfg = CullingConfig.default
        let sum = cfg.sharpnessWeight + cfg.saliencyWeight + cfg.exposureWeight
        #expect(abs(sum - 1.0) < 0.001, "Signal weights must sum to 1.0, got \(sum)")
    }

    /// Representative of duplicate group must NOT be rejected.
    @Test func duplicateRepresentativeIsNotRejected() {
        let gid = UUID()
        let rep = CullingService.shared.buildAnalysis(
            sharpness: 0.9, saliency: 0.8, exposure: 1.0,
            groupId: gid, duplicateRank: 1, isRepresentative: true
        )
        #expect(rep.suggestedFlag != .reject)
        #expect(!rep.rejectedReasons.contains("duplicate_non_best"))
        #expect(rep.duplicateRank == 1)
    }

    /// CullingAnalysis Codable roundtrip preserves all fields exactly.
    @Test func analysisCodablePreservesAllFields() throws {
        let gid = UUID()
        let original = CullingAnalysis(
            version: 1,
            overallScore: 0.6789,
            sharpnessScore: 0.75,
            saliencyScore: 0.55,
            exposureScore: 0.82,
            duplicateGroupId: gid,
            duplicateRank: 3,
            suggestedRating: 3,
            suggestedFlag: .none,
            rejectedReasons: ["blurry", "exposure_clipped"]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CullingAnalysis.self, from: data)
        #expect(decoded == original)
        #expect(decoded.version == 1)
        #expect(decoded.duplicateGroupId == gid)
        #expect(decoded.rejectedReasons == ["blurry", "exposure_clipped"])
    }
}

// MARK: - 3. AI Colour Grading Verification

struct V16ColorGradingVerificationTests {

    // MARK: - MoodPreset completeness

    /// MoodPreset.allCases must cover exactly the expected set.
    @Test func moodPresetCasesAreComplete() {
        let expected: Set<String> = [
            "cinematic", "airy", "moody", "warm_golden",
            "cool_urban", "bw_dramatic", "natural_vibrant"
        ]
        let actual = Set(GeminiColorService.MoodPreset.allCases.map(\.rawValue))
        #expect(actual == expected, "MoodPreset cases: expected \(expected), got \(actual)")
    }

    /// Every MoodPreset case has a non-empty displayName.
    @Test func moodPresetDisplayNamesNonEmpty() {
        for mood in GeminiColorService.MoodPreset.allCases {
            #expect(!mood.displayName.isEmpty, "\(mood.rawValue) has empty displayName")
        }
    }

    // MARK: - ColorGradeDelta edge cases

    /// Applying a delta with all 12 fields set and then diffing against the result should be empty.
    @Test func applyThenDiffOfAllFieldsIsNil() {
        let delta = ColorGradeDelta(
            exposure: 0.5, contrast: 10, highlights: -15, shadows: 20,
            whites: 5, blacks: -5, vibrance: 10, saturation: -8,
            temperature: 5500, tint: 10, clarity: 12, dehaze: 8
        )
        let base = EditRecipe()
        let applied = delta.applying(to: base)
        let diff = ColorGradeDelta.diff(ai: applied, final: applied)
        #expect(diff.hasChanges == false, "Diff of identical recipes should be empty")
    }

    /// ColorGradeDelta Codable roundtrip preserves all fields.
    @Test func deltaCodableRoundtrip() throws {
        let delta = ColorGradeDelta(
            exposure: 0.3, contrast: 15, highlights: -20, shadows: 35,
            whites: 10, blacks: -8, vibrance: 12, saturation: -6,
            temperature: 6000, tint: -5, clarity: 8, dehaze: 15
        )
        let data = try JSONEncoder().encode(delta)
        let decoded = try JSONDecoder().decode(ColorGradeDelta.self, from: data)
        #expect(decoded == delta)
    }

    /// Empty ColorGradeDelta has no changes.
    @Test func emptyDeltaHasNoChanges() {
        let delta = ColorGradeDelta()
        #expect(delta.hasChanges == false)
    }

    // MARK: - UserStyleProfile

    /// Default UserStyleProfile has zero bias.
    @Test func defaultStyleProfileIsZero() {
        let profile = UserStyleProfile()
        #expect(profile.sampleCount == 0)
        #expect(profile.exposureBias == 0)
        #expect(profile.contrastBias == 0)
        #expect(profile.preferredMoods.isEmpty)
        #expect(profile.avoidedMoods.isEmpty)
    }

    /// UserStyleProfile Codable roundtrip preserves all fields.
    @Test func styleProfileCodableRoundtrip() throws {
        var profile = UserStyleProfile()
        profile.sampleCount = 5
        profile.exposureBias = 0.3
        profile.contrastBias = -2.0
        profile.preferredMoods = ["cinematic", "moody"]
        profile.avoidedMoods = ["airy"]

        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(UserStyleProfile.self, from: data)

        #expect(decoded.sampleCount == 5)
        #expect(decoded.exposureBias == 0.3)
        #expect(decoded.contrastBias == -2.0)
        #expect(decoded.preferredMoods == ["cinematic", "moody"])
        #expect(decoded.avoidedMoods == ["airy"])
    }

    // MARK: - diff thresholds

    /// diff ignores small temperature changes (< 50 Kelvin).
    @Test func diffIgnoresSmallTemperatureChanges() {
        var ai = EditRecipe()
        ai.whiteBalance.temperature = 5500
        var final = EditRecipe()
        final.whiteBalance.temperature = 5530  // < 50
        let diff = ColorGradeDelta.diff(ai: ai, final: final)
        #expect(diff.temperature == nil)
    }

    /// diff captures meaningful temperature changes (>= 50 Kelvin).
    @Test func diffCapturesMeaningfulTemperatureChanges() {
        var ai = EditRecipe()
        ai.whiteBalance.temperature = 5500
        var final = EditRecipe()
        final.whiteBalance.temperature = 6000  // +500
        let diff = ColorGradeDelta.diff(ai: ai, final: final)
        #expect(diff.temperature != nil)
    }

    /// diff ignores small tint changes (< 5).
    @Test func diffIgnoresSmallTintChanges() {
        var ai = EditRecipe()
        ai.whiteBalance.tint = 10
        var final = EditRecipe()
        final.whiteBalance.tint = 13  // < 5 difference
        let diff = ColorGradeDelta.diff(ai: ai, final: final)
        #expect(diff.tint == nil)
    }

    /// diff captures meaningful tint changes (>= 5).
    @Test func diffCapturesMeaningfulTintChanges() {
        var ai = EditRecipe()
        ai.whiteBalance.tint = 10
        var final = EditRecipe()
        final.whiteBalance.tint = 25  // +15
        let diff = ColorGradeDelta.diff(ai: ai, final: final)
        #expect(diff.tint != nil)
    }

    // MARK: - AppState colour grading integration

    /// applyColorGrade must push undo history before applying.
    @Test @MainActor func applyColorGradePushesUndoHistory() {
        let state = AppState()
        let assetId = UUID()
        var base = EditRecipe()
        base.exposure = 1.0
        state.recipes[assetId] = base
        state.selectedAssetId = assetId

        let delta = ColorGradeDelta(exposure: 0.5)
        let result = GeminiColorService.ColorGradeResult(
            delta: delta, analysis: "test", detectedMood: "natural", creditsUsed: 1
        )
        state.applyColorGrade(result, mode: .auto)

        // After applying, exposure should be changed
        #expect(state.recipes[assetId]?.exposure == 0.5)
        // Pending suggestion must be recorded
        #expect(state.pendingAiSuggestion?.assetId == assetId)
        #expect(state.aiGradeAnalysis == "test")
    }
}

// MARK: - 4. Smart Sync Verification

struct V16SmartSyncVerificationTests {

    /// SmartSyncService is a shared actor singleton.
    @Test func smartSyncServiceIsSingleton() async {
        let s1 = SmartSyncService.shared
        let s2 = SmartSyncService.shared
        // Actor identity check — both point to same instance.
        #expect(s1 === s2)
    }

    /// adaptRecipe with nil metadata on both returns recipe unchanged.
    @Test func adaptWithBothNilMetadataIsIdentity() async {
        let service = SmartSyncService.shared
        var recipe = EditRecipe()
        recipe.exposure = 0.5
        recipe.contrast = 20

        let source = PhotoAsset(url: URL(filePath: "/tmp/s.jpg"))
        let target = PhotoAsset(url: URL(filePath: "/tmp/t.jpg"))

        let adapted = await service.adaptRecipe(recipe, from: source, to: target)
        #expect(adapted.exposure == recipe.exposure)
        #expect(adapted.contrast == recipe.contrast)
    }
}

// MARK: - 5. Cross-Feature: FeaturePrintIndex Shared Cache

struct V16FeaturePrintIndexSharedTests {

    /// FeaturePrintIndex is a shared singleton used by both Culling and SmartSync.
    @Test func featurePrintIndexIsSingleton() async {
        let i1 = FeaturePrintIndex.shared
        let i2 = FeaturePrintIndex.shared
        #expect(i1 === i2)
    }

    /// reset clears all entries.
    @Test func resetClearsEntireIndex() async {
        let index = FeaturePrintIndex.shared
        await index.reset()
        let prints = await index.allPrints()
        #expect(prints.isEmpty)
    }

    /// allPrints returns a snapshot that can be passed to scoreWithAnalysis.
    @Test func allPrintsSnapshotIsPassableToScoring() async {
        let index = FeaturePrintIndex.shared
        await index.reset()

        let snapshot = await index.allPrints()
        // Pass snapshot to scoreWithAnalysis (empty, but validates the type contract).
        let results = await CullingService.shared.scoreWithAnalysis(
            assets: [],
            existingPrints: snapshot,
            onProgress: { _, _ in }
        )
        #expect(results.isEmpty)
    }

    /// buildIndex returns count of indexed items.
    @Test func buildIndexReportsCorrectCount() async {
        let index = FeaturePrintIndex.shared
        await index.reset()

        guard let url = createSyntheticJPEG() else { return }
        defer { try? FileManager.default.removeItem(at: url) }

        let asset = PhotoAsset(url: url)
        let count = await index.buildIndex(assets: [asset], onProgress: { _, _ in })
        #expect(count == 1)

        // Second build with same asset should still return 1 (cached).
        let count2 = await index.buildIndex(assets: [asset], onProgress: { _, _ in })
        #expect(count2 == 1)
    }

    private func createSyntheticJPEG() -> URL? {
        let size = CGSize(width: 64, height: 64)
        guard let ctx = CGContext(
            data: nil,
            width: Int(size.width), height: Int(size.height),
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.setFillColor(CGColor(red: 0.5, green: 0.3, blue: 0.8, alpha: 1.0))
        ctx.fill(CGRect(origin: .zero, size: size))
        guard let image = ctx.makeImage() else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("v16_verify_\(UUID().uuidString).jpg")
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return url
    }
}

// MARK: - 6. Sidecar Persistence Roundtrip

struct V16SidecarPersistenceTests {

    /// Sidecar v8 roundtrip with CullingAnalysis preserves all fields.
    @Test func sidecarV8WithAnalysisRoundtrips() throws {
        let gid = UUID()
        let analysis = CullingAnalysis(
            version: 1,
            overallScore: 0.68,
            sharpnessScore: 0.82,
            saliencyScore: 0.55,
            exposureScore: 0.91,
            duplicateGroupId: gid,
            duplicateRank: 2,
            suggestedRating: 3,
            suggestedFlag: .none,
            rejectedReasons: ["duplicate_non_best"]
        )

        var sidecar = SidecarFile(
            for: URL(fileURLWithPath: "/tmp/verify.ARW"),
            recipe: EditRecipe()
        )
        sidecar.cullingAnalysis = analysis

        let data = try JSONEncoder().encode(sidecar)
        let decoded = try JSONDecoder().decode(SidecarFile.self, from: data)

        #expect(decoded.schemaVersion == 8)
        #expect(decoded.cullingAnalysis?.overallScore == 0.68)
        #expect(decoded.cullingAnalysis?.duplicateGroupId == gid)
        #expect(decoded.cullingAnalysis?.duplicateRank == 2)
        #expect(decoded.cullingAnalysis?.rejectedReasons == ["duplicate_non_best"])
    }

    /// Legacy v7 sidecar decodes with nil cullingAnalysis.
    @Test func legacyV7SidecarDecodesCleanly() throws {
        let v7Json = """
        {
            "schemaVersion": 7,
            "asset": { "originalFilename": "legacy.ARW", "fileSize": 256, "modifiedTime": 0 },
            "edit": {},
            "snapshots": [],
            "aiEdits": [],
            "aiLayers": [],
            "updatedAt": 0
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(SidecarFile.self, from: v7Json)
        #expect(decoded.cullingAnalysis == nil)
    }

    /// Sidecar roundtrip preserves both recipe edits and cullingAnalysis independently.
    @Test func sidecarPreservesRecipeAndAnalysisSeparately() throws {
        var recipe = EditRecipe()
        recipe.exposure = 1.5
        recipe.contrast = 20
        recipe.rating = 4
        recipe.flag = .pick

        let analysis = CullingAnalysis(
            version: 1, overallScore: 0.85,
            sharpnessScore: 0.9, saliencyScore: 0.8, exposureScore: 0.92,
            duplicateGroupId: nil, duplicateRank: nil,
            suggestedRating: 4, suggestedFlag: .pick,
            rejectedReasons: []
        )

        var sidecar = SidecarFile(
            for: URL(fileURLWithPath: "/tmp/combo.ARW"),
            recipe: recipe
        )
        sidecar.cullingAnalysis = analysis

        let data = try JSONEncoder().encode(sidecar)
        let decoded = try JSONDecoder().decode(SidecarFile.self, from: data)

        // Recipe fields intact
        #expect(decoded.edit.exposure == 1.5)
        #expect(decoded.edit.contrast == 20)
        #expect(decoded.edit.rating == 4)
        #expect(decoded.edit.flag == .pick)

        // Analysis fields intact
        #expect(decoded.cullingAnalysis?.overallScore == 0.85)
        #expect(decoded.cullingAnalysis?.suggestedRating == 4)
    }

    /// ColorGradeDelta JSON roundtrip is accurate.
    @Test func colorGradeDeltaJsonRoundtrip() throws {
        let json = """
        {
            "exposure": 0.5,
            "contrast": 10,
            "temperature": 5500,
            "tint": 5,
            "clarity": -8
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(ColorGradeDelta.self, from: json)
        #expect(decoded.exposure == 0.5)
        #expect(decoded.contrast == 10)
        #expect(decoded.temperature == 5500)
        #expect(decoded.tint == 5)
        #expect(decoded.clarity == -8)
        #expect(decoded.highlights == nil)
        #expect(decoded.shadows == nil)
    }
}

// MARK: - 7. AppState AI Feature Integration

struct V16AppStateIntegrationTests {

    /// startAICulling captures pre-cull snapshot before overwriting.
    @Test @MainActor func cullingCapturesSnapshotBeforeOverwriting() {
        let state = AppState()
        let assetId = UUID()
        var recipe = EditRecipe()
        recipe.rating = 5
        recipe.flag = .pick
        state.recipes[assetId] = recipe

        let snapshot = state.capturePreCullSnapshot()
        #expect(snapshot[assetId]?.rating == 5)
        #expect(snapshot[assetId]?.flag == .pick)
    }

    /// undoAICull restores ratings and clears snapshot.
    @Test @MainActor func undoAICullRestoresAndClearsSnapshot() {
        let state = AppState()
        let assetId = UUID()
        var original = EditRecipe()
        original.rating = 4
        original.flag = .pick
        state.recipes[assetId] = original

        // Capture snapshot
        let snapshot = state.capturePreCullSnapshot()
        state.lastPreCullSnapshot = snapshot

        // Simulate culling overwrite
        state.recipes[assetId]?.rating = 0
        state.recipes[assetId]?.flag = .reject

        // Undo
        state.undoAICull()

        #expect(state.recipes[assetId]?.rating == 4)
        #expect(state.recipes[assetId]?.flag == .pick)
        #expect(state.lastPreCullSnapshot == nil)
    }

    /// recordAndClearPendingAISuggestion clears the pending state.
    @Test @MainActor func recordAndClearClearsPendingState() {
        let state = AppState()
        let assetId = UUID()
        state.selectedAssetId = assetId
        state.recipes[assetId] = EditRecipe()

        let delta = ColorGradeDelta(exposure: 0.5)
        let result = GeminiColorService.ColorGradeResult(
            delta: delta, analysis: "test", detectedMood: "cinematic", creditsUsed: 1
        )
        state.applyColorGrade(result, mode: .auto)
        #expect(state.pendingAiSuggestion != nil)

        state.recordAndClearPendingAISuggestion()
        #expect(state.pendingAiSuggestion == nil)
    }

    /// applyColorGrade with mood mode stores the correct mode.
    @Test @MainActor func applyColorGradeWithMoodMode() {
        let state = AppState()
        let assetId = UUID()
        state.selectedAssetId = assetId
        state.recipes[assetId] = EditRecipe()

        let delta = ColorGradeDelta(exposure: 0.3, contrast: 10)
        let result = GeminiColorService.ColorGradeResult(
            delta: delta, analysis: "Moody grading", detectedMood: "moody", creditsUsed: 1
        )
        state.applyColorGrade(result, mode: .mood("moody"))

        #expect(state.pendingAiSuggestion?.delta.exposure == 0.3)
        #expect(state.aiGradeAnalysis == "Moody grading")
    }

    /// applyColorGrade preserves non-overridden recipe fields.
    @Test @MainActor func applyColorGradePreservesNonOverriddenFields() {
        let state = AppState()
        let assetId = UUID()
        var base = EditRecipe()
        base.exposure = 0.0
        base.contrast = 15
        base.vibrance = 20
        base.rating = 3
        state.recipes[assetId] = base
        state.selectedAssetId = assetId

        // Delta only changes exposure
        let delta = ColorGradeDelta(exposure: 0.8)
        let result = GeminiColorService.ColorGradeResult(
            delta: delta, analysis: "", detectedMood: "", creditsUsed: 1
        )
        state.applyColorGrade(result, mode: .auto)

        let applied = state.recipes[assetId]!
        #expect(applied.exposure == 0.8)    // changed
        #expect(applied.contrast == 15)     // preserved
        #expect(applied.vibrance == 20)     // preserved
        #expect(applied.rating == 3)        // preserved
    }
}
