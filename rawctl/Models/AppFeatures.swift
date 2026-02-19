//
//  AppFeatures.swift
//  rawctl
//
//  Build/runtime feature flags for optional entry points.
//

import Foundation

enum AppFeatures {
    private static func envEnabled(_ keys: [String]) -> Bool {
        let env = ProcessInfo.processInfo.environment
        return keys.contains { env[$0] == "1" }
    }

    // Defaults to OFF to avoid dead-end entry points in production.
    static var devicesEntryPointsEnabled: Bool {
        envEnabled(["LATENT_ENABLE_DEVICES", "RAWCTL_ENABLE_DEVICES"])
    }

    // Defaults to OFF unless explicitly enabled for QA/internal builds.
    static var recentImportsEntryPointEnabled: Bool {
        envEnabled(["LATENT_ENABLE_RECENT_IMPORTS", "RAWCTL_ENABLE_RECENT_IMPORTS"])
    }
}

