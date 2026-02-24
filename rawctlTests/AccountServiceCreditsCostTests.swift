//
//  AccountServiceCreditsCostTests.swift
//  rawctlTests
//
//  Unit tests for AccountService.hasEnoughCredits(for:)
//

import Foundation
import Testing
@testable import Latent

@MainActor
struct AccountServiceCreditsCostTests {

    @Test func recognizesNanoBananaResolutionOperationKeys() {
        let svc = AccountService()
        svc.creditsBalance = makeBalance(totalRemaining: 3)

        #expect(svc.hasEnoughCredits(for: "nano_banana_1k") == true)
        #expect(svc.hasEnoughCredits(for: "nano_banana_2k") == true)
        #expect(svc.hasEnoughCredits(for: "nano_banana_pro_2k") == true)
        #expect(svc.hasEnoughCredits(for: "nano_banana_4k") == false)
        #expect(svc.hasEnoughCredits(for: "nano_banana_pro_4k") == false)
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
