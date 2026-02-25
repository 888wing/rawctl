//
//  GeminiColorServiceTests.swift
//  rawctlTests
//
//  Tests for the AI Colour Grading feature (v1.6):
//    - ColorGradeDelta.applying(to:) merge correctness
//    - ColorGradeDelta.diff(ai:final:) preference delta
//    - ColorGradeDelta.hasChanges sentinel
//    - APIResponse<ColorGradeResponse> JSON decoding (wrapper + field mapping)
//    - AppState.applyColorGrade sets pendingAiSuggestion
//

import Foundation
import Testing
@testable import Latent

struct GeminiColorServiceTests {

    // MARK: - ColorGradeDelta.applying(to:)

    @Test func applyingAllFieldsMergesCorrectly() {
        var base = EditRecipe()
        base.exposure    = 0
        base.contrast    = 0
        base.highlights  = 0
        base.shadows     = 0
        base.whites      = 0
        base.blacks      = 0
        base.vibrance    = 0
        base.saturation  = 0
        base.clarity     = 0
        base.dehaze      = 0

        let delta = ColorGradeDelta(
            exposure:    0.8,
            contrast:    15,
            highlights: -20,
            shadows:     40,
            whites:       5,
            blacks:      -5,
            vibrance:   -10,
            saturation: -15,
            temperature: 5000,
            tint:         5,
            clarity:     -8,
            dehaze:      10
        )

        let result = delta.applying(to: base)

        #expect(result.exposure    == 0.8)
        #expect(result.contrast    == 15)
        #expect(result.highlights  == -20)
        #expect(result.shadows     == 40)
        #expect(result.whites      == 5)
        #expect(result.blacks      == -5)
        #expect(result.vibrance    == -10)
        #expect(result.saturation  == -15)
        #expect(result.whiteBalance.temperature == 5000)
        #expect(result.whiteBalance.tint        == 5)
        #expect(result.clarity     == -8)
        #expect(result.dehaze      == 10)
    }

    @Test func applyingNilFieldsPreservesBase() {
        var base = EditRecipe()
        base.exposure   = 1.5
        base.contrast   = 20
        base.saturation = -30
        base.whiteBalance.temperature = 6500

        // Empty delta — nothing should change
        let delta = ColorGradeDelta()
        let result = delta.applying(to: base)

        #expect(result.exposure   == 1.5)
        #expect(result.contrast   == 20)
        #expect(result.saturation == -30)
        #expect(result.whiteBalance.temperature == 6500)
    }

    @Test func applyingTemperatureClampedTo2000_12000() {
        let base = EditRecipe()

        let deltaLow = ColorGradeDelta(temperature: 100)   // below min
        let resultLow = deltaLow.applying(to: base)
        #expect(resultLow.whiteBalance.temperature == 2000)

        let deltaHigh = ColorGradeDelta(temperature: 99999) // above max
        let resultHigh = deltaHigh.applying(to: base)
        #expect(resultHigh.whiteBalance.temperature == 12000)
    }

    @Test func applyingTintClampedTo_150_150() {
        let base = EditRecipe()

        let deltaLow  = ColorGradeDelta(tint: -999)
        let deltaHigh = ColorGradeDelta(tint:  999)

        #expect(deltaLow.applying(to: base).whiteBalance.tint  == -150)
        #expect(deltaHigh.applying(to: base).whiteBalance.tint ==  150)
    }

    @Test func applyingPartialDeltaOnlyOverwritesSpecifiedFields() {
        var base = EditRecipe()
        base.exposure  = 1.0
        base.contrast  = 10
        base.saturation = -20

        // Only change exposure
        let delta = ColorGradeDelta(exposure: 0.3)
        let result = delta.applying(to: base)

        #expect(result.exposure   == 0.3)   // changed
        #expect(result.contrast   == 10)    // preserved
        #expect(result.saturation == -20)   // preserved
    }

    // MARK: - ColorGradeDelta.hasChanges

    @Test func hasChangesIsFalseForEmptyDelta() {
        let delta = ColorGradeDelta()
        #expect(delta.hasChanges == false)
    }

    @Test func hasChangesIsTrueWhenAnyFieldSet() {
        let fields: [ColorGradeDelta] = [
            ColorGradeDelta(exposure: 0.1),
            ColorGradeDelta(contrast: 5),
            ColorGradeDelta(highlights: -10),
            ColorGradeDelta(shadows: 20),
            ColorGradeDelta(whites: 5),
            ColorGradeDelta(blacks: -5),
            ColorGradeDelta(vibrance: 10),
            ColorGradeDelta(saturation: -8),
            ColorGradeDelta(temperature: 5500),
            ColorGradeDelta(tint: 3),
            ColorGradeDelta(clarity: 15),
            ColorGradeDelta(dehaze: 20),
        ]
        for delta in fields {
            #expect(delta.hasChanges == true)
        }
    }

    // MARK: - ColorGradeDelta.diff(ai:final:)

    @Test func diffReturnsNilForNegligibleChanges() {
        // Small tweak to exposure (< 0.01 threshold)
        var aiRecipe = EditRecipe()
        aiRecipe.exposure = 0.5

        var finalRecipe = EditRecipe()
        finalRecipe.exposure = 0.505   // 0.005 difference — below threshold

        let diff = ColorGradeDelta.diff(ai: aiRecipe, final: finalRecipe)
        #expect(diff.exposure == nil)
    }

    @Test func diffCapturesMeaningfulExposureChange() {
        var aiRecipe = EditRecipe()
        aiRecipe.exposure = 0.5

        var finalRecipe = EditRecipe()
        finalRecipe.exposure = 1.2   // +0.7 — above 0.01 threshold

        let diff = ColorGradeDelta.diff(ai: aiRecipe, final: finalRecipe)
        #expect(diff.exposure != nil)
        #expect(abs((diff.exposure ?? 0) - 0.7) < 0.001)
    }

    @Test func diffIgnoresSmallContrastChanges() {
        var aiRecipe = EditRecipe(); aiRecipe.contrast = 20
        var finalRecipe = EditRecipe(); finalRecipe.contrast = 20.3   // < 0.5 threshold
        let diff = ColorGradeDelta.diff(ai: aiRecipe, final: finalRecipe)
        #expect(diff.contrast == nil)
    }

    @Test func diffCapturesMeaningfulContrastChange() {
        var aiRecipe = EditRecipe(); aiRecipe.contrast = 10
        var finalRecipe = EditRecipe(); finalRecipe.contrast = 25   // +15 — above threshold
        let diff = ColorGradeDelta.diff(ai: aiRecipe, final: finalRecipe)
        #expect(diff.contrast != nil)
    }

    // MARK: - JSON Response Decoding

    @Test func colorGradeResponseDecodesFromAPIResponseEnvelope() throws {
        let json = """
        {
          "success": true,
          "data": {
            "recipe": {
              "exposure": 0.5,
              "contrast": 10,
              "highlights": -15,
              "shadows": 20
            },
            "analysis": "Natural outdoor portrait with slight underexposure.",
            "detectedMood": "cinematic",
            "creditsUsed": 1,
            "creditsRemaining": 9
          }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(APIResponse<ColorGradeResponse>.self, from: json)

        #expect(envelope.success == true)
        let response = try #require(envelope.data)
        #expect(response.recipe.exposure  == 0.5)
        #expect(response.recipe.contrast  == 10)
        #expect(response.recipe.highlights == -15)
        #expect(response.recipe.shadows   == 20)
        #expect(response.analysis         == "Natural outdoor portrait with slight underexposure.")
        #expect(response.detectedMood     == "cinematic")
        #expect(response.creditsUsed      == 1)
        #expect(response.creditsRemaining == 9)
    }

    @Test func colorGradeResponseHandlesNullFieldsInRecipe() throws {
        let json = """
        {
          "success": true,
          "data": {
            "recipe": {
              "exposure": 0.3
            },
            "analysis": "Slight underexposure corrected.",
            "detectedMood": "natural",
            "creditsUsed": 1,
            "creditsRemaining": 8
          }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(APIResponse<ColorGradeResponse>.self, from: json)
        let response = try #require(envelope.data)

        #expect(response.recipe.exposure   == 0.3)
        #expect(response.recipe.contrast   == nil)  // not present → nil
        #expect(response.recipe.highlights == nil)
        #expect(response.recipe.shadows    == nil)
    }

    @Test func colorGradeResponseHandlesErrorEnvelope() throws {
        let json = """
        {
          "success": false,
          "error": {
            "code": "INSUFFICIENT_CREDITS",
            "message": "Not enough credits"
          }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(APIResponse<ColorGradeResponse>.self, from: json)
        #expect(envelope.success == false)
        #expect(envelope.data    == nil)
        #expect(envelope.error?.code == "INSUFFICIENT_CREDITS")
    }

    // MARK: - AppState.applyColorGrade

    @Test @MainActor func applyColorGradeSetsPendingAiSuggestion() {
        let appState = AppState()
        let assetId = UUID()
        appState.selectedAssetId = assetId
        appState.recipes[assetId] = EditRecipe()

        let delta = ColorGradeDelta(exposure: 0.5, shadows: 20)
        let result = GeminiColorService.ColorGradeResult(
            delta: delta,
            analysis: "Test analysis",
            detectedMood: "cinematic",
            creditsUsed: 1
        )

        appState.applyColorGrade(result, mode: .auto)

        #expect(appState.pendingAiSuggestion != nil)
        #expect(appState.pendingAiSuggestion?.assetId == assetId)
        #expect(appState.pendingAiSuggestion?.delta.exposure == 0.5)
        #expect(appState.aiGradeAnalysis == "Test analysis")
    }

    @Test @MainActor func applyColorGradeMergesDeltaIntoRecipe() {
        let appState = AppState()
        let assetId = UUID()

        var base = EditRecipe()
        base.exposure = 0.0
        base.contrast = 5
        appState.recipes[assetId] = base
        appState.selectedAssetId = assetId

        let delta = ColorGradeDelta(exposure: 0.8, shadows: 30)
        let result = GeminiColorService.ColorGradeResult(
            delta: delta,
            analysis: "Improved exposure",
            detectedMood: "natural",
            creditsUsed: 1
        )

        appState.applyColorGrade(result, mode: .mood("cinematic"))

        let applied = appState.recipes[assetId]!
        #expect(applied.exposure == 0.8)   // delta applied
        #expect(applied.contrast == 5)     // base preserved
        #expect(applied.shadows  == 30)    // delta applied
    }

    @Test @MainActor func recordAndClearPendingAISuggestionClearsState() {
        let appState = AppState()
        let assetId = UUID()
        appState.selectedAssetId = assetId
        appState.recipes[assetId] = EditRecipe()

        let delta = ColorGradeDelta(exposure: 0.4)
        let result = GeminiColorService.ColorGradeResult(
            delta: delta, analysis: "", detectedMood: "", creditsUsed: 1
        )
        appState.applyColorGrade(result, mode: .auto)
        #expect(appState.pendingAiSuggestion != nil)

        appState.recordAndClearPendingAISuggestion()
        #expect(appState.pendingAiSuggestion == nil)
    }
}
