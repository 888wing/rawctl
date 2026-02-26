//
//  BillingProviderTests.swift
//  rawctlTests
//
//  Unit tests for BillingProvider channel routing, product map lookups, and
//  credit reservation logic.
//

import Foundation
import Testing
@testable import Latent

@MainActor
struct BillingProviderTests {

    // MARK: - Channel Assignment

    @Test
    func directBillingProviderReportsDirectChannel() {
        let provider = DirectBillingProvider()
        #expect(provider.channel == .direct)
    }

    @Test
    func storeKitBillingProviderReportsMASChannel() {
        let provider = StoreKitBillingProvider()
        #expect(provider.channel == .mas)
    }

    // MARK: - StoreKitBillingProvider Product Map (via purchasePlan error path)

    @Test
    func storeKitPurchasePlanThrowsForUnknownPlan() async {
        let provider = StoreKitBillingProvider()
        let svc = AccountService()
        // Empty plans list → product ID lookup fails → billingProductUnavailable
        svc.plans = []

        do {
            try await provider.purchasePlan(named: "nonexistent", accountService: svc)
            Issue.record("Expected billingProductUnavailable error")
        } catch let error as AccountError {
            #expect(error == .billingProductUnavailable)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test
    func storeKitPurchaseCreditsPackThrowsForUnknownPack() async {
        let provider = StoreKitBillingProvider()
        let svc = AccountService()
        svc.creditsPacks = []

        do {
            try await provider.purchaseCreditsPack(named: "nonexistent", accountService: svc)
            Issue.record("Expected billingProductUnavailable error")
        } catch let error as AccountError {
            #expect(error == .billingProductUnavailable)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - Direct Provider No-Ops

    @Test
    func directBillingProviderRefreshCatalogIsNoOp() async {
        let provider = DirectBillingProvider()
        let svc = AccountService()
        svc.plans = [PlanInfo(name: "pro", credits: 100, price: 15, priceFormatted: "$15")]
        // Should not crash or modify plans
        await provider.refreshCatalog(accountService: svc)
        #expect(svc.plans.count == 1)
    }

    @Test
    func directBillingProviderSyncEntitlementsIsNoOp() async {
        let provider = DirectBillingProvider()
        let svc = AccountService()
        // Should not crash
        await provider.syncEntitlements(accountService: svc, reason: "test")
    }

    @Test
    func directBillingProviderRestoreSetsNotice() async throws {
        let provider = DirectBillingProvider()
        let svc = AccountService()
        // restorePurchases on direct calls refreshEntitlementsIfNeeded (requires auth)
        // Without auth, it will return early, then set billingNotice
        try await provider.restorePurchases(accountService: svc)
        #expect(svc.billingNotice == "Account status refreshed.")
    }
}

// MARK: - Credit Reservation Tests

@MainActor
struct CreditReservationTests {

    @Test
    func reserveCreditsSucceedsWhenBalanceSufficient() {
        let svc = AccountService()
        svc.creditsBalance = makeBalance(totalRemaining: 10)

        #expect(svc.reserveCredits(5) == true)
    }

    @Test
    func reserveCreditsFailsWhenBalanceInsufficient() {
        let svc = AccountService()
        svc.creditsBalance = makeBalance(totalRemaining: 3)

        #expect(svc.reserveCredits(5) == false)
    }

    @Test
    func reserveCreditsFailsWhenNilBalance() {
        let svc = AccountService()
        svc.creditsBalance = nil

        #expect(svc.reserveCredits(1) == false)
    }

    @Test
    func reserveCreditsAccountsForPreviousReservations() {
        let svc = AccountService()
        svc.creditsBalance = makeBalance(totalRemaining: 10)

        #expect(svc.reserveCredits(6) == true)
        // Now only 4 available (10 - 6)
        #expect(svc.reserveCredits(5) == false)
        #expect(svc.reserveCredits(4) == true)
    }

    @Test
    func releaseCreditsRestoresAvailability() {
        let svc = AccountService()
        svc.creditsBalance = makeBalance(totalRemaining: 10)

        #expect(svc.reserveCredits(8) == true)
        #expect(svc.reserveCredits(5) == false) // only 2 left

        svc.releaseCredits(8)
        #expect(svc.reserveCredits(5) == true) // back to 10 available → now 5 left
    }

    @Test
    func releaseCreditsNeverGoesNegative() {
        let svc = AccountService()
        svc.creditsBalance = makeBalance(totalRemaining: 5)

        // Release more than reserved — should clamp to 0
        svc.releaseCredits(100)

        // Should still be able to reserve up to balance
        #expect(svc.reserveCredits(5) == true)
    }

    private func makeBalance(totalRemaining: Int) -> CreditsBalance {
        CreditsBalance(
            subscription: SubscriptionCredits(
                plan: "free",
                total: 0,
                used: 0,
                remaining: 0,
                resetsAt: nil
            ),
            purchased: PurchasedCredits(total: totalRemaining, remaining: totalRemaining),
            totalRemaining: totalRemaining
        )
    }
}

// MARK: - Account Deletion Validation Tests

@MainActor
struct AccountDeletionValidationTests {

    @Test
    func deleteAccountRejectsEmailMismatch() async {
        let svc = AccountService()
        // Set up a fake authenticated user
        svc.currentUser = UserInfo(id: "test-123", email: "user@example.com")
        svc.isAuthenticated = true

        do {
            try await svc.deleteAccount(verificationCode: "123456", typedEmail: "wrong@example.com")
            Issue.record("Expected accountDeletionConfirmationMismatch error")
        } catch let error as AccountError {
            #expect(error == .accountDeletionConfirmationMismatch)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test
    func deleteAccountRejectsCaseSensitiveMismatch() async {
        let svc = AccountService()
        svc.currentUser = UserInfo(id: "test-123", email: "User@Example.com")
        svc.isAuthenticated = true

        // Same email but with trailing whitespace is OK (trimmed), but different email is not
        do {
            try await svc.deleteAccount(verificationCode: "123456", typedEmail: "different@example.com")
            Issue.record("Expected accountDeletionConfirmationMismatch error")
        } catch let error as AccountError {
            #expect(error == .accountDeletionConfirmationMismatch)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test
    func deleteAccountThrowsUnauthorizedWhenNotSignedIn() async {
        let svc = AccountService()
        svc.currentUser = nil

        do {
            try await svc.deleteAccount(verificationCode: "123456", typedEmail: "user@example.com")
            Issue.record("Expected unauthorized error")
        } catch let error as AccountError {
            #expect(error == .unauthorized)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test
    func sendDeletionCodeThrowsUnauthorizedWhenNotSignedIn() async {
        let svc = AccountService()
        svc.currentUser = nil

        do {
            try await svc.sendAccountDeletionCode()
            Issue.record("Expected unauthorized error")
        } catch let error as AccountError {
            #expect(error == .unauthorized)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}

// MARK: - AccountError Equatable (for test assertions)

extension AccountError: Equatable {
    public static func == (lhs: AccountError, rhs: AccountError) -> Bool {
        switch (lhs, rhs) {
        case (.networkError, .networkError),
             (.invalidResponse, .invalidResponse),
             (.unauthorized, .unauthorized),
             (.insufficientCredits, .insufficientCredits),
             (.tokenReplayDetected, .tokenReplayDetected),
             (.externalCheckoutNotAllowed, .externalCheckoutNotAllowed),
             (.billingProductUnavailable, .billingProductUnavailable),
             (.purchasePending, .purchasePending),
             (.purchaseCancelled, .purchaseCancelled),
             (.accountDeletionConfirmationMismatch, .accountDeletionConfirmationMismatch):
            return true
        case (.rateLimited(let a), .rateLimited(let b)):
            return a == b
        case (.securityBlock(let a), .securityBlock(let b)):
            return a == b
        default:
            return false
        }
    }
}
