# Image Pipeline v1.2 Phase 1: Color Foundation

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement color pipeline foundation with camera profiles, filmic tone curves, and highlight shoulder for natural-looking RAW processing.

**Architecture:** Add a 4-stage color pipeline (RAW Decode → Camera Profile → User Adjustments → Display Transform) to replace direct linear output. Camera profiles apply color matrix + base tone curve before user edits.

**Tech Stack:** Swift, Core Image (CIFilter, CIColorCube), Swift Testing framework

---

## Task 1: Create ColorPipelineConfig

**Files:**
- Create: `rawctl/rawctl/Models/ColorPipelineConfig.swift`

**Step 1: Create the color pipeline configuration file**

Create `rawctl/rawctl/Models/ColorPipelineConfig.swift`:

```swift
//
//  ColorPipelineConfig.swift
//  rawctl
//
//  Color pipeline configuration for v1.2 image processing
//

import Foundation
import CoreGraphics

/// Configuration for the rawctl color pipeline
struct ColorPipelineConfig {
    /// Working color space (scene-referred, wide gamut)
    static let workingColorSpace = CGColorSpace(name: CGColorSpace.displayP3)!

    /// Output color space for display
    static let displayColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    /// Internal processing precision
    static let processingBitDepth: Int = 16  // 16-bit float

    /// Log encoding type for working space
    var logEncoding: LogEncoding = .linear

    /// Active camera profile ID
    var profileId: String = BuiltInProfile.neutral.rawValue
}

/// Log encoding options for highlight headroom
enum LogEncoding: String, Codable, CaseIterable {
    case linear     // No encoding (current behavior)
    case filmicLog  // Custom filmic log for highlight headroom

    var displayName: String {
        switch self {
        case .linear: return "Linear"
        case .filmicLog: return "Filmic Log"
        }
    }
}
```

**Step 2: Verify build succeeds**

Run: `cd /Users/chuisiufai/Projects/rawctl/rawctl && xcodebuild -scheme rawctl -configuration Debug build 2>&1 | tail -20`

Expected: "BUILD SUCCEEDED"

**Step 3: Commit**

```bash
git add rawctl/rawctl/Models/ColorPipelineConfig.swift
git commit -m "feat(color): add ColorPipelineConfig for v1.2 pipeline"
```

---

## Task 2: Create HighlightShoulder Model

**Files:**
- Create: `rawctl/rawctl/Models/HighlightShoulder.swift`

**Step 1: Create the highlight shoulder configuration**

Create `rawctl/rawctl/Models/HighlightShoulder.swift`:

```swift
//
//  HighlightShoulder.swift
//  rawctl
//
//  Highlight roll-off parameters to prevent clipping
//

import Foundation

/// Parameters for highlight roll-off (soft knee)
struct HighlightShoulder: Codable, Equatable {
    /// Where roll-off begins (0.0-1.0, e.g., 0.85 = 85% brightness)
    var knee: Double = 0.85

    /// How gradual the roll-off is (0.0-1.0, higher = softer)
    var softness: Double = 0.3

    /// Maximum output value (0.0-1.0, e.g., 0.98 for soft clip)
    var whitePoint: Double = 0.98

    /// Check if shoulder has any effect
    var hasEffect: Bool {
        knee < 1.0 && whitePoint < 1.0
    }

    // MARK: - Presets

    /// Neutral shoulder - subtle roll-off
    static let neutral = HighlightShoulder(knee: 0.85, softness: 0.3, whitePoint: 0.98)

    /// Vivid shoulder - earlier, punchier roll-off
    static let vivid = HighlightShoulder(knee: 0.82, softness: 0.25, whitePoint: 0.97)

    /// Soft shoulder - later, gentler roll-off (good for portraits)
    static let soft = HighlightShoulder(knee: 0.88, softness: 0.4, whitePoint: 0.99)

    /// No roll-off (hard clip)
    static let none = HighlightShoulder(knee: 1.0, softness: 0.0, whitePoint: 1.0)
}
```

**Step 2: Verify build succeeds**

Run: `cd /Users/chuisiufai/Projects/rawctl/rawctl && xcodebuild -scheme rawctl -configuration Debug build 2>&1 | tail -20`

Expected: "BUILD SUCCEEDED"

**Step 3: Commit**

```bash
git add rawctl/rawctl/Models/HighlightShoulder.swift
git commit -m "feat(color): add HighlightShoulder for highlight roll-off"
```

---

## Task 3: Create FilmicToneCurve Extensions

**Files:**
- Modify: `rawctl/rawctl/Models/EditRecipe.swift` (add filmic presets to ToneCurve)

**Step 1: Check existing ToneCurve structure**

First, find ToneCurve definition. It uses `CurvePoint` which is in EditRecipe.swift.

**Step 2: Create ToneCurve extension file**

Create `rawctl/rawctl/Models/FilmicToneCurve.swift`:

```swift
//
//  FilmicToneCurve.swift
//  rawctl
//
//  Filmic tone curve presets for camera profiles
//

import Foundation

/// Tone curve for camera profile base look
struct FilmicToneCurve: Codable, Equatable {
    /// Control points for the curve (x = input, y = output, 0-1 range)
    var points: [CurvePoint]

    /// Check if curve has edits (is not identity)
    var hasEdits: Bool {
        for point in points {
            if abs(point.x - point.y) > 0.01 {
                return true
            }
        }
        return false
    }

    /// Linear (identity) curve
    static var linear: FilmicToneCurve {
        FilmicToneCurve(points: [
            CurvePoint(x: 0.00, y: 0.00),
            CurvePoint(x: 0.25, y: 0.25),
            CurvePoint(x: 0.50, y: 0.50),
            CurvePoint(x: 0.75, y: 0.75),
            CurvePoint(x: 1.00, y: 1.00)
        ])
    }

    /// Filmic neutral - natural roll-off, no crushed blacks
    static var filmicNeutral: FilmicToneCurve {
        FilmicToneCurve(points: [
            CurvePoint(x: 0.00, y: 0.00),   // Black point
            CurvePoint(x: 0.05, y: 0.03),   // Shadow lift (subtle)
            CurvePoint(x: 0.18, y: 0.18),   // Mid-gray anchor
            CurvePoint(x: 0.50, y: 0.52),   // Slight mid lift
            CurvePoint(x: 0.85, y: 0.90),   // Shoulder start
            CurvePoint(x: 1.00, y: 0.98)    // Soft white clip
        ])
    }

    /// Filmic vivid - more contrast, saturated
    static var filmicVivid: FilmicToneCurve {
        FilmicToneCurve(points: [
            CurvePoint(x: 0.00, y: 0.00),
            CurvePoint(x: 0.05, y: 0.02),   // Slightly deeper shadows
            CurvePoint(x: 0.18, y: 0.16),   // Below mid for contrast
            CurvePoint(x: 0.50, y: 0.54),   // Push mids up
            CurvePoint(x: 0.82, y: 0.92),   // Earlier shoulder
            CurvePoint(x: 1.00, y: 0.97)
        ])
    }

    /// Filmic soft - lower contrast, skin-friendly
    static var filmicSoft: FilmicToneCurve {
        FilmicToneCurve(points: [
            CurvePoint(x: 0.00, y: 0.02),   // Lifted blacks
            CurvePoint(x: 0.05, y: 0.06),
            CurvePoint(x: 0.18, y: 0.20),   // Slightly above mid
            CurvePoint(x: 0.50, y: 0.50),
            CurvePoint(x: 0.88, y: 0.88),   // Late, gentle shoulder
            CurvePoint(x: 1.00, y: 0.99)
        ])
    }
}
```

**Step 3: Verify build succeeds**

Run: `cd /Users/chuisiufai/Projects/rawctl/rawctl && xcodebuild -scheme rawctl -configuration Debug build 2>&1 | tail -20`

Expected: "BUILD SUCCEEDED"

**Step 4: Commit**

```bash
git add rawctl/rawctl/Models/FilmicToneCurve.swift
git commit -m "feat(color): add FilmicToneCurve presets for camera profiles"
```

---

## Task 4: Create ColorMatrix3x3 Model

**Files:**
- Create: `rawctl/rawctl/Models/ColorMatrix.swift`

**Step 1: Create color matrix model**

Create `rawctl/rawctl/Models/ColorMatrix.swift`:

```swift
//
//  ColorMatrix.swift
//  rawctl
//
//  3x3 color matrix for camera profile transforms
//

import Foundation
import simd

/// 3x3 color matrix for input profile transforms
struct ColorMatrix3x3: Codable, Equatable {
    /// Matrix values in row-major order [r0c0, r0c1, r0c2, r1c0, ...]
    var values: [Double]

    init(values: [Double] = [1, 0, 0, 0, 1, 0, 0, 0, 1]) {
        precondition(values.count == 9, "ColorMatrix3x3 requires exactly 9 values")
        self.values = values
    }

    /// Identity matrix (no transform)
    static let identity = ColorMatrix3x3(values: [1, 0, 0, 0, 1, 0, 0, 0, 1])

    /// Skin tone optimized matrix (slightly warmer, more pleasing skin)
    static let skinToneOptimized = ColorMatrix3x3(values: [
        1.05, -0.02, -0.03,  // Red channel: slight boost
        -0.01, 1.02, -0.01,  // Green channel: slight boost
        -0.02, -0.03, 1.05   // Blue channel: slight boost
    ])

    /// Convert to simd_float3x3 for GPU processing
    var simdMatrix: simd_float3x3 {
        simd_float3x3(
            simd_float3(Float(values[0]), Float(values[3]), Float(values[6])),
            simd_float3(Float(values[1]), Float(values[4]), Float(values[7])),
            simd_float3(Float(values[2]), Float(values[5]), Float(values[8]))
        )
    }

    /// Apply matrix to RGB values
    func apply(r: Double, g: Double, b: Double) -> (r: Double, g: Double, b: Double) {
        let newR = values[0] * r + values[1] * g + values[2] * b
        let newG = values[3] * r + values[4] * g + values[5] * b
        let newB = values[6] * r + values[7] * g + values[8] * b
        return (newR, newG, newB)
    }
}
```

**Step 2: Verify build succeeds**

Run: `cd /Users/chuisiufai/Projects/rawctl/rawctl && xcodebuild -scheme rawctl -configuration Debug build 2>&1 | tail -20`

Expected: "BUILD SUCCEEDED"

**Step 3: Commit**

```bash
git add rawctl/rawctl/Models/ColorMatrix.swift
git commit -m "feat(color): add ColorMatrix3x3 for profile transforms"
```

---

## Task 5: Create CameraProfile Model

**Files:**
- Create: `rawctl/rawctl/Models/CameraProfile.swift`

**Step 1: Create camera profile model**

Create `rawctl/rawctl/Models/CameraProfile.swift`:

```swift
//
//  CameraProfile.swift
//  rawctl
//
//  Camera profile for color transform and base look
//

import Foundation

/// Camera profile containing color transform and base look
struct CameraProfile: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let manufacturer: String

    /// Color matrix (camera → working space)
    let colorMatrix: ColorMatrix3x3

    /// Base tone curve (applied before user adjustments)
    let baseToneCurve: FilmicToneCurve

    /// Highlight shoulder parameters
    let highlightShoulder: HighlightShoulder

    /// Optional look adjustments
    let look: ProfileLook?

    static func == (lhs: CameraProfile, rhs: CameraProfile) -> Bool {
        lhs.id == rhs.id
    }
}

/// Optional look/style adjustments for a profile
struct ProfileLook: Codable, Equatable {
    var saturationBoost: Double = 0      // -1.0 to +1.0
    var contrastBoost: Double = 0        // -1.0 to +1.0
    var warmthShift: Double = 0          // -1.0 to +1.0 (cool to warm)
    var shadowTint: Double = 0           // -1.0 to +1.0 (green to magenta)
}

/// Built-in rawctl profiles
enum BuiltInProfile: String, CaseIterable, Identifiable {
    case neutral = "rawctl.neutral"
    case vivid = "rawctl.vivid"
    case portrait = "rawctl.portrait"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .neutral: return "rawctl Neutral"
        case .vivid: return "rawctl Vivid"
        case .portrait: return "rawctl Portrait"
        }
    }

    var icon: String {
        switch self {
        case .neutral: return "circle.lefthalf.filled"
        case .vivid: return "paintpalette"
        case .portrait: return "person.crop.circle"
        }
    }

    var profile: CameraProfile {
        switch self {
        case .neutral:
            return CameraProfile(
                id: rawValue,
                name: "rawctl Neutral",
                manufacturer: "rawctl",
                colorMatrix: .identity,
                baseToneCurve: .filmicNeutral,
                highlightShoulder: .neutral,
                look: nil
            )
        case .vivid:
            return CameraProfile(
                id: rawValue,
                name: "rawctl Vivid",
                manufacturer: "rawctl",
                colorMatrix: .identity,
                baseToneCurve: .filmicVivid,
                highlightShoulder: .vivid,
                look: ProfileLook(saturationBoost: 0.15, contrastBoost: 0.1)
            )
        case .portrait:
            return CameraProfile(
                id: rawValue,
                name: "rawctl Portrait",
                manufacturer: "rawctl",
                colorMatrix: .skinToneOptimized,
                baseToneCurve: .filmicSoft,
                highlightShoulder: .soft,
                look: ProfileLook(saturationBoost: -0.05, warmthShift: 0.02)
            )
        }
    }

    /// Get all built-in profiles
    static var allProfiles: [CameraProfile] {
        allCases.map { $0.profile }
    }

    /// Find profile by ID
    static func profile(for id: String) -> CameraProfile? {
        allCases.first { $0.rawValue == id }?.profile
    }
}
```

**Step 2: Verify build succeeds**

Run: `cd /Users/chuisiufai/Projects/rawctl/rawctl && xcodebuild -scheme rawctl -configuration Debug build 2>&1 | tail -20`

Expected: "BUILD SUCCEEDED"

**Step 3: Commit**

```bash
git add rawctl/rawctl/Models/CameraProfile.swift
git commit -m "feat(color): add CameraProfile with built-in Neutral/Vivid/Portrait"
```

---

## Task 6: Add Profile Selection to EditRecipe

**Files:**
- Modify: `rawctl/rawctl/Models/EditRecipe.swift`

**Step 1: Add profileId property to EditRecipe**

In `rawctl/rawctl/Models/EditRecipe.swift`, add after line 51 (after `calibration`):

```swift
    // MARK: - Camera Profile (v1.2)
    var profileId: String = BuiltInProfile.neutral.rawValue
```

**Step 2: Update hasEdits computed property**

In the `hasEdits` computed property, add profile check:

```swift
    var hasEdits: Bool {
        exposure != 0 || contrast != 0 || highlights != 0 || shadows != 0 ||
        whites != 0 || blacks != 0 || whiteBalance.hasEdits ||
        vibrance != 0 || saturation != 0 || crop.isEnabled || resize.hasEffect ||
        toneCurve.hasEdits || rgbCurves.hasEdits ||
        vignette.hasEffect || splitToning.hasEffect ||
        sharpness > 0 || noiseReduction > 0 || grain.hasEffect ||
        chromaticAberration.hasEffect || perspective.hasEdits ||
        hsl.hasEdits || clarity != 0 || dehaze != 0 || texture != 0 ||
        calibration.hasEdits || profileId != BuiltInProfile.neutral.rawValue
    }
```

**Step 3: Update CodingKeys enum**

Add `profileId` to the CodingKeys enum:

```swift
    private enum CodingKeys: String, CodingKey {
        case exposure, contrast, highlights, shadows, whites, blacks
        case toneCurve, whiteBalance
        case vibrance, saturation
        case crop, resize
        case rgbCurves, vignette, splitToning, sharpness, noiseReduction, grain
        case chromaticAberration, perspective
        case hsl, clarity, dehaze, texture, calibration
        case rating, colorLabel, flag, tags
        case profileId  // v1.2
    }
```

**Step 4: Update init(from decoder:)**

Add profileId decoding in the custom decoder:

```swift
        // Camera Profile (v1.2)
        profileId = try container.decodeIfPresent(String.self, forKey: .profileId) ?? BuiltInProfile.neutral.rawValue
```

**Step 5: Verify build succeeds**

Run: `cd /Users/chuisiufai/Projects/rawctl/rawctl && xcodebuild -scheme rawctl -configuration Debug build 2>&1 | tail -20`

Expected: "BUILD SUCCEEDED"

**Step 6: Commit**

```bash
git add rawctl/rawctl/Models/EditRecipe.swift
git commit -m "feat(color): add profileId to EditRecipe for camera profile selection"
```

---

## Task 7: Write Camera Profile Tests

**Files:**
- Create: `rawctl/rawctlTests/CameraProfileTests.swift`

**Step 1: Create test file**

Create `rawctl/rawctlTests/CameraProfileTests.swift`:

```swift
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
        #expect(profiles.count == 3)
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
```

**Step 2: Run tests**

Run: `cd /Users/chuisiufai/Projects/rawctl/rawctl && xcodebuild test -scheme rawctl -destination 'platform=macOS' 2>&1 | grep -E "(Test Case|passed|failed|error:)"`

Expected: All tests pass

**Step 3: Commit**

```bash
git add rawctl/rawctlTests/CameraProfileTests.swift
git commit -m "test(color): add CameraProfile and color pipeline tests"
```

---

## Task 8: Add Profile Application to ImagePipeline

**Files:**
- Modify: `rawctl/rawctl/Services/ImagePipeline.swift`

**Step 1: Add helper method for applying filmic tone curve**

Add this method to ImagePipeline (after `applyPostRAWRecipe`):

```swift
    // MARK: - Camera Profile Application (v1.2)

    /// Apply camera profile base tone curve and highlight shoulder
    private func applyCameraProfile(_ profile: CameraProfile, to image: CIImage) -> CIImage {
        var result = image

        // 1. Apply base tone curve
        result = applyFilmicToneCurve(profile.baseToneCurve, to: result)

        // 2. Apply highlight shoulder (roll-off)
        if profile.highlightShoulder.hasEffect {
            result = applyHighlightShoulder(profile.highlightShoulder, to: result)
        }

        // 3. Apply profile look (saturation/contrast boost)
        if let look = profile.look {
            result = applyProfileLook(look, to: result)
        }

        return result
    }

    /// Apply filmic tone curve using CIToneCurve
    private func applyFilmicToneCurve(_ curve: FilmicToneCurve, to image: CIImage) -> CIImage {
        guard curve.hasEdits else { return image }

        // CIToneCurve requires exactly 5 points
        // Interpolate our 6 points to 5 for the filter
        let points = curve.points
        let p0 = points.first ?? CurvePoint(x: 0, y: 0)
        let p4 = points.last ?? CurvePoint(x: 1, y: 1)

        // Find points closest to 0.25, 0.5, 0.75
        let p1 = points.first { $0.x >= 0.15 && $0.x <= 0.35 } ?? CurvePoint(x: 0.25, y: 0.25)
        let p2 = points.first { $0.x >= 0.4 && $0.x <= 0.6 } ?? CurvePoint(x: 0.5, y: 0.5)
        let p3 = points.first { $0.x >= 0.7 && $0.x <= 0.9 } ?? CurvePoint(x: 0.75, y: 0.75)

        let filter = CIFilter.toneCurve()
        filter.inputImage = image
        filter.point0 = CGPoint(x: p0.x, y: p0.y)
        filter.point1 = CGPoint(x: p1.x, y: p1.y)
        filter.point2 = CGPoint(x: p2.x, y: p2.y)
        filter.point3 = CGPoint(x: p3.x, y: p3.y)
        filter.point4 = CGPoint(x: p4.x, y: p4.y)

        return filter.outputImage ?? image
    }

    /// Apply highlight shoulder (soft roll-off to prevent clipping)
    private func applyHighlightShoulder(_ shoulder: HighlightShoulder, to image: CIImage) -> CIImage {
        let kneeStart = shoulder.knee
        let whitePoint = shoulder.whitePoint

        // Create shoulder curve using tone curve filter
        let filter = CIFilter.toneCurve()
        filter.inputImage = image
        filter.point0 = CGPoint(x: 0, y: 0)
        filter.point1 = CGPoint(x: 0.25, y: 0.25)
        filter.point2 = CGPoint(x: 0.5, y: 0.5)
        filter.point3 = CGPoint(x: kneeStart, y: kneeStart * (1.0 - shoulder.softness * 0.1))
        filter.point4 = CGPoint(x: 1.0, y: whitePoint)

        return filter.outputImage ?? image
    }

    /// Apply profile look adjustments
    private func applyProfileLook(_ look: ProfileLook, to image: CIImage) -> CIImage {
        var result = image

        // Apply saturation boost
        if look.saturationBoost != 0 {
            let filter = CIFilter.colorControls()
            filter.inputImage = result
            filter.saturation = Float(1.0 + look.saturationBoost)
            result = filter.outputImage ?? result
        }

        // Apply contrast boost using simple S-curve
        if look.contrastBoost != 0 {
            let filter = CIFilter.colorControls()
            filter.inputImage = result
            filter.contrast = Float(1.0 + look.contrastBoost * 0.5)
            result = filter.outputImage ?? result
        }

        // Apply warmth shift (temperature adjustment)
        if look.warmthShift != 0 {
            let filter = CIFilter.temperatureAndTint()
            filter.inputImage = result
            // Warmth: positive = warmer (higher temp), negative = cooler
            filter.neutral = CIVector(x: 6500 + CGFloat(look.warmthShift * 1000), y: 0)
            filter.targetNeutral = CIVector(x: 6500, y: 0)
            result = filter.outputImage ?? result
        }

        return result
    }
```

**Step 2: Integrate profile into applyPostRAWRecipe**

At the beginning of `applyPostRAWRecipe`, add profile application:

```swift
    private func applyPostRAWRecipe(_ recipe: EditRecipe, to image: CIImage, fastMode: Bool = false) -> CIImage {
        var result = image

        // Apply camera profile (v1.2) - base look before user adjustments
        if let profile = BuiltInProfile.profile(for: recipe.profileId) {
            result = applyCameraProfile(profile, to: result)
        }

        // ... rest of existing code
```

**Step 3: Verify build succeeds**

Run: `cd /Users/chuisiufai/Projects/rawctl/rawctl && xcodebuild -scheme rawctl -configuration Debug build 2>&1 | tail -20`

Expected: "BUILD SUCCEEDED"

**Step 4: Run tests**

Run: `cd /Users/chuisiufai/Projects/rawctl/rawctl && xcodebuild test -scheme rawctl -destination 'platform=macOS' 2>&1 | grep -E "(Test Case|passed|failed|error:)"`

Expected: All tests pass

**Step 5: Commit**

```bash
git add rawctl/rawctl/Services/ImagePipeline.swift
git commit -m "feat(color): integrate camera profile into ImagePipeline rendering"
```

---

## Task 9: Create ProfilePicker UI Component

**Files:**
- Create: `rawctl/rawctl/Components/ProfilePicker.swift`

**Step 1: Create profile picker view**

Create `rawctl/rawctl/Components/ProfilePicker.swift`:

```swift
//
//  ProfilePicker.swift
//  rawctl
//
//  Camera profile selection UI component
//

import SwiftUI

/// Picker for selecting camera profiles
struct ProfilePicker: View {
    @Binding var selectedProfileId: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Profile")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                ForEach(BuiltInProfile.allCases) { profile in
                    ProfileButton(
                        profile: profile,
                        isSelected: selectedProfileId == profile.rawValue,
                        action: {
                            selectedProfileId = profile.rawValue
                        }
                    )
                }
            }
        }
    }
}

/// Individual profile selection button
private struct ProfileButton: View {
    let profile: BuiltInProfile
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: profile.icon)
                    .font(.system(size: 16))

                Text(profile.displayName.replacingOccurrences(of: "rawctl ", with: ""))
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? .accentColor : .primary)
    }
}

#Preview {
    ProfilePicker(selectedProfileId: .constant(BuiltInProfile.neutral.rawValue))
        .padding()
        .frame(width: 280)
}
```

**Step 2: Verify build succeeds**

Run: `cd /Users/chuisiufai/Projects/rawctl/rawctl && xcodebuild -scheme rawctl -configuration Debug build 2>&1 | tail -20`

Expected: "BUILD SUCCEEDED"

**Step 3: Commit**

```bash
git add rawctl/rawctl/Components/ProfilePicker.swift
git commit -m "feat(ui): add ProfilePicker component for camera profile selection"
```

---

## Task 10: Integrate ProfilePicker into LightPanel

**Files:**
- Modify: `rawctl/rawctl/Views/Inspector/LightPanel.swift`

**Step 1: Find LightPanel file location**

Run: `find /Users/chuisiufai/Projects/rawctl/rawctl -name "*LightPanel*" -o -name "*Inspector*" | head -10`

**Step 2: Add ProfilePicker to the top of LightPanel**

Add the ProfilePicker at the top of the LightPanel body, before the exposure slider:

```swift
// Add at top of panel content:
ProfilePicker(selectedProfileId: $recipe.profileId)
    .padding(.bottom, 8)

Divider()
    .padding(.bottom, 8)
```

**Step 3: Verify build succeeds**

Run: `cd /Users/chuisiufai/Projects/rawctl/rawctl && xcodebuild -scheme rawctl -configuration Debug build 2>&1 | tail -20`

Expected: "BUILD SUCCEEDED"

**Step 4: Commit**

```bash
git add rawctl/rawctl/Views/Inspector/LightPanel.swift
git commit -m "feat(ui): integrate ProfilePicker into LightPanel inspector"
```

---

## Task 11: Update Sidecar Schema Version

**Files:**
- Modify: `rawctl/rawctl/Models/EditRecipe.swift`

**Step 1: Update schemaVersion in SidecarFile**

In `SidecarFile` struct, update the schema version:

```swift
struct SidecarFile: Codable {
    var schemaVersion: Int = 5 // v5: Added profileId for camera profiles
```

**Step 2: Verify build succeeds**

Run: `cd /Users/chuisiufai/Projects/rawctl/rawctl && xcodebuild -scheme rawctl -configuration Debug build 2>&1 | tail -20`

Expected: "BUILD SUCCEEDED"

**Step 3: Commit**

```bash
git add rawctl/rawctl/Models/EditRecipe.swift
git commit -m "chore: bump sidecar schema to v5 for profileId"
```

---

## Task 12: Final Integration Test

**Step 1: Build and run tests**

Run: `cd /Users/chuisiufai/Projects/rawctl/rawctl && xcodebuild test -scheme rawctl -destination 'platform=macOS' 2>&1 | grep -E "(Test Suite|passed|failed|Executed)"`

Expected: All tests pass

**Step 2: Manual verification checklist**

- [ ] App builds without errors
- [ ] ProfilePicker visible in Light panel
- [ ] Selecting different profiles changes preview
- [ ] Vivid profile shows more contrast/saturation
- [ ] Portrait profile has warmer, softer look
- [ ] Profile selection persists in sidecar

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat(color): complete Phase 1 color foundation

- Add ColorPipelineConfig for working/display spaces
- Add HighlightShoulder for soft highlight roll-off
- Add FilmicToneCurve with Neutral/Vivid/Soft presets
- Add ColorMatrix3x3 for profile transforms
- Add CameraProfile with 3 built-in profiles
- Integrate profile application into ImagePipeline
- Add ProfilePicker UI component
- Bump sidecar schema to v5

Part of v1.2 image pipeline improvements."
```

---

## Summary

**Files Created:**
- `Models/ColorPipelineConfig.swift`
- `Models/HighlightShoulder.swift`
- `Models/FilmicToneCurve.swift`
- `Models/ColorMatrix.swift`
- `Models/CameraProfile.swift`
- `Components/ProfilePicker.swift`
- `rawctlTests/CameraProfileTests.swift`

**Files Modified:**
- `Models/EditRecipe.swift` (added profileId, updated hasEdits, CodingKeys, decoder)
- `Services/ImagePipeline.swift` (added profile application methods)
- `Views/Inspector/LightPanel.swift` (added ProfilePicker)

**Total Tasks:** 12
**Estimated Time:** 60-90 minutes

---

## Next Phase

After Phase 1 is complete, proceed to Phase 2: Preview System
- PreviewPyramid (multi-resolution)
- TileRenderer (viewport-based rendering)
- RenderCoordinator (draft/full quality)
- IntermediateCache (stage-based caching)
