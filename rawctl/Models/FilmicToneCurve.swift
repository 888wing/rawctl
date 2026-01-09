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
