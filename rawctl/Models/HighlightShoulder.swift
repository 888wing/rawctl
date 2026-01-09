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
