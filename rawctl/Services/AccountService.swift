//
//  AccountService.swift
//  rawctl
//
//  Service for account management and API communication
//

import Foundation
import AuthenticationServices
import AppKit
import StoreKit

// MARK: - API Response Types

struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let error: APIError?
}

struct APIError: Codable {
    let code: String
    let message: String
}

struct AuthResponse: Codable {
    let user: UserInfo
    let accessToken: String
    let refreshToken: String
}

/// Response from `/auth/refresh` — does NOT include `user`.
struct RefreshTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
}

struct UserInfo: Codable {
    let id: String
    let email: String
}

struct CreditsBalance: Codable {
    let subscription: SubscriptionCredits
    let purchased: PurchasedCredits
    let totalRemaining: Int
}

struct SubscriptionCredits: Codable {
    let plan: String
    let total: Int
    let used: Int
    let remaining: Int
    let resetsAt: Int?
}

struct PurchasedCredits: Codable {
    let total: Int
    let remaining: Int
}

struct CheckoutResponse: Codable {
    let url: String
}

struct PlansResponse: Codable {
    let plans: [PlanInfo]
    let creditsPacks: [CreditPackInfo]
}

struct PlanInfo: Codable, Identifiable {
    let name: String
    let credits: Int
    let price: Double
    let priceFormatted: String
    let storeKitProductId: String?

    init(
        name: String,
        credits: Int,
        price: Double,
        priceFormatted: String,
        storeKitProductId: String? = nil
    ) {
        self.name = name
        self.credits = credits
        self.price = price
        self.priceFormatted = priceFormatted
        self.storeKitProductId = storeKitProductId
    }
    
    var id: String { name }
}

struct CreditPackInfo: Codable, Identifiable {
    let name: String
    let credits: Int
    let price: Double
    let priceFormatted: String
    let storeKitProductId: String?

    init(
        name: String,
        credits: Int,
        price: Double,
        priceFormatted: String,
        storeKitProductId: String? = nil
    ) {
        self.name = name
        self.credits = credits
        self.price = price
        self.priceFormatted = priceFormatted
        self.storeKitProductId = storeKitProductId
    }
    
    var id: String { name }
}

// MARK: - AccountService

@MainActor
final class AccountService: ObservableObject {
    static let shared = AccountService()
    
    // API Configuration - Always use production API
    private let baseURL = "https://api.latent-app.com"
    
    // Published state
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var currentUser: UserInfo?
    @Published var creditsBalance: CreditsBalance?
    @Published var plans: [PlanInfo] = []
    @Published var creditsPacks: [CreditPackInfo] = []
    @Published var errorMessage: String?
    @Published var userStyleProfile: UserStyleProfile?
    @Published var billingNotice: String?

    // Entitlement sync control (used after browser-based checkout returns)
    private var lastEntitlementRefreshAt: Date?
    private var checkoutSyncTask: Task<Void, Never>?
    private static let entitlementRefreshThrottleSeconds: TimeInterval = 8
    private static let checkoutSyncWindowSeconds: TimeInterval = 180
    
    // Guard against recursive refresh attempts
    private var isRefreshingToken = false
    // Local credit reservation for in-flight AI operations
    private var reservedCredits: Int = 0
    private let cachedCreditsBalanceKey = "rawctl_cached_credits_balance_v1"
    private lazy var billingProvider: any BillingProvider = {
        if AppDistributionChannel.current.usesStoreKitBilling {
            return StoreKitBillingProvider()
        }
        return DirectBillingProvider()
    }()

    // Token storage
    private var accessToken: String? {
        get { KeychainHelper.get(key: "rawctl_access_token") }
        set {
            if let value = newValue {
                KeychainHelper.set(key: "rawctl_access_token", value: value)
            } else {
                KeychainHelper.delete(key: "rawctl_access_token")
            }
        }
    }
    
    private var refreshToken: String? {
        get { KeychainHelper.get(key: "rawctl_refresh_token") }
        set {
            if let value = newValue {
                KeychainHelper.set(key: "rawctl_refresh_token", value: value)
            } else {
                KeychainHelper.delete(key: "rawctl_refresh_token")
            }
        }
    }
    
    init() {
        restoreCachedCreditsBalance()

        // Check if we have tokens on launch
        if accessToken != nil {
            isAuthenticated = true
            Task {
                await loadUserData()
            }
        }
    }
    
    // MARK: - Authentication
    
    /// Send magic link to email
    func sendMagicLink(email: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        let _: APIResponse<EmptyResponse> = try await post(
            endpoint: "/auth/magic-link",
            body: ["email": email]
        )
    }
    
    /// Verify magic link code
    func verifyMagicLink(email: String, code: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        let response: APIResponse<AuthResponse> = try await post(
            endpoint: "/auth/verify",
            body: ["email": email, "code": code]
        )
        
        guard let data = response.data else {
            throw AccountError.invalidResponse
        }
        
        accessToken = data.accessToken
        refreshToken = data.refreshToken
        currentUser = data.user
        isAuthenticated = true
        
        await postAuthenticationBootstrap()
    }
    
    /// Sign in with Google
    func signInWithGoogle(idToken: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        let response: APIResponse<AuthResponse> = try await post(
            endpoint: "/auth/oauth/google",
            body: ["idToken": idToken]
        )
        
        guard let data = response.data else {
            throw AccountError.invalidResponse
        }
        
        accessToken = data.accessToken
        refreshToken = data.refreshToken
        currentUser = data.user
        isAuthenticated = true
        
        await postAuthenticationBootstrap()
    }
    
    /// Sign in with Apple
    func signInWithApple(identityToken: String, email: String?) async throws {
        isLoading = true
        defer { isLoading = false }
        
        var body: [String: Any] = ["identityToken": identityToken]
        if let email = email {
            body["email"] = email
        }
        
        let response: APIResponse<AuthResponse> = try await post(
            endpoint: "/auth/oauth/apple",
            body: body
        )
        
        guard let data = response.data else {
            throw AccountError.invalidResponse
        }
        
        accessToken = data.accessToken
        refreshToken = data.refreshToken
        currentUser = data.user
        isAuthenticated = true
        
        await postAuthenticationBootstrap()
    }
    
    /// Sign out
    func signOut() {
        checkoutSyncTask?.cancel()
        checkoutSyncTask = nil
        lastEntitlementRefreshAt = nil
        accessToken = nil
        refreshToken = nil
        currentUser = nil
        creditsBalance = nil
        billingNotice = nil
        isAuthenticated = false
    }

    private func postAuthenticationBootstrap() async {
        if AppDistributionChannel.current.usesStoreKitBilling {
            await billingProvider.syncEntitlements(accountService: self, reason: "post_auth")
        }
        await loadCreditsBalance()
        await loadPlans()
    }
    
    // MARK: - User Data

    func loadUserData() async {
        await loadUserProfile()
        await loadCreditsBalance()
        await loadPlans()
    }

    func loadUserProfile() async {
        guard isAuthenticated else { return }

        do {
            let response: APIResponse<UserInfo> = try await get(endpoint: "/user/me")
            if let user = response.data {
                currentUser = user
            } else {
                // User not found or token invalid, sign out
                print("[AccountService] Failed to load user profile: no data")
                signOut()
            }
        } catch AccountError.unauthorized {
            // Token expired and refresh failed, sign out
            print("[AccountService] Unauthorized, signing out")
            signOut()
        } catch {
            print("[AccountService] Failed to load user profile: \(error)")
            // Don't sign out on network errors, user might be offline
        }
    }

    /// Reserve credits locally before API call. Returns false if insufficient.
    func reserveCredits(_ amount: Int) -> Bool {
        let available = (creditsBalance?.totalRemaining ?? 0) - reservedCredits
        guard available >= amount else { return false }
        reservedCredits += amount
        return true
    }

    /// Release reserved credits (called after API response or on failure).
    func releaseCredits(_ amount: Int) {
        reservedCredits = max(0, reservedCredits - amount)
    }

    func loadCreditsBalance() async {
        guard isAuthenticated else { return }

        do {
            let response: APIResponse<CreditsBalance> = try await get(endpoint: "/user/credits")
            if let balance = response.data {
                creditsBalance = balance
                cacheCreditsBalance(balance)
                lastEntitlementRefreshAt = Date()
            }
        } catch AccountError.unauthorized {
            // Token expired and refresh failed, sign out
            print("[AccountService] Unauthorized loading credits, signing out")
            signOut()
        } catch {
            print("[AccountService] Failed to load credits: \(error)")
            // Keep last known entitlements for offline use.
            restoreCachedCreditsBalance()
        }
    }
    
    func loadPlans() async {
        do {
            let response: APIResponse<PlansResponse> = try await get(endpoint: "/checkout/plans", authenticated: false)
            if let data = response.data {
                plans = data.plans
                creditsPacks = data.creditsPacks
            } else {
                applyFallbackPlansIfNeeded()
            }
        } catch {
            print("[AccountService] Failed to load plans: \(error)")
            // Plans are public data, don't sign out on failure.
            // Keep a deterministic fallback so pricing UI is never empty.
            applyFallbackPlansIfNeeded()
        }

        await billingProvider.refreshCatalog(accountService: self)
    }
    
    // MARK: - Checkout

    /// Channel-aware entrypoint for plan purchase.
    func purchasePlan(named plan: String) async throws {
        try await billingProvider.purchasePlan(named: plan, accountService: self)
    }

    /// Channel-aware entrypoint for one-off credits purchase.
    func purchaseCreditsPack(named pack: String) async throws {
        try await billingProvider.purchaseCreditsPack(named: pack, accountService: self)
    }

    /// Channel-aware "manage billing" action.
    func openBillingPortal() async throws {
        try await billingProvider.openManageSubscription(accountService: self)
    }

    /// MAS restore purchases entrypoint.
    func restorePurchases() async throws {
        try await billingProvider.restorePurchases(accountService: self)
    }
    
    /// Create subscription checkout and open in browser
    func createSubscriptionCheckout(plan: String) async throws {
        guard AppDistributionChannel.current.allowsExternalCheckout else {
            throw AccountError.externalCheckoutNotAllowed
        }

        isLoading = true
        defer { isLoading = false }
        
        let response: APIResponse<CheckoutResponse> = try await post(
            endpoint: "/checkout/subscription",
            body: ["plan": plan],
            authenticated: true
        )
        
        guard let data = response.data, let url = URL(string: data.url) else {
            throw AccountError.invalidResponse
        }

        NSWorkspace.shared.open(url)
        startCheckoutSyncWindow(reason: "subscription_checkout_opened")
    }
    
    /// Create credits pack checkout and open in browser
    func createCreditsCheckout(pack: String) async throws {
        guard AppDistributionChannel.current.allowsExternalCheckout else {
            throw AccountError.externalCheckoutNotAllowed
        }

        isLoading = true
        defer { isLoading = false }
        
        let response: APIResponse<CheckoutResponse> = try await post(
            endpoint: "/checkout/credits",
            body: ["pack": pack],
            authenticated: true
        )
        
        guard let data = response.data, let url = URL(string: data.url) else {
            throw AccountError.invalidResponse
        }

        NSWorkspace.shared.open(url)
        startCheckoutSyncWindow(reason: "credits_checkout_opened")
    }
    
    /// Direct-channel billing portal.
    func openDirectBillingPortal() async throws {
        guard AppDistributionChannel.current.allowsExternalCheckout else {
            throw AccountError.externalCheckoutNotAllowed
        }

        isLoading = true
        defer { isLoading = false }
        
        let response: APIResponse<CheckoutResponse> = try await post(
            endpoint: "/billing/portal",
            body: [:],
            authenticated: true
        )
        
        guard let data = response.data, let url = URL(string: data.url) else {
            throw AccountError.invalidResponse
        }

        NSWorkspace.shared.open(url)
        startCheckoutSyncWindow(reason: "billing_portal_opened")
    }

    /// Refresh entitlements when app returns to foreground.
    /// This keeps web/browser checkout and app-side Pro/credits state aligned.
    func refreshEntitlementsIfNeeded(force: Bool = false, reason: String) async {
        guard isAuthenticated else { return }

        if !force,
           let last = lastEntitlementRefreshAt,
           Date().timeIntervalSince(last) < Self.entitlementRefreshThrottleSeconds {
            return
        }

        if AppDistributionChannel.current.usesStoreKitBilling {
            await billingProvider.syncEntitlements(accountService: self, reason: reason)
        }

        lastEntitlementRefreshAt = Date()
        await loadCreditsBalance()
    }

    /// Handle app deep links for post-checkout return URLs.
    func handleIncomingURL(_ url: URL) async {
        guard Self.isBillingReturnURL(url) else { return }
        await refreshEntitlementsIfNeeded(force: true, reason: "billing_return_url")
        startCheckoutSyncWindow(reason: "billing_return_url")
    }

    static func isBillingReturnURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "latent" || scheme == "latent-app" else {
            return false
        }

        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased()
        if host.contains("billing") || host.contains("checkout") {
            return true
        }
        if path.contains("billing") || path.contains("checkout") {
            return true
        }

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let source = components.queryItems?.first(where: { $0.name.lowercased() == "source" })?.value?.lowercased(),
           source.contains("billing") || source.contains("checkout") {
            return true
        }

        return false
    }

    // MARK: - Account Deletion

    /// Sends a short-lived re-auth code to the signed-in email before destructive delete.
    func sendAccountDeletionCode() async throws {
        guard let email = currentUser?.email else {
            throw AccountError.unauthorized
        }

        isLoading = true
        defer { isLoading = false }

        let _: APIResponse<EmptyResponse> = try await post(
            endpoint: "/auth/magic-link",
            body: [
                "email": email,
                "purpose": "account_deletion"
            ],
            authenticated: true
        )
    }

    /// Permanently deletes account after in-app re-auth + explicit confirmation.
    func deleteAccount(verificationCode: String, typedEmail: String) async throws {
        guard let currentEmail = currentUser?.email else {
            throw AccountError.unauthorized
        }

        guard typedEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == currentEmail.lowercased() else {
            throw AccountError.accountDeletionConfirmationMismatch
        }

        isLoading = true
        defer { isLoading = false }

        let payload: [String: Any] = [
            "email": currentEmail,
            "code": verificationCode,
            "confirmDelete": true
        ]

        do {
            let _: APIResponse<EmptyResponse> = try await post(
                endpoint: "/user/delete",
                body: payload,
                authenticated: true
            )
        } catch {
            // Backward compatibility for older backend routes.
            let _: APIResponse<EmptyResponse> = try await post(
                endpoint: "/user/account/delete",
                body: payload,
                authenticated: true
            )
        }

        UserDefaults.standard.set(
            Date().timeIntervalSince1970,
            forKey: "rawctl_account_deletion_requested_at"
        )
        signOut()
    }

    // MARK: - StoreKit Verification Bridge

    /// Sends signed App Store transaction payloads to backend for server-side verification.
    func syncStoreKitTransactionsWithBackend(
        signedTransactions: [String],
        reason: String
    ) async throws {
        guard isAuthenticated else { return }
        guard !signedTransactions.isEmpty else { return }

        let _: APIResponse<EmptyResponse> = try await post(
            endpoint: "/billing/app-store/sync",
            body: [
                "channel": "mas",
                "reason": reason,
                "transactions": signedTransactions
            ],
            authenticated: true
        )
    }
    
    // MARK: - Pro Subscription

    /// True if the current user's subscription plan includes Pro AI features.
    ///
    /// Checks the `subscription.plan` field returned by `/user/credits`.
    /// Non-authenticated and free-tier users both return `false`.
    var isProUser: Bool {
        guard isAuthenticated, let balance = creditsBalance else { return false }
        let plan = balance.subscription.plan.lowercased()
        return plan.contains("pro") || plan.contains("premium") || plan.contains("yearly")
    }

    // MARK: - AI Operations

    /// Check if user has enough credits
    func hasEnoughCredits(for operation: String) -> Bool {
        guard let balance = creditsBalance else { return false }
        
        let cost: Int
        switch operation {
        case "nano_banana_1k": cost = 1
        case "nano_banana_2k", "nano_banana_pro_2k": cost = 3
        case "nano_banana_4k", "nano_banana_pro_4k": cost = 6
        default: cost = 1
        }
        
        return balance.totalRemaining >= cost
    }
    
    /// Record that the user modified an AI colour-grading suggestion before saving.
    /// Posts a fire-and-forget preference update to the backend.
    /// Requires at least 5 samples before the backend starts influencing future AI suggestions.
    func recordStylePreference(
        originalSuggestion: ColorGradeDelta,
        userModification: ColorGradeDelta,
        mode: String,
        mood: String? = nil
    ) {
        guard isAuthenticated else { return }
        Task {
            let body: [String: Any] = [
                "mode": mode,
                "mood": mood as Any,
                "originalSuggestion": (try? JSONEncoder().encode(originalSuggestion))
                    .flatMap { try? JSONSerialization.jsonObject(with: $0) } as Any,
                "userModification": (try? JSONEncoder().encode(userModification))
                    .flatMap { try? JSONSerialization.jsonObject(with: $0) } as Any
            ]
            let _: APIResponse<EmptyResponse> = (try? await post(
                endpoint: "/ai/style-preference",
                body: body,
                authenticated: true
            )) ?? APIResponse(success: false, data: nil, error: nil)
        }
    }

    // MARK: - Device ID

    /// Get or create persistent device identifier
    var deviceId: String {
        KeychainHelper.getOrCreateDeviceId()
    }

    // MARK: - Pricing Fallbacks

    private func applyFallbackPlansIfNeeded() {
        if plans.isEmpty {
            plans = [
                PlanInfo(name: "free", credits: 0, price: 0, priceFormatted: "$0"),
                PlanInfo(
                    name: "pro_monthly",
                    credits: 0,
                    price: 15,
                    priceFormatted: "$15",
                    storeKitProductId: "com.latent.pro.monthly"
                ),
                PlanInfo(
                    name: "pro_yearly",
                    credits: 0,
                    price: 120,
                    priceFormatted: "$120",
                    storeKitProductId: "com.latent.pro.yearly"
                )
            ]
        }

        if creditsPacks.isEmpty {
            creditsPacks = [
                CreditPackInfo(
                    name: "credits_100",
                    credits: 100,
                    price: 4.99,
                    priceFormatted: "$4.99",
                    storeKitProductId: "com.latent.credits.100"
                ),
                CreditPackInfo(
                    name: "credits_300",
                    credits: 300,
                    price: 11.99,
                    priceFormatted: "$11.99",
                    storeKitProductId: "com.latent.credits.300"
                ),
                CreditPackInfo(
                    name: "credits_1000",
                    credits: 1000,
                    price: 29.99,
                    priceFormatted: "$29.99",
                    storeKitProductId: "com.latent.credits.1000"
                )
            ]
        }
    }

    private func cacheCreditsBalance(_ balance: CreditsBalance) {
        guard let encoded = try? JSONEncoder().encode(balance) else { return }
        UserDefaults.standard.set(encoded, forKey: cachedCreditsBalanceKey)
    }

    private func restoreCachedCreditsBalance() {
        guard let data = UserDefaults.standard.data(forKey: cachedCreditsBalanceKey),
              let cached = try? JSONDecoder().decode(CreditsBalance.self, from: data) else {
            return
        }
        creditsBalance = cached
    }

    private func startCheckoutSyncWindow(reason: String) {
        guard isAuthenticated else { return }
        checkoutSyncTask?.cancel()

        let baseline = creditsBalance
        checkoutSyncTask = Task { [weak self] in
            guard let self else { return }
            let startedAt = Date()
            var attempt = 0

            while !Task.isCancelled && Date().timeIntervalSince(startedAt) < Self.checkoutSyncWindowSeconds {
                attempt += 1

                await self.refreshEntitlementsIfNeeded(force: true, reason: reason)

                if Self.entitlementsChanged(from: baseline, to: self.creditsBalance) {
                    return
                }

                let delaySeconds: TimeInterval = attempt <= 5 ? 2 : 5
                try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            }
        }
    }

    static func entitlementsChanged(from old: CreditsBalance?, to new: CreditsBalance?) -> Bool {
        switch (old, new) {
        case (nil, nil):
            return false
        case (nil, .some), (.some, nil):
            return true
        case (.some(let lhs), .some(let rhs)):
            return lhs.subscription.plan != rhs.subscription.plan ||
                lhs.subscription.total != rhs.subscription.total ||
                lhs.subscription.used != rhs.subscription.used ||
                lhs.subscription.remaining != rhs.subscription.remaining ||
                lhs.purchased.total != rhs.purchased.total ||
                lhs.purchased.remaining != rhs.purchased.remaining ||
                lhs.totalRemaining != rhs.totalRemaining
        }
    }

    // MARK: - Network Helpers

    private func get<T: Codable>(endpoint: String, authenticated: Bool = true) async throws -> T {
        var request = URLRequest(url: URL(string: baseURL + endpoint)!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")

        if authenticated, let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AccountError.networkError
        }

        // Handle security-related HTTP status codes
        switch httpResponse.statusCode {
        case 200...299:
            break // Success, continue to decode

        case 401:
            // Check for token replay detection
            if let errorCode = parseErrorCode(from: data), errorCode == "TOKEN_REPLAY_DETECTED" {
                signOut()
                throw AccountError.tokenReplayDetected
            }
            // Try to refresh token
            if try await refreshAccessToken() {
                return try await get(endpoint: endpoint, authenticated: authenticated)
            }
            throw AccountError.unauthorized

        case 403:
            let reason = parseErrorMessage(from: data) ?? "Access denied"
            throw AccountError.securityBlock(reason: reason)

        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { Int($0) } ?? 60
            throw AccountError.rateLimited(retryAfter: retryAfter)

        default:
            break // Other errors handled by decoder
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
    
    private func post<T: Codable>(
        endpoint: String,
        body: [String: Any],
        authenticated: Bool = false
    ) async throws -> T {
        var request = URLRequest(url: URL(string: baseURL + endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        if authenticated, let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AccountError.networkError
        }

        // Handle security-related HTTP status codes
        switch httpResponse.statusCode {
        case 200...299:
            break // Success, continue to decode

        case 401:
            // Check for token replay detection
            if let errorCode = parseErrorCode(from: data), errorCode == "TOKEN_REPLAY_DETECTED" {
                signOut()
                throw AccountError.tokenReplayDetected
            }
            // Try to refresh token
            if try await refreshAccessToken() {
                return try await post(endpoint: endpoint, body: body, authenticated: authenticated)
            }
            throw AccountError.unauthorized

        case 403:
            let reason = parseErrorMessage(from: data) ?? "Access denied"
            throw AccountError.securityBlock(reason: reason)

        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { Int($0) } ?? 60
            throw AccountError.rateLimited(retryAfter: retryAfter)

        default:
            break // Other errors handled by decoder
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Error Parsing Helpers

    /// Parse error code from API error response
    private func parseErrorCode(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let code = error["code"] as? String else {
            return nil
        }
        return code
    }

    /// Parse error message from API error response
    private func parseErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String else {
            return nil
        }
        return message
    }
    
    private func refreshAccessToken() async throws -> Bool {
        guard let token = refreshToken else { return false }
        guard !isRefreshingToken else { return false }

        isRefreshingToken = true
        defer { isRefreshingToken = false }

        let response: APIResponse<RefreshTokenResponse> = try await post(
            endpoint: "/auth/refresh",
            body: ["refreshToken": token]
        )

        guard let data = response.data else { return false }

        accessToken = data.accessToken
        refreshToken = data.refreshToken
        return true
    }
}

// MARK: - Errors

enum AccountError: LocalizedError {
    case networkError
    case invalidResponse
    case unauthorized
    case insufficientCredits
    case rateLimited(retryAfter: Int)
    case securityBlock(reason: String)
    case tokenReplayDetected
    case externalCheckoutNotAllowed
    case billingProductUnavailable
    case purchasePending
    case purchaseCancelled
    case accountDeletionConfirmationMismatch

    var errorDescription: String? {
        switch self {
        case .networkError: return "Network error. Please check your connection."
        case .invalidResponse: return "Invalid response from server."
        case .unauthorized: return "Session expired. Please sign in again."
        case .insufficientCredits: return "Not enough credits."
        case .rateLimited(let retryAfter): return "Too many requests. Please wait \(retryAfter) seconds."
        case .securityBlock(let reason): return "Request blocked: \(reason)"
        case .tokenReplayDetected: return "Security alert: Please sign in again."
        case .externalCheckoutNotAllowed: return "This build uses in-app purchases only."
        case .billingProductUnavailable: return "Pricing is currently unavailable. Please try again."
        case .purchasePending: return "Purchase is pending approval."
        case .purchaseCancelled: return "Purchase was cancelled."
        case .accountDeletionConfirmationMismatch: return "Email confirmation does not match your account."
        }
    }

    /// Retry-After value for rate limited errors
    var retryAfter: Int? {
        if case .rateLimited(let seconds) = self {
            return seconds
        }
        return nil
    }
}

// MARK: - Keychain Helper

struct KeychainHelper {
    /// Keychain keys
    private static let deviceIdKey = "rawctl_device_id"

    static func set(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Device ID Management

    /// Get or create a persistent device identifier
    /// This ID is generated once and stored in Keychain for the lifetime of the app installation
    static func getOrCreateDeviceId() -> String {
        // Check if we already have a device ID
        if let existingId = get(key: deviceIdKey) {
            return existingId
        }

        // Generate a new UUID
        let newDeviceId = UUID().uuidString

        // Store with more restrictive access - only accessible on this device
        let data = newDeviceId.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: deviceIdKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            print("[KeychainHelper] Failed to store device ID: \(status)")
        }

        return newDeviceId
    }

    /// Get current device ID (returns nil if not yet created)
    static var deviceId: String? {
        return get(key: deviceIdKey)
    }
}

// MARK: - Empty Response

struct EmptyResponse: Codable {}

// MARK: - User Style Profile

/// Accumulated colour-grading preference profile.
/// Built from the rolling average of user corrections applied on top of AI suggestions.
struct UserStyleProfile: Codable {
    /// Number of AI grading cycles that have contributed to this profile.
    var sampleCount: Int = 0
    /// Rolling-average exposure correction the user applies after AI grading.
    var exposureBias: Double = 0
    /// Rolling-average contrast correction.
    var contrastBias: Double = 0
    /// Moods the user tends to request.
    var preferredMoods: [String] = []
    /// Moods the user rarely accepts.
    var avoidedMoods: [String] = []
}

// MARK: - Billing Abstraction

@MainActor
protocol BillingProvider {
    var channel: AppDistributionChannel { get }

    func refreshCatalog(accountService: AccountService) async
    func purchasePlan(named: String, accountService: AccountService) async throws
    func purchaseCreditsPack(named: String, accountService: AccountService) async throws
    func openManageSubscription(accountService: AccountService) async throws
    func restorePurchases(accountService: AccountService) async throws
    func syncEntitlements(accountService: AccountService, reason: String) async
}

@MainActor
struct DirectBillingProvider: BillingProvider {
    let channel: AppDistributionChannel = .direct

    func refreshCatalog(accountService: AccountService) async {
        _ = accountService
    }

    func purchasePlan(named: String, accountService: AccountService) async throws {
        try await accountService.createSubscriptionCheckout(plan: named)
    }

    func purchaseCreditsPack(named: String, accountService: AccountService) async throws {
        try await accountService.createCreditsCheckout(pack: named)
    }

    func openManageSubscription(accountService: AccountService) async throws {
        try await accountService.openDirectBillingPortal()
    }

    func restorePurchases(accountService: AccountService) async throws {
        await accountService.refreshEntitlementsIfNeeded(force: true, reason: "direct_manual_restore")
        accountService.billingNotice = "Account status refreshed."
    }

    func syncEntitlements(accountService: AccountService, reason: String) async {
        _ = accountService
        _ = reason
    }
}

@MainActor
struct StoreKitBillingProvider: BillingProvider {
    let channel: AppDistributionChannel = .mas

    private let planProductMap: [String: String] = [
        "pro": "com.latent.pro.monthly",
        "pro_monthly": "com.latent.pro.monthly",
        "pro_yearly": "com.latent.pro.yearly",
        "yearly": "com.latent.pro.yearly",
        "annual": "com.latent.pro.yearly"
    ]

    private let creditPackProductMap: [String: String] = [
        "credits_100": "com.latent.credits.100",
        "credits_300": "com.latent.credits.300",
        "credits_1000": "com.latent.credits.1000"
    ]

    func refreshCatalog(accountService: AccountService) async {
        let ids = Set(
            accountService.plans.compactMap(productId(for:)) +
            accountService.creditsPacks.compactMap(productId(for:))
        )
        guard !ids.isEmpty else { return }

        do {
            let products = try await Product.products(for: Array(ids))
            guard !products.isEmpty else { return }

            let productsById = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })

            accountService.plans = accountService.plans.map { plan in
                guard let id = productId(for: plan),
                      let product = productsById[id] else {
                    return plan
                }
                return PlanInfo(
                    name: plan.name,
                    credits: plan.credits,
                    price: NSDecimalNumber(decimal: product.price).doubleValue,
                    priceFormatted: product.displayPrice,
                    storeKitProductId: id
                )
            }

            accountService.creditsPacks = accountService.creditsPacks.map { pack in
                guard let id = productId(for: pack),
                      let product = productsById[id] else {
                    return pack
                }
                return CreditPackInfo(
                    name: pack.name,
                    credits: pack.credits,
                    price: NSDecimalNumber(decimal: product.price).doubleValue,
                    priceFormatted: product.displayPrice,
                    storeKitProductId: id
                )
            }
        } catch {
            print("[StoreKitBillingProvider] Failed to refresh catalog: \(error)")
        }
    }

    func purchasePlan(named: String, accountService: AccountService) async throws {
        guard let plan = accountService.plans.first(where: { $0.name.caseInsensitiveCompare(named) == .orderedSame }),
              let productId = productId(for: plan) else {
            throw AccountError.billingProductUnavailable
        }

        try await purchase(productId: productId, accountService: accountService, reason: "mas_plan_purchase")
    }

    func purchaseCreditsPack(named: String, accountService: AccountService) async throws {
        guard let pack = accountService.creditsPacks.first(where: { $0.name.caseInsensitiveCompare(named) == .orderedSame }),
              let productId = productId(for: pack) else {
            throw AccountError.billingProductUnavailable
        }

        try await purchase(productId: productId, accountService: accountService, reason: "mas_credits_purchase")
    }

    func openManageSubscription(accountService: AccountService) async throws {
        _ = accountService
        guard let subscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions") else {
            throw AccountError.invalidResponse
        }
        NSWorkspace.shared.open(subscriptionsURL)
    }

    func restorePurchases(accountService: AccountService) async throws {
        accountService.isLoading = true
        defer { accountService.isLoading = false }

        try await AppStore.sync()
        await syncEntitlements(accountService: accountService, reason: "mas_restore")
        await accountService.refreshEntitlementsIfNeeded(force: true, reason: "mas_restore")
        accountService.billingNotice = "Purchases restored."
    }

    func syncEntitlements(accountService: AccountService, reason: String) async {
        var signedTransactions: [String] = []

        for await entitlement in Transaction.currentEntitlements {
            switch entitlement {
            case .verified(let transaction):
                signedTransactions.append(transaction.jsonRepresentation.base64EncodedString())
                if transaction.revocationDate != nil {
                    accountService.billingNotice = "A previous purchase was revoked or refunded."
                }
            case .unverified(_, let error):
                print("[StoreKitBillingProvider] Unverified entitlement: \(error)")
            }
        }

        do {
            try await accountService.syncStoreKitTransactionsWithBackend(
                signedTransactions: signedTransactions,
                reason: reason
            )
        } catch {
            print("[StoreKitBillingProvider] Failed to sync transactions: \(error)")
        }
    }

    private func purchase(
        productId: String,
        accountService: AccountService,
        reason: String
    ) async throws {
        let products = try await Product.products(for: [productId])
        guard let product = products.first else {
            throw AccountError.billingProductUnavailable
        }

        accountService.isLoading = true
        defer { accountService.isLoading = false }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verifiedTransaction(from: verification)
            await transaction.finish()
            await syncEntitlements(accountService: accountService, reason: reason)
            await accountService.refreshEntitlementsIfNeeded(force: true, reason: reason)
            accountService.billingNotice = "Purchase completed."

        case .pending:
            accountService.billingNotice = "Purchase is pending approval."
            throw AccountError.purchasePending

        case .userCancelled:
            throw AccountError.purchaseCancelled

        @unknown default:
            throw AccountError.invalidResponse
        }
    }

    private func verifiedTransaction(
        from verification: VerificationResult<Transaction>
    ) throws -> Transaction {
        switch verification {
        case .verified(let transaction):
            return transaction
        case .unverified:
            throw AccountError.invalidResponse
        }
    }

    private func productId(for plan: PlanInfo) -> String? {
        if let explicit = normalized(plan.storeKitProductId) {
            return explicit
        }
        return planProductMap[normalized(plan.name) ?? ""]
    }

    private func productId(for pack: CreditPackInfo) -> String? {
        if let explicit = normalized(pack.storeKitProductId) {
            return explicit
        }

        if let mapped = creditPackProductMap[normalized(pack.name) ?? ""] {
            return mapped
        }

        let digits = pack.name.filter { $0.isNumber }
        if !digits.isEmpty {
            return creditPackProductMap["credits_\(digits)"]
        }

        return nil
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }
}
