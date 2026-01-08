//
//  PhotoAsset.swift
//  rawctl
//
//  Model representing a single image file with metadata
//

import Foundation
import UniformTypeIdentifiers

/// Represents a single photo file in the working directory
struct PhotoAsset: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let fingerprint: String
    var metadata: ImageMetadata?
    
    // File attributes for sorting
    var fileSize: Int64 = 0
    var creationDate: Date?
    var modificationDate: Date?
    
    // Organization
    var rating: Int = 0              // 0-5 stars
    var flag: FlagStatus = .none
    
    var filename: String {
        url.lastPathComponent
    }
    
    var fileExtension: String {
        url.pathExtension.uppercased()
    }
    
    var isRAW: Bool {
        Self.rawExtensions.contains(url.pathExtension.lowercased())
    }
    
    /// Supported RAW file extensions (expanded list)
    static let rawExtensions: Set<String> = [
        // Common RAW formats
        "cr2", "cr3",           // Canon
        "nef", "nrw",           // Nikon
        "arw", "srf", "sr2",    // Sony
        "dng",                  // Adobe/Universal
        "rw2", "rwl",           // Panasonic
        "orf",                  // Olympus
        "raf",                  // Fujifilm
        "pef", "ptx",           // Pentax
        "srw",                  // Samsung
        "3fr", "fff",           // Hasselblad
        "iiq",                  // Phase One
        "mrw",                  // Minolta
        "x3f",                  // Sigma
        "erf",                  // Epson
        "mef", "mos",           // Mamiya
        "mdc", "kdc", "dcr",    // Kodak
        "raw",                  // Generic
    ]
    
    /// Supported image file extensions (including RAW)
    static let supportedExtensions: Set<String> = rawExtensions.union([
        "jpg", "jpeg",          // JPEG
        "tif", "tiff",          // TIFF
        "png",                  // PNG
        "heic", "heif",         // Apple HEIC
        "webp",                 // WebP
    ])
    
    /// Create fingerprint from file attributes (size + modification time)
    static func createFingerprint(for url: URL) -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return nil
        }
        let size = attrs[.size] as? Int64 ?? 0
        let mtime = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        return "\(size)-\(Int(mtime))"
    }
    
    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.fingerprint = Self.createFingerprint(for: url) ?? UUID().uuidString
        self.metadata = nil
        
        // Load file attributes for sorting
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) {
            self.fileSize = attrs[.size] as? Int64 ?? 0
            self.creationDate = attrs[.creationDate] as? Date
            self.modificationDate = attrs[.modificationDate] as? Date
        }
    }
}

/// Basic image metadata from EXIF
struct ImageMetadata: Hashable, Codable {
    var width: Int?
    var height: Int?
    var cameraMake: String?
    var cameraModel: String?
    var lens: String?
    var iso: Int?
    var shutterSpeed: String?
    var aperture: String?
    var focalLength: String?
    var dateTime: Date?
    
    var cameraDescription: String {
        [cameraMake, cameraModel].compactMap { $0 }.joined(separator: " ")
    }
    
    var exposureDescription: String {
        var parts: [String] = []
        if let iso = iso { parts.append("ISO \(iso)") }
        if let aperture = aperture { parts.append(aperture) }
        if let shutter = shutterSpeed { parts.append(shutter) }
        return parts.joined(separator: "  ")
    }
}
