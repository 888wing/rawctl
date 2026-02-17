//
//  E2EFixtureGenerator.swift
//  rawctl
//
//  Small helper for deterministic UI/E2E runs in a sandboxed app.
//

import Foundation

enum E2EFixtureGenerator {
    enum Error: Swift.Error {
        case invalidEmbeddedPNG
    }

    /// Creates a new folder under the app's sandboxed temp directory and writes `count` tiny PNGs:
    /// `E2E_001.png`, `E2E_002.png`, ...
    static func generatePNGFolder(count: Int) throws -> URL {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory
            .appendingPathComponent("rawctl-e2e-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        // 1x1 PNG (opaque white)
        let pngBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7+Gx0AAAAASUVORK5CYII="
        guard let pngData = Data(base64Encoded: pngBase64) else {
            throw Error.invalidEmbeddedPNG
        }

        let fileCount = max(1, count)
        for i in 1...fileCount {
            let name = String(format: "E2E_%03d.png", i)
            try pngData.write(to: dir.appendingPathComponent(name), options: .atomic)
        }

        return dir
    }
}

