//
//  AppFeaturesProGatingTests.swift
//  rawctlTests
//
//  Tests that verify the tier-gating contract in AppFeatures:
//   - AI Culling, Smart Sync, AI Masking, and Batch Processing gate behind isProUser.
//   - all Pro flags and isProUser are internally consistent.
//

import Foundation
import Testing
@testable import Latent

struct AppFeaturesProGatingTests {

    // MARK: - Pro tier consistency

    /// aiCullingEnabled must equal isProUser — no tighter, no looser.
    @Test @MainActor func aiCullingEnabledMatchesIsProUser() {
        #expect(AppFeatures.aiCullingEnabled == AppFeatures.isProUser)
    }

    /// smartSyncEnabled must equal isProUser — no tighter, no looser.
    @Test @MainActor func smartSyncEnabledMatchesIsProUser() {
        #expect(AppFeatures.smartSyncEnabled == AppFeatures.isProUser)
    }

    /// aiMaskingEnabled must equal isProUser — no tighter, no looser.
    @Test @MainActor func aiMaskingEnabledMatchesIsProUser() {
        #expect(AppFeatures.aiMaskingEnabled == AppFeatures.isProUser)
    }

    /// batchProcessingEnabled must equal isProUser — no tighter, no looser.
    @Test @MainActor func batchProcessingEnabledMatchesIsProUser() {
        #expect(AppFeatures.batchProcessingEnabled == AppFeatures.isProUser)
    }

    /// All Pro features must be in lockstep.
    @Test @MainActor func proFeaturesAreInLockstep() {
        #expect(AppFeatures.aiCullingEnabled == AppFeatures.smartSyncEnabled)
        #expect(AppFeatures.smartSyncEnabled == AppFeatures.aiMaskingEnabled)
        #expect(AppFeatures.aiMaskingEnabled == AppFeatures.batchProcessingEnabled)
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
            #expect(AppFeatures.aiCullingEnabled == false)
            #expect(AppFeatures.smartSyncEnabled == false)
            #expect(AppFeatures.aiMaskingEnabled == false)
            #expect(AppFeatures.batchProcessingEnabled == false)
        }
    }
}
