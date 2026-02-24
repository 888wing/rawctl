//
//  AccountServiceIsProUserTests.swift
//  rawctlTests
//
//  Unit tests for AccountService.isProUser.
//
//  Strategy: create isolated AccountService instances (not the shared singleton),
//  inject synthetic CreditsBalance values, and assert the plan-string matching
//  logic for all relevant tier names and edge cases.
//
//  AccountService is @MainActor, so all tests are marked @MainActor.
//

import Foundation
import Testing
@testable import Latent

@MainActor
struct AccountServiceIsProUserTests {

    // MARK: - Unauthenticated guard

    @Test func notAuthenticatedIsNeverPro() {
        let svc = AccountService()
        svc.isAuthenticated = false
        svc.creditsBalance  = makeBalance(plan: "pro")
        #expect(svc.isProUser == false)
    }

    @Test func nilBalanceIsNotPro() {
        let svc = AccountService()
        svc.isAuthenticated = true
        svc.creditsBalance  = nil
        #expect(svc.isProUser == false)
    }

    @Test func notAuthenticatedWithNilBalanceIsNotPro() {
        let svc = AccountService()
        svc.isAuthenticated = false
        svc.creditsBalance  = nil
        #expect(svc.isProUser == false)
    }

    // MARK: - Free plan

    @Test func freePlanIsNotPro() {
        let svc = AccountService()
        svc.isAuthenticated = true
        svc.creditsBalance  = makeBalance(plan: "free")
        #expect(svc.isProUser == false)
    }

    @Test func emptyPlanStringIsNotPro() {
        let svc = AccountService()
        svc.isAuthenticated = true
        svc.creditsBalance  = makeBalance(plan: "")
        #expect(svc.isProUser == false)
    }

    @Test func unknownPlanIsNotPro() {
        let svc = AccountService()
        svc.isAuthenticated = true
        svc.creditsBalance  = makeBalance(plan: "starter")
        #expect(svc.isProUser == false)
    }

    // MARK: - Pro plan (substring match)

    @Test func proPlanIsPro() {
        let svc = AccountService()
        svc.isAuthenticated = true
        svc.creditsBalance  = makeBalance(plan: "pro")
        #expect(svc.isProUser == true)
    }

    @Test func proMonthlyPlanIsPro() {
        let svc = AccountService()
        svc.isAuthenticated = true
        svc.creditsBalance  = makeBalance(plan: "pro_monthly")
        #expect(svc.isProUser == true)
    }

    @Test func proPlanNameIsCaseInsensitive() {
        for variant in ["Pro", "PRO", "PrO"] {
            let svc = AccountService()
            svc.isAuthenticated = true
            svc.creditsBalance  = makeBalance(plan: variant)
            #expect(svc.isProUser == true, "Expected '\(variant)' to be recognised as Pro")
        }
    }

    // MARK: - Premium plan

    @Test func premiumPlanIsPro() {
        let svc = AccountService()
        svc.isAuthenticated = true
        svc.creditsBalance  = makeBalance(plan: "premium")
        #expect(svc.isProUser == true)
    }

    @Test func premiumPlanNameIsCaseInsensitive() {
        let svc = AccountService()
        svc.isAuthenticated = true
        svc.creditsBalance  = makeBalance(plan: "PREMIUM")
        #expect(svc.isProUser == true)
    }

    // MARK: - Yearly plan

    @Test func yearlyPlanIsPro() {
        let svc = AccountService()
        svc.isAuthenticated = true
        svc.creditsBalance  = makeBalance(plan: "yearly")
        #expect(svc.isProUser == true)
    }

    @Test func yearlyPlanNameIsCaseInsensitive() {
        let svc = AccountService()
        svc.isAuthenticated = true
        svc.creditsBalance  = makeBalance(plan: "YEARLY")
        #expect(svc.isProUser == true)
    }

    @Test func proYearlyCompoundNameIsPro() {
        let svc = AccountService()
        svc.isAuthenticated = true
        svc.creditsBalance  = makeBalance(plan: "pro_yearly")
        #expect(svc.isProUser == true)
    }

    // MARK: - Helpers

    private func makeBalance(plan: String) -> CreditsBalance {
        CreditsBalance(
            subscription: SubscriptionCredits(
                plan:       plan,
                total:      1000,
                used:       0,
                remaining:  1000,
                resetsAt:   nil
            ),
            purchased: PurchasedCredits(total: 0, remaining: 0),
            totalRemaining: 1000
        )
    }
}
