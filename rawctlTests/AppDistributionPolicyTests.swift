//
//  AppDistributionPolicyTests.swift
//  rawctlTests
//
//  Verifies distribution-channel policy invariants used by billing/update routing.
//

import Testing
@testable import Latent

struct AppDistributionPolicyTests {

    @Test
    func directChannelPoliciesAreSelfConsistent() {
        let channel = AppDistributionChannel.direct
        #expect(channel.usesStoreKitBilling == false)
        #expect(channel.supportsSparkleUpdates == true)
        #expect(channel.allowsExternalCheckout == true)
    }

    @Test
    func masChannelPoliciesAreSelfConsistent() {
        let channel = AppDistributionChannel.mas
        #expect(channel.usesStoreKitBilling == true)
        #expect(channel.supportsSparkleUpdates == false)
        #expect(channel.allowsExternalCheckout == false)
    }

    @Test
    func pricingModelsSupportOptionalStoreKitIdentifiers() {
        let plan = PlanInfo(name: "pro_monthly", credits: 0, price: 15, priceFormatted: "$15")
        let pack = CreditPackInfo(name: "credits_100", credits: 100, price: 4.99, priceFormatted: "$4.99")
        #expect(plan.storeKitProductId == nil)
        #expect(pack.storeKitProductId == nil)
    }
}
