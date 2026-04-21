//
//  GeminiColorService.swift
//  rawctl
//
//  AI colour grading via Gemini Flash 3 through the Latent backend.
//  Sends the current photo thumbnail to api.latent-app.com/ai/color-grade
//  and receives a ColorGradeDelta — a subset of EditRecipe parameters to apply.
//

import Foundation
import AppKit
import CoreGraphics

// MARK: - Request / Response types

struct ColorGradeRequest: Encodable {
    enum Mode: String, Encodable {
        case auto, mood, reference
    }

    let imageBase64: String
    let mode: Mode
    let mood: String?                   // mood mode only
    let referenceImageBase64: String?   // reference mode only
    let styleProfile: UserStyleProfile?
}

struct ColorGradeResponse: Codable {
    let recipe: ColorGradeDelta
    let analysis: String
    let detectedMood: String
    let creditsUsed: Int
    let creditsRemaining: Int
}

/// Captured after AI suggestions are applied — used to record the preference
/// delta when the user saves (difference between AI suggestion and user's final recipe).
struct PendingAISuggestion {
    let assetId: UUID
    let delta: ColorGradeDelta
    let mode: GeminiColorService.Mode
    let aiAppliedRecipe: EditRecipe
}

// MARK: - GeminiColorService

@MainActor
final class GeminiColorService: ObservableObject {

    static let shared = GeminiColorService()

    enum Mode: Equatable {
        case auto
        case mood(String)
        case reference // reference image supplied separately
    }

    enum MoodPreset: String, CaseIterable, Identifiable {
        case cinematic     = "cinematic"
        case airy          = "airy"
        case moody         = "moody"
        case warmGolden    = "warm_golden"
        case coolUrban     = "cool_urban"
        case bwDramatic    = "bw_dramatic"
        case naturalVibrant = "natural_vibrant"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .cinematic:      return "Cinematic"
            case .airy:           return "Airy"
            case .moody:          return "Moody"
            case .warmGolden:     return "Warm Golden"
            case .coolUrban:      return "Cool Urban"
            case .bwDramatic:     return "B&W Dramatic"
            case .naturalVibrant: return "Natural Vibrant"
            }
        }
    }

    struct ColorGradeResult {
        let delta: ColorGradeDelta
        let analysis: String
        let detectedMood: String
        let creditsUsed: Int
    }

    enum GeminiError: LocalizedError {
        case authenticationRequired
        case insufficientCredits(Int)
        case networkError
        case invalidResponse
        case imageEncodingFailed

        var errorDescription: String? {
            switch self {
            case .authenticationRequired:  return "Sign in to use AI Colour Grading."
            case .insufficientCredits(let n): return "Not enough credits (need \(n))."
            case .networkError:            return "Network error — check your connection."
            case .invalidResponse:         return "Server returned an unexpected response."
            case .imageEncodingFailed:     return "Could not encode the photo for analysis."
            }
        }
    }

    // Published state
    @Published var isAnalysing = false
    @Published var lastError: GeminiError?

    private let baseURL = "https://api.latent-app.com"
    private let requiredCredits = 1   // auto/mood = 1; TODO: reference = 2

    // MARK: - Main API

    /// Analyse the rendered photo and return a ColorGradeDelta.
    /// Caller is responsible for pushing undo history and applying the delta.
    func analyzeAndGrade(
        renderedImage: NSImage,
        mode: Mode,
        referenceImage: NSImage? = nil
    ) async throws -> ColorGradeResult {

        guard let token = KeychainHelper.get(key: "rawctl_access_token") else {
            throw GeminiError.authenticationRequired
        }

        guard (AccountService.shared.creditsBalance?.totalRemaining ?? 0) >= requiredCredits else {
            throw GeminiError.insufficientCredits(requiredCredits)
        }

        guard let imageB64 = renderedImage.jpegBase64(maxDimension: 1024) else {
            throw GeminiError.imageEncodingFailed
        }

        let refB64: String? = referenceImage?.jpegBase64(maxDimension: 1024)

        let modeValue: ColorGradeRequest.Mode
        let moodValue: String?
        switch mode {
        case .auto:           modeValue = .auto;      moodValue = nil
        case .mood(let m):    modeValue = .mood;      moodValue = m
        case .reference:      modeValue = .reference; moodValue = nil
        }

        let requestBody = ColorGradeRequest(
            imageBase64: imageB64,
            mode: modeValue,
            mood: moodValue,
            referenceImageBase64: refB64,
            styleProfile: AccountService.shared.userStyleProfile
        )

        let encoded = try JSONEncoder().encode(requestBody)

        var urlRequest = URLRequest(url: URL(string: "\(baseURL)/ai/color-grade")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = 30
        urlRequest.httpBody = encoded

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw GeminiError.networkError
        }

        // Map specific HTTP status codes to typed errors
        switch http.statusCode {
        case 200...299: break
        case 401: throw GeminiError.authenticationRequired
        case 402:
            // Decode error to get required credits from message if available
            throw GeminiError.insufficientCredits(requiredCredits)
        default: throw GeminiError.invalidResponse
        }

        let envelope = try JSONDecoder().decode(APIResponse<ColorGradeResponse>.self, from: data)
        guard let gradeResponse = envelope.data else {
            throw GeminiError.invalidResponse
        }

        await AccountService.shared.loadCreditsBalance()

        return ColorGradeResult(
            delta: gradeResponse.recipe,
            analysis: gradeResponse.analysis,
            detectedMood: gradeResponse.detectedMood,
            creditsUsed: gradeResponse.creditsUsed
        )
    }
}

// MARK: - NSImage base64 helper

private extension NSImage {
    func jpegBase64(maxDimension: CGFloat) -> String? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let width  = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let scale  = min(maxDimension / max(width, height), 1.0)
        let newW   = Int(width * scale)
        let newH   = Int(height * scale)

        guard let ctx = CGContext(
            data: nil,
            width: newW, height: newH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: newW, height: newH))
        guard let resized = ctx.makeImage() else { return nil }

        let bitmapRep = NSBitmapImageRep(cgImage: resized)
        guard let jpegData = bitmapRep.representation(
            using: .jpeg,
            properties: [.compressionFactor: 0.85]
        ) else { return nil }

        return jpegData.base64EncodedString()
    }
}
