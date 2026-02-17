//
//  HistogramDataTests.swift
//  rawctlTests
//
//  Regression tests for histogram color-space handling.
//

import AppKit
import Testing
@testable import rawctl

struct HistogramDataTests {

    @Test func computeHandlesDeviceWhiteBitmap() async throws {
        let width = 4
        let height = 4

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 1,
            hasAlpha: false,
            isPlanar: false,
            colorSpaceName: .deviceWhite,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            Issue.record("Failed to create grayscale bitmap representation")
            return
        }

        guard let pixels = rep.bitmapData else {
            Issue.record("Missing grayscale bitmap data")
            return
        }

        for i in 0..<(width * height) {
            pixels[i] = UInt8(64 + (i % 3) * 64)
        }

        let image = NSImage(size: NSSize(width: width, height: height))
        image.addRepresentation(rep)

        let histogram = await HistogramData.compute(from: image)
        let totalSamples = histogram.luminance.reduce(0, +)

        #expect(totalSamples > 0)
    }

    @Test func computeHandlesSystemColorRenderedImage() async throws {
        let size = NSSize(width: 64, height: 64)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.controlAccentColor.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()

        let histogram = await HistogramData.compute(from: image)
        let redTotal = histogram.red.reduce(0, +)
        let greenTotal = histogram.green.reduce(0, +)
        let blueTotal = histogram.blue.reduce(0, +)
        let luminanceTotal = histogram.luminance.reduce(0, +)

        #expect(redTotal > 0)
        #expect(greenTotal > 0)
        #expect(blueTotal > 0)
        #expect(luminanceTotal > 0)
    }
}
