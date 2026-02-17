//
//  FileSystemService.swift
//  rawctl
//
//  File system operations: folder selection, scanning
//

import Foundation
import AppKit

/// Service for file system operations
actor FileSystemService {
    
    /// Show folder selection dialog
    @MainActor
    static func selectFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder containing RAW or image files"
        panel.prompt = "Select Folder"
        
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
    
    /// Scan a folder for supported image files
    static func scanFolder(_ url: URL) async throws -> [PhotoAsset] {
        let fileManager = FileManager.default

        let signpostId = PerformanceSignposts.signposter.makeSignpostID()
        let signpostState = PerformanceSignposts.begin("scanFolder", id: signpostId)
        var scannedCount = 0
        var assets: [PhotoAsset] = []
        defer {
            PerformanceSignposts.end("scanFolder", signpostState)
        }
        
        print("[FileSystem] Scanning folder: \(url.path)")
        
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            print("[FileSystem] Cannot enumerate folder")
            throw FileSystemError.cannotEnumerateFolder
        }
        
        var skippedExtensions: Set<String> = []
        
        // Avoid `DirectoryEnumerator` Sequence iteration in async context (Swift 6 `noasync`).
        while let fileURL = enumerator.nextObject() as? URL {
            scannedCount += 1
            
            // Check if it's a regular file
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .creationDateKey, .contentModificationDateKey, .fileSizeKey]),
                  resourceValues.isRegularFile == true else {
                continue
            }
            
            // Check extension
            let ext = fileURL.pathExtension.lowercased()
            guard PhotoAsset.supportedExtensions.contains(ext) else {
                skippedExtensions.insert(ext)
                continue
            }

            let fileSize = Int64(resourceValues.fileSize ?? 0)
            let creationDate = resourceValues.creationDate
            let modificationDate = resourceValues.contentModificationDate
            let fingerprint = PhotoAsset.createFingerprint(fileSize: fileSize, modificationDate: modificationDate)
            assets.append(
                PhotoAsset(
                    url: fileURL,
                    fileSize: fileSize,
                    creationDate: creationDate,
                    modificationDate: modificationDate,
                    fingerprint: fingerprint
                )
            )
        }
        
        print("[FileSystem] Scanned \(scannedCount) items, found \(assets.count) supported images")
        if !skippedExtensions.isEmpty {
            print("[FileSystem] Skipped extensions: \(skippedExtensions.sorted().joined(separator: ", "))")
        }
        
        // Sort by filename
        assets.sort { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }
        
        return assets
    }
    
    /// Get sidecar file URL for an asset
    static func sidecarURL(for assetURL: URL) -> URL {
        let filename = assetURL.lastPathComponent
        let sidecarName = "\(filename).rawctl.json"
        return assetURL.deletingLastPathComponent().appendingPathComponent(sidecarName)
    }
    
    // MARK: - Incremental Scanning
    
    /// Folder state for incremental scanning
    struct FolderState: Codable {
        var folderPath: String
        var lastScanDate: Date
        var assetFingerprints: [String: String]  // filename -> fingerprint
        
        static func cacheURL(for folderURL: URL) -> URL {
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let folderHash = folderURL.path.hash
            return caches
                .appendingPathComponent("Shacoworkshop.rawctl", isDirectory: true)
                .appendingPathComponent("folderstate_\(folderHash).json")
        }
    }
    
    /// Load cached folder state
    static func loadFolderState(for folderURL: URL) -> FolderState? {
        let stateURL = FolderState.cacheURL(for: folderURL)
        guard let data = try? Data(contentsOf: stateURL),
              let state = try? JSONDecoder().decode(FolderState.self, from: data) else {
            return nil
        }
        return state
    }
    
    /// Save folder state to cache
    static func saveFolderState(_ state: FolderState, for folderURL: URL) {
        let stateURL = FolderState.cacheURL(for: folderURL)
        
        // Ensure directory exists
        try? FileManager.default.createDirectory(
            at: stateURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: stateURL)
        }
    }
    
    /// Incremental scan result
    struct IncrementalScanResult {
        var unchanged: [PhotoAsset]  // Assets that haven't changed
        var added: [PhotoAsset]      // New assets
        var removed: [String]        // Fingerprints of removed assets
    }
    
    /// Perform incremental folder scan
    /// Returns unchanged, added, and removed assets
    static func incrementalScan(
        _ url: URL,
        previousAssets: [PhotoAsset],
        cachedState: FolderState?
    ) async throws -> IncrementalScanResult {
        let fileManager = FileManager.default

        let signpostId = PerformanceSignposts.signposter.makeSignpostID()
        let signpostState = PerformanceSignposts.begin("incrementalScan", id: signpostId)
        defer {
            PerformanceSignposts.end("incrementalScan", signpostState)
        }
        
        print("[FileSystem] Incremental scan: \(url.path)")
        
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw FileSystemError.cannotEnumerateFolder
        }
        
        // Build lookup from previous assets
        var previousByFingerprint: [String: PhotoAsset] = [:]
        for asset in previousAssets {
            previousByFingerprint[asset.fingerprint] = asset
        }
        
        var unchanged: [PhotoAsset] = []
        var added: [PhotoAsset] = []
        var seenFingerprints: Set<String> = []
        
        // Avoid `DirectoryEnumerator` Sequence iteration in async context (Swift 6 `noasync`).
        while let fileURL = enumerator.nextObject() as? URL {
            // Check if it's a regular file
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .creationDateKey, .contentModificationDateKey, .fileSizeKey]),
                  resourceValues.isRegularFile == true else {
                continue
            }
            
            // Check extension
            let ext = fileURL.pathExtension.lowercased()
            guard PhotoAsset.supportedExtensions.contains(ext) else {
                continue
            }
            
            let fileSize = Int64(resourceValues.fileSize ?? 0)
            let creationDate = resourceValues.creationDate
            let modificationDate = resourceValues.contentModificationDate
            let fingerprint = PhotoAsset.createFingerprint(fileSize: fileSize, modificationDate: modificationDate)
            seenFingerprints.insert(fingerprint)
            
            // Check if asset existed before
            if let existing = previousByFingerprint[fingerprint] {
                unchanged.append(existing)
            } else {
                added.append(
                    PhotoAsset(
                        url: fileURL,
                        fileSize: fileSize,
                        creationDate: creationDate,
                        modificationDate: modificationDate,
                        fingerprint: fingerprint
                    )
                )
            }
        }
        
        // Find removed
        let removedFingerprints = Set(previousByFingerprint.keys).subtracting(seenFingerprints)
        
        print("[FileSystem] Incremental result: \(unchanged.count) unchanged, \(added.count) added, \(removedFingerprints.count) removed")
        
        return IncrementalScanResult(
            unchanged: unchanged,
            added: added,
            removed: Array(removedFingerprints)
        )
    }
    
    /// Build folder state from assets
    static func buildFolderState(for folderURL: URL, assets: [PhotoAsset]) -> FolderState {
        var fingerprints: [String: String] = [:]
        for asset in assets {
            fingerprints[asset.filename] = asset.fingerprint
        }
        return FolderState(
            folderPath: folderURL.path,
            lastScanDate: Date(),
            assetFingerprints: fingerprints
        )
    }
}

enum FileSystemError: LocalizedError {
    case cannotEnumerateFolder
    case cannotReadFile
    case cannotWriteFile
    
    var errorDescription: String? {
        switch self {
        case .cannotEnumerateFolder:
            return "Cannot read the selected folder"
        case .cannotReadFile:
            return "Cannot read the file"
        case .cannotWriteFile:
            return "Cannot write the file"
        }
    }
}
