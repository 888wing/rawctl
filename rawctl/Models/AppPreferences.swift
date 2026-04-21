//
//  AppPreferences.swift
//  rawctl
//
//  Shared app-level preferences for startup experience and preview caching.
//

import Foundation

enum StartupRestoreMode: String, CaseIterable, Identifiable {
    case lastProject
    case lastOpenedFolder
    case defaultFolder

    var id: Self { self }

    var title: String {
        switch self {
        case .lastProject:
            return "Last Project"
        case .lastOpenedFolder:
            return "Last Opened Folder"
        case .defaultFolder:
            return "Default Folder"
        }
    }

    var description: String {
        switch self {
        case .lastProject:
            return "Restore the previous project first, then fall back to folders if needed."
        case .lastOpenedFolder:
            return "Skip project restore and reopen the last folder you browsed."
        case .defaultFolder:
            return "Always start from a pinned library folder you choose below."
        }
    }

    var symbolName: String {
        switch self {
        case .lastProject:
            return "square.stack"
        case .lastOpenedFolder:
            return "clock.arrow.circlepath"
        case .defaultFolder:
            return "folder.badge.star"
        }
    }
}

enum StartupPresentationMode: String, CaseIterable, Identifiable {
    case directLibrary
    case preloadImage

    var id: Self { self }

    var title: String {
        switch self {
        case .directLibrary:
            return "Direct Library"
        case .preloadImage:
            return "Preload Hero"
        }
    }

    var description: String {
        switch self {
        case .directLibrary:
            return "Open directly into the restored project or folder without a launch hero."
        case .preloadImage:
            return "Show one real photo on launch while warming its edit preview."
        }
    }

    var symbolName: String {
        switch self {
        case .directLibrary:
            return "rectangle.stack"
        case .preloadImage:
            return "photo.on.rectangle"
        }
    }
}

enum PreviewCacheBudget: Int, CaseIterable, Identifiable {
    case mb500 = 500_000_000
    case gb1 = 1_000_000_000
    case gb2 = 2_000_000_000
    case gb4 = 4_000_000_000

    var id: Int { rawValue }

    var bytes: Int64 {
        Int64(rawValue)
    }

    var title: String {
        switch self {
        case .mb500:
            return "500 MB"
        case .gb1:
            return "1 GB"
        case .gb2:
            return "2 GB"
        case .gb4:
            return "4 GB"
        }
    }

    var description: String {
        switch self {
        case .mb500:
            return "Best for laptops with limited storage."
        case .gb1:
            return "Balanced default for day-to-day editing."
        case .gb2:
            return "Keeps more edited previews warm across launches."
        case .gb4:
            return "Most aggressive cache for large active libraries."
        }
    }

    init(storedBytes: Int64) {
        switch storedBytes {
        case ..<750_000_000:
            self = .mb500
        case ..<1_500_000_000:
            self = .gb1
        case ..<3_000_000_000:
            self = .gb2
        default:
            self = .gb4
        }
    }
}

enum AppPreferences {
    static let startupRestoreModeKey = "latent.startup.restoreMode"
    static let startupSurfaceModeKey = "latent.startup.surfaceMode"
    static let persistentPreviewDiskCacheEnabledKey = "latent.previewDiskCache.enabled"
    static let persistentPreviewDiskCacheMaxBytesKey = "latent.previewDiskCache.maxBytes"

    static let defaultStartupRestoreMode: StartupRestoreMode = .lastProject
    static let defaultStartupPresentationMode: StartupPresentationMode = .preloadImage
    static let defaultPersistentPreviewDiskCacheEnabled = true
    static let defaultPersistentPreviewDiskCacheMaxBytes: Int64 = PreviewCacheBudget.gb1.bytes

    static func startupRestoreMode(userDefaults: UserDefaults = .standard) -> StartupRestoreMode {
        guard let rawValue = userDefaults.string(forKey: startupRestoreModeKey),
              let mode = StartupRestoreMode(rawValue: rawValue) else {
            return defaultStartupRestoreMode
        }
        return mode
    }

    static func startupPresentationMode(userDefaults: UserDefaults = .standard) -> StartupPresentationMode {
        guard let rawValue = userDefaults.string(forKey: startupSurfaceModeKey) else {
            return defaultStartupPresentationMode
        }

        switch rawValue {
        case StartupPresentationMode.directLibrary.rawValue, "lastOpenedFolder":
            return .directLibrary
        case StartupPresentationMode.preloadImage.rawValue:
            return .preloadImage
        default:
            return defaultStartupPresentationMode
        }
    }

    static func persistentPreviewDiskCacheEnabled(userDefaults: UserDefaults = .standard) -> Bool {
        if userDefaults.object(forKey: persistentPreviewDiskCacheEnabledKey) == nil {
            return defaultPersistentPreviewDiskCacheEnabled
        }
        return userDefaults.bool(forKey: persistentPreviewDiskCacheEnabledKey)
    }

    static func persistentPreviewDiskCacheMaxBytes(userDefaults: UserDefaults = .standard) -> Int64 {
        let storedValue = userDefaults.object(forKey: persistentPreviewDiskCacheMaxBytesKey) as? NSNumber
        let value = storedValue?.int64Value ?? defaultPersistentPreviewDiskCacheMaxBytes
        return max(PreviewCacheBudget.mb500.bytes, value)
    }

    static func persistentPreviewBudget(userDefaults: UserDefaults = .standard) -> PreviewCacheBudget {
        PreviewCacheBudget(storedBytes: persistentPreviewDiskCacheMaxBytes(userDefaults: userDefaults))
    }
}
