//
//  AccountService.swift
//  rawctl
//
//  Service for account management and API communication
//

import Foundation
import AuthenticationServices

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
    
    var id: String { name }
}

struct CreditPackInfo: Codable, Identifiable {
    let name: String
    let credits: Int
    let price: Double
    let priceFormatted: String
    
    var id: String { name }
}

// MARK: - AccountService

@MainActor
final class AccountService: ObservableObject {
    static let shared = AccountService()
    
    // API Configuration - Always use production API
    private let baseURL = "https://api.rawctl.com"
    
    // Published state
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var currentUser: UserInfo?
    @Published var creditsBalance: CreditsBalance?
    @Published var plans: [PlanInfo] = []
    @Published var creditsPacks: [CreditPackInfo] = []
    @Published var errorMessage: String?
    
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
        
        // Load additional data
        await loadCreditsBalance()
        await loadPlans()
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
        
        await loadCreditsBalance()
        await loadPlans()
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
        
        await loadCreditsBalance()
        await loadPlans()
    }
    
    /// Sign out
    func signOut() {
        accessToken = nil
        refreshToken = nil
        currentUser = nil
        creditsBalance = nil
        isAuthenticated = false
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

    func loadCreditsBalance() async {
        guard isAuthenticated else { return }

        do {
            let response: APIResponse<CreditsBalance> = try await get(endpoint: "/user/credits")
            creditsBalance = response.data
        } catch AccountError.unauthorized {
            // Token expired and refresh failed, sign out
            print("[AccountService] Unauthorized loading credits, signing out")
            signOut()
        } catch {
            print("[AccountService] Failed to load credits: \(error)")
        }
    }
    
    func loadPlans() async {
        do {
            let response: APIResponse<PlansResponse> = try await get(endpoint: "/checkout/plans", authenticated: false)
            if let data = response.data {
                plans = data.plans
                creditsPacks = data.creditsPacks
            }
        } catch {
            print("[AccountService] Failed to load plans: \(error)")
            // Plans are public data, don't sign out on failure
        }
    }
    
    // MARK: - Checkout
    
    /// Create subscription checkout and open in browser
    func createSubscriptionCheckout(plan: String) async throws {
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
    }
    
    /// Create credits pack checkout and open in browser
    func createCreditsCheckout(pack: String) async throws {
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
    }
    
    /// Open billing portal
    func openBillingPortal() async throws {
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
    }
    
    // MARK: - AI Operations
    
    /// Check if user has enough credits
    func hasEnoughCredits(for operation: String) -> Bool {
        guard let balance = creditsBalance else { return false }
        
        let cost: Int
        switch operation {
        case "nano_banana_1k": cost = 1
        case "nano_banana_pro_2k": cost = 3
        case "nano_banana_pro_4k": cost = 6
        default: cost = 1
        }
        
        return balance.totalRemaining >= cost
    }
    
    // MARK: - Device ID

    /// Get or create persistent device identifier
    var deviceId: String {
        KeychainHelper.getOrCreateDeviceId()
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
        
        let response: APIResponse<AuthResponse> = try await post(
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

    var errorDescription: String? {
        switch self {
        case .networkError: return "Network error. Please check your connection."
        case .invalidResponse: return "Invalid response from server."
        case .unauthorized: return "Session expired. Please sign in again."
        case .insufficientCredits: return "Not enough credits."
        case .rateLimited(let retryAfter): return "Too many requests. Please wait \(retryAfter) seconds."
        case .securityBlock(let reason): return "Request blocked: \(reason)"
        case .tokenReplayDetected: return "Security alert: Please sign in again."
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
