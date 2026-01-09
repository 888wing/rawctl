//
//  ReleaseNotes.swift
//  rawctl
//
//  Release notes data structure and version history
//

import Foundation

// MARK: - Release Notes Data

struct ReleaseNote: Identifiable, Codable, Hashable {
    let id: String
    let version: String
    let date: Date
    let title: String
    let highlights: [String]
    let sections: [ReleaseSection]

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ReleaseNote, rhs: ReleaseNote) -> Bool {
        lhs.id == rhs.id
    }
}

struct ReleaseSection: Identifiable, Codable, Hashable {
    var id: String { title }
    let title: String  // "Added", "Changed", "Fixed", etc.
    let items: [String]
}

// MARK: - Release History

struct ReleaseHistory {
    static let notes: [ReleaseNote] = [
        ReleaseNote(
            id: "1.1.0",
            version: "1.1.0",
            date: dateFrom("2026-01-08"),
            title: "Crop, Rotate & Resize",
            highlights: [
                "Full crop overlay with aspect ratio enforcement",
                "Straighten, rotate 90°, and flip controls",
                "Non-destructive resize with multiple modes",
                "Enhanced security with device tracking"
            ],
            sections: [
                ReleaseSection(title: "Crop & Composition", items: [
                    "Crop overlay with draggable corner handles and rule-of-thirds grid",
                    "Aspect ratio presets: Free, Original, 1:1, 4:3, 3:2, 16:9, 5:4, 7:5",
                    "Aspect ratio enforcement when dragging crop handles",
                    "Real-time dimension labels showing crop size in pixels",
                    "Straighten slider (-45° to +45°) for fine rotation adjustment",
                    "90° rotation buttons (rotate left/right)",
                    "Flip horizontal/vertical toggle buttons"
                ]),
                ReleaseSection(title: "Resize", items: [
                    "ResizePanel in Inspector with multiple modes",
                    "Modes: Pixels, Percentage, Long Edge, Short Edge, Presets",
                    "Presets: Instagram, Facebook Cover, Twitter Header, 4K/2K Wallpaper",
                    "Maintain aspect ratio toggle",
                    "Calculated output dimensions preview",
                    "Recipe-based resize stored non-destructively"
                ]),
                ReleaseSection(title: "Transform Mode", items: [
                    "Transform toolbar with Crop button alongside AI Edit",
                    "Keyboard shortcut C to toggle transform mode",
                    "Enter to commit and exit, Escape to cancel"
                ]),
                ReleaseSection(title: "Export Enhancements", items: [
                    "\"Use Recipe Resize\" export option",
                    "Recipe resize dimensions displayed in export dialog",
                    "Info/warning messages when recipe resize is configured"
                ]),
                ReleaseSection(title: "Security Hardening", items: [
                    "Device ID tracking via Keychain",
                    "Rate limit handling with Retry-After support",
                    "Security block detection for HTTP 403",
                    "Token replay detection with automatic sign-out"
                ])
            ]
        ),
        ReleaseNote(
            id: "1.0.0",
            version: "1.0.0",
            date: dateFrom("2026-01-08"),
            title: "First Stable Release",
            highlights: [
                "Professional white balance controls",
                "Photo organization with ratings, flags, and labels",
                "True RAW processing via CIRAWFilter",
                "Non-destructive editing with sidecar files"
            ],
            sections: [
                ReleaseSection(title: "White Balance", items: [
                    "Preset modes: As Shot, Auto, Daylight, Cloudy, Shade, Tungsten, Fluorescent, Flash",
                    "Kelvin temperature slider (2000-12000K)",
                    "Tint adjustment (-150 to +150)",
                    "Eyedropper tool for picking neutral point"
                ]),
                ReleaseSection(title: "Effects", items: [
                    "Vignette with amount and midpoint controls",
                    "Sharpness (luminance sharpening)",
                    "Noise reduction",
                    "Split toning (highlight/shadow color grading)"
                ]),
                ReleaseSection(title: "Organization", items: [
                    "Rating: 0-5 stars with visual indicators",
                    "Flags: Pick (green) / Reject (red) / Unflag",
                    "Color labels: 7 colors with thumbnail indicators",
                    "Tags: Custom text tags with add/remove",
                    "FilterBar: Filter photos by rating, flag, color, or tag"
                ]),
                ReleaseSection(title: "Keyboard Shortcuts", items: [
                    "1-5: Set rating (same key toggles off)",
                    "0: Clear rating",
                    "P: Pick flag, X: Reject flag, U: Unflag",
                    "6-9: Color labels (Red, Yellow, Green, Blue)"
                ]),
                ReleaseSection(title: "Core Features", items: [
                    "Folder browsing with file list",
                    "Thumbnail grid view and single photo view",
                    "True RAW processing via CIRAWFilter",
                    "Non-destructive editing stored in sidecar JSON",
                    "5-point Tone Curve editor",
                    "JPG export with sRGB profile",
                    "Memory card detection"
                ]),
                ReleaseSection(title: "Performance", items: [
                    "Two-stage loading: Instant embedded JPEG preview, then full RAW decode",
                    "Eliminated flicker when adjusting sliders",
                    "Debounced preview updates (50ms)",
                    "RAW filter caching"
                ])
            ]
        )
    ]

    static var latest: ReleaseNote {
        notes.first!
    }

    static func note(for version: String) -> ReleaseNote? {
        notes.first { $0.version == version }
    }

    private static func dateFrom(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string) ?? Date()
    }
}

// MARK: - Version Tracking

struct VersionTracker {
    private static let lastSeenVersionKey = "rawctl_last_seen_version"

    /// Get the current app version
    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    /// Get the current build number
    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    /// Get the last version the user has seen What's New for
    static var lastSeenVersion: String? {
        UserDefaults.standard.string(forKey: lastSeenVersionKey)
    }

    /// Mark the current version as seen
    static func markCurrentVersionAsSeen() {
        UserDefaults.standard.set(currentVersion, forKey: lastSeenVersionKey)
    }

    /// Check if What's New should be shown
    static var shouldShowWhatsNew: Bool {
        guard let lastSeen = lastSeenVersion else {
            // First time user - show What's New
            return true
        }
        // Show if current version is newer than last seen
        return compareVersions(currentVersion, lastSeen) == .orderedDescending
    }

    /// Compare two version strings
    private static func compareVersions(_ v1: String, _ v2: String) -> ComparisonResult {
        let v1Parts = v1.split(separator: ".").compactMap { Int($0) }
        let v2Parts = v2.split(separator: ".").compactMap { Int($0) }

        let maxLength = max(v1Parts.count, v2Parts.count)

        for i in 0..<maxLength {
            let p1 = i < v1Parts.count ? v1Parts[i] : 0
            let p2 = i < v2Parts.count ? v2Parts[i] : 0

            if p1 > p2 { return .orderedDescending }
            if p1 < p2 { return .orderedAscending }
        }

        return .orderedSame
    }
}
