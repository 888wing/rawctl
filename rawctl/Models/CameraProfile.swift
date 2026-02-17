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
    case original = "rawctl.original"
    case neutral = "rawctl.neutral"
    case vivid = "rawctl.vivid"
    case portrait = "rawctl.portrait"
    case landscape = "rawctl.landscape"
    case cinematic = "rawctl.cinematic"
    case monochrome = "rawctl.monochrome"
    case night = "rawctl.night"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .original: return "Original"
        case .neutral: return "rawctl Neutral"
        case .vivid: return "rawctl Vivid"
        case .portrait: return "rawctl Portrait"
        case .landscape: return "rawctl Landscape"
        case .cinematic: return "rawctl Cinematic"
        case .monochrome: return "rawctl B&W"
        case .night: return "rawctl Night"
        }
    }

    var icon: String {
        switch self {
        case .original: return "camera"
        case .neutral: return "circle.lefthalf.filled"
        case .vivid: return "paintpalette"
        case .portrait: return "person.crop.circle"
        case .landscape: return "mountain.2"
        case .cinematic: return "film"
        case .monochrome: return "circle.lefthalf.striped.horizontal"
        case .night: return "moon.stars"
        }
    }

    var profile: CameraProfile {
        switch self {
        case .original:
            return CameraProfile(
                id: rawValue,
                name: "Original",
                manufacturer: "rawctl",
                colorMatrix: .identity,
                baseToneCurve: .linear,
                highlightShoulder: .none,
                look: nil
            )
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
        case .landscape:
            return CameraProfile(
                id: rawValue,
                name: "rawctl Landscape",
                manufacturer: "rawctl",
                colorMatrix: .identity,
                baseToneCurve: .filmicVivid,
                highlightShoulder: .vivid,
                look: ProfileLook(saturationBoost: 0.2, contrastBoost: 0.12, warmthShift: -0.03)
            )
        case .cinematic:
            return CameraProfile(
                id: rawValue,
                name: "rawctl Cinematic",
                manufacturer: "rawctl",
                colorMatrix: .identity,
                baseToneCurve: .filmicSoft,
                highlightShoulder: .soft,
                look: ProfileLook(saturationBoost: -0.1, contrastBoost: 0.16, warmthShift: -0.02)
            )
        case .monochrome:
            return CameraProfile(
                id: rawValue,
                name: "rawctl B&W",
                manufacturer: "rawctl",
                colorMatrix: .identity,
                baseToneCurve: .filmicNeutral,
                highlightShoulder: .neutral,
                look: ProfileLook(saturationBoost: -1.0, contrastBoost: 0.15)
            )
        case .night:
            return CameraProfile(
                id: rawValue,
                name: "rawctl Night",
                manufacturer: "rawctl",
                colorMatrix: .identity,
                baseToneCurve: .filmicSoft,
                highlightShoulder: .neutral,
                look: ProfileLook(saturationBoost: -0.12, contrastBoost: 0.08, warmthShift: -0.08)
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
