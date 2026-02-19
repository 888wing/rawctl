//
//  AppFeatures.swift
//  rawctl
//
//  Build/runtime feature flags for optional entry points and Pro gating.
//

import Foundation

enum AppFeatures {
    private static func parseBool(_ value: String) -> Bool {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on", "enabled":
            return true
        default:
            return false
        }
    }

    private static func envEnabled(_ keys: [String]) -> Bool {
        let env = ProcessInfo.processInfo.environment
        for key in keys {
            if let value = env[key] {
                return parseBool(value)
            }
        }
        return false
    }

    // MARK: - Entry Point Flags

    // Defaults to OFF to avoid dead-end entry points in production.
    static var devicesEntryPointsEnabled: Bool {
        envEnabled(["LATENT_ENABLE_DEVICES", "RAWCTL_ENABLE_DEVICES"])
    }

    // Defaults to OFF unless explicitly enabled for QA/internal builds.
    static var recentImportsEntryPointEnabled: Bool {
        envEnabled(["LATENT_ENABLE_RECENT_IMPORTS", "RAWCTL_ENABLE_RECENT_IMPORTS"])
    }

    // MARK: - AI Tier Flags
    //
    // AI Culling is FREE — Apple Vision only, zero marginal cost.
    // Smart Sync and AI Masking are PRO features.
    //
    // Tier check delegates to AccountService.shared.isProUser which reads
    // the subscription plan from the backend (no StoreKit purchase required).
    //
    // Usage in views:
    //   if AppFeatures.isProUser { … } else { appState.showAccountSheet = true }
    //
    // Override for QA/CI with: LATENT_PRO_OVERRIDE=1

    /// AI Photo Culling is always available (free tier feature).
    static var aiCullingEnabled: Bool { true }

    /// Scene-Aware Smart Sync — Pro only.
    @MainActor
    static var smartSyncEnabled: Bool {
        isProUser
    }

    /// AI Masking via Mobile-SAM — Pro only.
    @MainActor
    static var aiMaskingEnabled: Bool {
        isProUser
    }

    // MARK: - Pro Status

    /// True if the current user has an active Pro subscription.
    ///
    /// Reads from `AccountService.shared.isProUser`.
    /// Override for QA/internal builds with `LATENT_PRO_OVERRIDE=1`.
    @MainActor
    static var isProUser: Bool {
        if envEnabled(["LATENT_PRO_OVERRIDE", "RAWCTL_PRO_OVERRIDE"]) { return true }
        return AccountService.shared.isProUser
    }
}
