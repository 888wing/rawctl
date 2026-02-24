//
//  FileSystemServiceCacheMigrationTests.swift
//  rawctlTests
//
//  Cache namespace migration coverage for folder state.
//

import Foundation
import Testing
@testable import Latent

struct FileSystemServiceCacheMigrationTests {
    @Test func loadFolderStateFallsBackToLegacyNamespace() throws {
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appendingPathComponent(
            "latent-folderstate-\(UUID().uuidString)",
            isDirectory: true
        )
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: folder) }

        let legacyURL = FileSystemService.FolderState.legacyCacheURL(for: folder)
        let currentURL = FileSystemService.FolderState.cacheURL(for: folder)
        defer {
            try? fm.removeItem(at: legacyURL)
            try? fm.removeItem(at: currentURL)
        }

        let state = FileSystemService.FolderState(
            folderPath: folder.path,
            lastScanDate: Date(timeIntervalSince1970: 123_456),
            assetFingerprints: ["sample.jpg": "123-456"]
        )
        try fm.createDirectory(at: legacyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(state).write(to: legacyURL, options: .atomic)

        #expect(!fm.fileExists(atPath: currentURL.path))

        let loaded = FileSystemService.loadFolderState(for: folder)
        #expect(loaded?.folderPath == folder.path)
        #expect(loaded?.assetFingerprints == state.assetFingerprints)
    }

    @Test func saveFolderStateWritesCurrentNamespace() throws {
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appendingPathComponent(
            "latent-folderstate-save-\(UUID().uuidString)",
            isDirectory: true
        )
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: folder) }

        let currentURL = FileSystemService.FolderState.cacheURL(for: folder)
        let legacyURL = FileSystemService.FolderState.legacyCacheURL(for: folder)
        defer {
            try? fm.removeItem(at: currentURL)
            try? fm.removeItem(at: legacyURL)
        }

        let state = FileSystemService.FolderState(
            folderPath: folder.path,
            lastScanDate: Date(),
            assetFingerprints: ["sample.jpg": "1-2"]
        )
        FileSystemService.saveFolderState(state, for: folder)

        #expect(fm.fileExists(atPath: currentURL.path))
    }
}
