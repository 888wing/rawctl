//
//  CameraProfileTests.swift
//  rawctlTests
//
//  Tests for CameraProfile and related color pipeline models
//

import Foundation
import Testing
@testable import rawctl

struct CameraProfileTests {

    // MARK: - HighlightShoulder Tests

    @Test func highlightShoulderPresets() async throws {
        let neutral = HighlightShoulder.neutral
        #expect(neutral.knee == 0.85)
        #expect(neutral.hasEffect == true)

        let none = HighlightShoulder.none
        #expect(none.hasEffect == false)
    }

    // MARK: - ColorMatrix Tests

    @Test func colorMatrixIdentity() async throws {
        let matrix = ColorMatrix3x3.identity
        let result = matrix.apply(r: 0.5, g: 0.3, b: 0.2)

        #expect(abs(result.r - 0.5) < 0.001)
        #expect(abs(result.g - 0.3) < 0.001)
        #expect(abs(result.b - 0.2) < 0.001)
    }

    // MARK: - FilmicToneCurve Tests

    @Test func filmicToneCurveHasCorrectPoints() async throws {
        let neutral = FilmicToneCurve.filmicNeutral
        #expect(neutral.points.count == 6)
        #expect(neutral.hasEdits == true)

        let linear = FilmicToneCurve.linear
        #expect(linear.hasEdits == false)
    }

    // MARK: - CameraProfile Tests

    @Test func builtInProfilesExist() async throws {
        let profiles = BuiltInProfile.allProfiles
        #expect(profiles.count == BuiltInProfile.allCases.count)
        #expect(profiles.count >= 8)
    }

    @Test func neutralProfileIsDefault() async throws {
        let neutral = BuiltInProfile.neutral.profile
        #expect(neutral.name == "rawctl Neutral")
        #expect(neutral.colorMatrix == .identity)
    }

    @Test func profileLookupWorks() async throws {
        let vivid = BuiltInProfile.profile(for: "rawctl.vivid")
        #expect(vivid != nil)
        #expect(vivid?.name == "rawctl Vivid")

        let original = BuiltInProfile.profile(for: "rawctl.original")
        #expect(original != nil)
        #expect(original?.name == "Original")

        let invalid = BuiltInProfile.profile(for: "invalid.profile")
        #expect(invalid == nil)
    }

    // MARK: - EditRecipe Profile Integration

    @Test func editRecipeDefaultsToNeutralProfile() async throws {
        let recipe = EditRecipe()
        #expect(recipe.profileId == BuiltInProfile.neutral.rawValue)
    }

    @Test func editRecipeHasEditsWhenProfileChanged() async throws {
        var recipe = EditRecipe()
        #expect(recipe.hasEdits == false)

        recipe.profileId = BuiltInProfile.vivid.rawValue
        #expect(recipe.hasEdits == true)
    }
}
