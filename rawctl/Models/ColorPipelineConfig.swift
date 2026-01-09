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
    /// Falls back to sRGB if Display P3 unavailable (older systems)
    static let workingColorSpace: CGColorSpace = {
        CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpace(name: CGColorSpace.sRGB)!
    }()

    /// Output color space for display
    static let displayColorSpace: CGColorSpace = {
        CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    }()

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
