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

    /// Active camera profile ID (default: rawctl.neutral)
    var profileId: String = "rawctl.neutral"
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
