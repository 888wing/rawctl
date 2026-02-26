//
//  AppDistribution.swift
//  rawctl
//
//  Compile-time distribution channel switches and policy helpers.
//

import Foundation

enum AppDistributionChannel: String, Codable {
    case direct
    case mas

    static var current: AppDistributionChannel {
        #if DISTRIBUTION_CHANNEL_MAS
        return .mas
        #else
        return .direct
        #endif
    }

    var usesStoreKitBilling: Bool {
        self == .mas
    }

    var supportsSparkleUpdates: Bool {
        self == .direct
    }

    var allowsExternalCheckout: Bool {
        self == .direct
    }

    var displayName: String {
        switch self {
        case .direct: return "Latent Direct"
        case .mas: return "Latent (Mac App Store)"
        }
    }
}

enum AppLegalLinks {
    static let privacyPolicy = URL(string: "https://latent-app.com/privacy")!
    static let termsOfService = URL(string: "https://latent-app.com/terms")!
    static let support = URL(string: "https://latent-app.com/support") ?? URL(string: "https://latent-app.com")!
}
