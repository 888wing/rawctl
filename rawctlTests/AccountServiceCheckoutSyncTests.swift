//
//  AccountServiceCheckoutSyncTests.swift
//  rawctlTests
//
//  Unit tests for checkout return URL classification and entitlement diffing.
//

import Foundation
import Testing
@testable import Latent

@MainActor
struct AccountServiceCheckoutSyncTests {

    @Test func billingReturnUrlByHostIsRecognized() {
        let url = URL(string: "latent://billing-return?source=checkout")!
        #expect(AccountService.isBillingReturnURL(url) == true)
    }

    @Test func billingReturnUrlByPathIsRecognized() {
        let url = URL(string: "latent-app://return/checkout-complete")!
        #expect(AccountService.isBillingReturnURL(url) == true)
    }

    @Test func billingReturnUrlByQuerySourceIsRecognized() {
        let url = URL(string: "latent://return?source=billing_portal")!
        #expect(AccountService.isBillingReturnURL(url) == true)
    }

    @Test func nonLatentSchemeIsIgnored() {
        let url = URL(string: "https://latent-app.com/billing-return")!
        #expect(AccountService.isBillingReturnURL(url) == false)
    }

    @Test func unrelatedLatentDeepLinkIsIgnored() {
        let url = URL(string: "latent://open-library")!
        #expect(AccountService.isBillingReturnURL(url) == false)
    }

    @Test func entitlementDiffNilToNilIsUnchanged() {
        #expect(AccountService.entitlementsChanged(from: nil, to: nil) == false)
    }

    @Test func entitlementDiffNilToValueIsChanged() {
        #expect(AccountService.entitlementsChanged(from: nil, to: makeBalance(plan: "free", totalRemaining: 100)) == true)
    }

    @Test func entitlementDiffPlanChangeIsDetected() {
        let oldValue = makeBalance(plan: "free", totalRemaining: 100)
        let newValue = makeBalance(plan: "pro_monthly", totalRemaining: 100)
        #expect(AccountService.entitlementsChanged(from: oldValue, to: newValue) == true)
    }

    @Test func entitlementDiffRemainingCreditsChangeIsDetected() {
        let oldValue = makeBalance(plan: "pro_monthly", totalRemaining: 100, used: 0, subscriptionRemaining: 100)
        let newValue = makeBalance(plan: "pro_monthly", totalRemaining: 98, used: 2, subscriptionRemaining: 98)
        #expect(AccountService.entitlementsChanged(from: oldValue, to: newValue) == true)
    }

    @Test func entitlementDiffSameSnapshotIsUnchanged() {
        let snapshot = makeBalance(plan: "pro_monthly", totalRemaining: 100)
        #expect(AccountService.entitlementsChanged(from: snapshot, to: snapshot) == false)
    }

    private func makeBalance(
        plan: String,
        totalRemaining: Int,
        used: Int = 0,
        subscriptionRemaining: Int = 100
    ) -> CreditsBalance {
        CreditsBalance(
            subscription: SubscriptionCredits(
                plan: plan,
                total: 100,
                used: used,
                remaining: subscriptionRemaining,
                resetsAt: nil
            ),
            purchased: PurchasedCredits(total: totalRemaining, remaining: totalRemaining),
            totalRemaining: totalRemaining
        )
    }
}
