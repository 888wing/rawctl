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
