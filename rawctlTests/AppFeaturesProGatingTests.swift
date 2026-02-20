//
//  AppFeaturesProGatingTests.swift
//  rawctlTests
//
//  Tests that verify the tier-gating contract in AppFeatures:
//   - AI Culling is always free (no Pro check).
//   - Smart Sync and AI Masking gate behind isProUser.
//   - smartSyncEnabled, aiMaskingEnabled, and isProUser are internally consistent.
//

import Foundation
import Testing
@testable import rawctl

struct AppFeaturesProGatingTests {

    // MARK: - Free tier

    /// AI Culling must never require a Pro subscription.
    @Test func aiCullingIsAlwaysEnabled() {
        #expect(AppFeatures.aiCullingEnabled == true)
    }

    // MARK: - Pro tier consistency

    /// smartSyncEnabled must equal isProUser — no tighter, no looser.
    @Test @MainActor func smartSyncEnabledMatchesIsProUser() {
        #expect(AppFeatures.smartSyncEnabled == AppFeatures.isProUser)
    }

    /// aiMaskingEnabled must equal isProUser — no tighter, no looser.
    @Test @MainActor func aiMaskingEnabledMatchesIsProUser() {
        #expect(AppFeatures.aiMaskingEnabled == AppFeatures.isProUser)
    }

    /// Both Pro features must be in lockstep — if one gates, both gate.
    @Test @MainActor func proFeaturesAreInLockstep() {
        #expect(AppFeatures.smartSyncEnabled == AppFeatures.aiMaskingEnabled)
    }

    // MARK: - Unauthenticated / default environment

    /// In a stock test environment (no Keychain tokens, no Pro override env var),
    /// no user is authenticated and isProUser must be false.
    @Test @MainActor func isProUserIsFalseWithNoAuthAndNoOverride() {
        // Guard: if LATENT_PRO_OVERRIDE or RAWCTL_PRO_OVERRIDE is set in the test
        // scheme, this test cannot make assertions about the unauthenticated default.
        let env = ProcessInfo.processInfo.environment
        let hasOverride = env["LATENT_PRO_OVERRIDE"] != nil || env["RAWCTL_PRO_OVERRIDE"] != nil
        guard !hasOverride else { return }

        // AccountService.shared has no tokens in a fresh test run.
        let isAuthenticated = AccountService.shared.isAuthenticated
        if !isAuthenticated {
            #expect(AppFeatures.isProUser == false)
        }
    }

    /// In the same unauthenticated environment, Pro AI features must be disabled.
    @Test @MainActor func proAIFeaturesAreOffWhenNotAuthenticated() {
        let env = ProcessInfo.processInfo.environment
        let hasOverride = env["LATENT_PRO_OVERRIDE"] != nil || env["RAWCTL_PRO_OVERRIDE"] != nil
        guard !hasOverride else { return }

        if !AccountService.shared.isAuthenticated {
            #expect(AppFeatures.smartSyncEnabled == false)
            #expect(AppFeatures.aiMaskingEnabled == false)
        }
    }
}
