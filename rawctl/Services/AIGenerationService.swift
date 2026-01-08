//
//  AIGenerationService.swift
//  rawctl
//
//  Service for AI image generation and prompt enhancement
//

import Foundation
import AppKit

// MARK: - API Response Types

struct EnhancePromptResponse: Codable {
    let enhancedPrompt: String
    let originalPrompt: String
}

struct GenerateImageResponse: Codable {
    let image: String  // base64
    let text: String?
    let creditsUsed: Int
    let creditsRemaining: Int
    let thoughtSignature: String?  // For multi-turn editing
}

// MARK: - AIGenerationService

@MainActor
final class AIGenerationService: ObservableObject {
    static let shared = AIGenerationService()

    // API Configuration - Always use production API
    private let baseURL = "https://api.rawctl.com"

    // Request timeout
    private let requestTimeout: TimeInterval = 30

    // Published state
    @Published var state: AIGenerationState = .idle
    @Published var currentRequest: AIGenerationRequest?

    // Cache for enhanced prompts (session-only)
    private var promptCache: [String: String] = [:]

    // Image compression settings
    private let maxImageDimension: CGFloat = 2048  // Max dimension for AI processing
    private let jpegCompressionQuality: CGFloat = 0.85  // 85% JPEG quality

    // MARK: - Prompt Enhancement

    /// Enhance a user prompt for better AI generation results
    /// This is FREE and does not consume credits
    func enhancePrompt(_ prompt: String, language: String = "system") async throws -> String {
        // Check cache first
        if let cached = promptCache[prompt] {
            return cached
        }

        guard let token = getAccessToken() else {
            throw AIGenerationError.authenticationRequired
        }

        var request = URLRequest(url: URL(string: "\(baseURL)/ai/enhance-prompt")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = requestTimeout

        let body: [String: Any] = [
            "prompt": prompt,
            "language": language
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIGenerationError.networkError
            }

            switch httpResponse.statusCode {
            case 200:
                let apiResponse = try JSONDecoder().decode(APIResponse<EnhancePromptResponse>.self, from: data)
                guard let result = apiResponse.data else {
                    throw AIGenerationError.generationFailed("Invalid response from server")
                }
                // Cache the result
                promptCache[prompt] = result.enhancedPrompt
                return result.enhancedPrompt

            case 401:
                throw AIGenerationError.authenticationRequired

            case 429:
                throw AIGenerationError.generationFailed("Too many requests. Please wait a moment.")

            case 500...599:
                throw AIGenerationError.generationFailed("Server error. Please try again later.")

            default:
                throw AIGenerationError.networkError
            }
        } catch let error as AIGenerationError {
            throw error
        } catch let urlError as URLError {
            switch urlError.code {
            case .timedOut:
                throw AIGenerationError.generationFailed("Request timed out. Please try again.")
            case .notConnectedToInternet, .networkConnectionLost:
                throw AIGenerationError.networkError
            default:
                throw AIGenerationError.generationFailed("Connection error: \(urlError.localizedDescription)")
            }
        } catch {
            throw AIGenerationError.generationFailed(error.localizedDescription)
        }
    }

    // MARK: - Image Generation

    /// Generate an AI layer from the given request
    func generateLayer(
        for asset: PhotoAsset,
        request: AIGenerationRequest
    ) async throws -> AILayer {
        // Validate request
        if case .failure(let error) = request.validate() {
            throw error
        }

        // Check credits
        let requiredCredits = request.estimatedCredits
        guard (AccountService.shared.creditsBalance?.totalRemaining ?? 0) >= requiredCredits else {
            throw AIGenerationError.insufficientCredits
        }

        state = .uploading(progress: 0)
        currentRequest = request

        defer {
            state = .idle
            currentRequest = nil
        }

        do {
            // Compress and encode image for upload
            let imageBase64 = try compressImageForUpload(from: asset.url)

            // Prepare mask if region mode
            var maskBase64: String?
            if request.mode == .region, let mask = request.mask {
                let imageSize = CGSize(
                    width: asset.metadata?.width ?? 1000,
                    height: asset.metadata?.height ?? 1000
                )
                if let maskPNG = mask.renderToPNG(targetSize: imageSize) {
                    maskBase64 = maskPNG.base64EncodedString()
                }
            }

            // Call API
            state = .uploading(progress: 0.5)

            let result = try await callGenerateAPI(
                image: imageBase64,
                mask: maskBase64,
                prompt: request.effectivePrompt,
                type: request.type,
                preserveStrength: request.preserveStrength,
                resolution: request.resolution
            )

            state = .processing(progress: 100)

            // Save result to cache
            let layerId = UUID()
            let resultPath = try saveResultToCache(
                base64Image: result.image,
                assetFingerprint: asset.fingerprint,
                layerId: layerId
            )

            // Refresh credits
            await AccountService.shared.loadCreditsBalance()

            // Create AILayer
            let layer = AILayer(
                id: layerId,
                type: request.type,
                prompt: request.effectivePrompt,
                originalPrompt: request.prompt,
                maskData: request.mask?.strokes.isEmpty == false ? try? request.mask?.exportStrokes() : nil,
                generatedImagePath: resultPath,
                preserveStrength: request.preserveStrength,
                resolution: request.resolution,
                creditsUsed: result.creditsUsed
            )

            state = .complete
            return layer

        } catch {
            if let aiError = error as? AIGenerationError {
                throw aiError
            }
            throw AIGenerationError.generationFailed(error.localizedDescription)
        }
    }

    // MARK: - API Calls

    private func callGenerateAPI(
        image: String,
        mask: String?,
        prompt: String,
        type: AILayerType,
        preserveStrength: Double,
        resolution: AIResolution
    ) async throws -> GenerateImageResponse {
        guard let token = getAccessToken() else {
            throw AIGenerationError.authenticationRequired
        }

        var request = URLRequest(url: URL(string: "\(baseURL)/ai/edit")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120  // 2 minutes for generation

        // Determine model based on resolution
        let model: String
        let imageSize: String?
        switch resolution {
        case .standard:
            model = "nano_banana"
            imageSize = nil
        case .high:
            model = "nano_banana_pro"
            imageSize = "2K"
        case .ultra:
            model = "nano_banana_pro"
            imageSize = "4K"
        }

        var body: [String: Any] = [
            "image": image,
            "prompt": prompt,
            "model": model,
            "type": type.rawValue,
            "preserveStrength": preserveStrength
        ]

        if let mask = mask {
            body["mask"] = mask
        }

        if let imageSize = imageSize {
            body["imageSize"] = imageSize
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIGenerationError.networkError
            }

            switch httpResponse.statusCode {
            case 200...299:
                let apiResponse = try JSONDecoder().decode(APIResponse<GenerateImageResponse>.self, from: data)
                guard let result = apiResponse.data else {
                    throw AIGenerationError.generationFailed("Invalid response from server")
                }
                return result

            case 401:
                throw AIGenerationError.authenticationRequired

            case 402:
                throw AIGenerationError.insufficientCredits

            case 429:
                throw AIGenerationError.generationFailed("Too many requests. Please wait a moment.")

            case 500...599:
                throw AIGenerationError.generationFailed("Server error. Please try again later.")

            default:
                if let errorResponse = try? JSONDecoder().decode(APIResponse<EmptyResponse>.self, from: data),
                   let error = errorResponse.error {
                    throw AIGenerationError.generationFailed(error.message)
                }
                throw AIGenerationError.generationFailed("HTTP \(httpResponse.statusCode)")
            }
        } catch let error as AIGenerationError {
            throw error
        } catch let urlError as URLError {
            switch urlError.code {
            case .timedOut:
                throw AIGenerationError.generationFailed("Request timed out. Please try again.")
            case .notConnectedToInternet, .networkConnectionLost:
                throw AIGenerationError.networkError
            default:
                throw AIGenerationError.generationFailed("Connection error: \(urlError.localizedDescription)")
            }
        } catch {
            throw AIGenerationError.generationFailed(error.localizedDescription)
        }
    }

    // MARK: - Cache Management

    private func saveResultToCache(
        base64Image: String,
        assetFingerprint: String,
        layerId: UUID
    ) throws -> String {
        guard let imageData = Data(base64Encoded: base64Image) else {
            throw AIGenerationError.generationFailed("Invalid image data")
        }

        let resultURL = CacheManager.shared.aiResultPath(
            assetFingerprint: assetFingerprint,
            editId: layerId
        )

        try imageData.write(to: resultURL)

        return resultURL.lastPathComponent
    }

    /// Load a layer's result image
    func loadLayerImage(
        layer: AILayer,
        assetFingerprint: String
    ) -> NSImage? {
        let resultURL = CacheManager.shared.aiCacheDirectory(for: assetFingerprint)
            .appendingPathComponent(layer.generatedImagePath)

        guard FileManager.default.fileExists(atPath: resultURL.path) else {
            return nil
        }

        return NSImage(contentsOf: resultURL)
    }

    /// Delete a layer's cached files
    func deleteLayerCache(
        layer: AILayer,
        assetFingerprint: String
    ) {
        let resultURL = CacheManager.shared.aiCacheDirectory(for: assetFingerprint)
            .appendingPathComponent(layer.generatedImagePath)

        try? FileManager.default.removeItem(at: resultURL)
    }

    // MARK: - Image Compression

    /// Compress and resize image for API upload
    /// Returns compressed JPEG data as base64 string
    private func compressImageForUpload(from url: URL) throws -> String {
        // Load image using NSImage (handles RAW, JPEG, PNG, etc.)
        guard let image = NSImage(contentsOf: url) else {
            throw AIGenerationError.generationFailed("Failed to load image")
        }

        // Get the best representation size
        guard let bitmapRep = image.representations.first else {
            throw AIGenerationError.generationFailed("Failed to get image representation")
        }

        let originalWidth = CGFloat(bitmapRep.pixelsWide)
        let originalHeight = CGFloat(bitmapRep.pixelsHigh)

        // Calculate target size (preserve aspect ratio, limit max dimension)
        var targetWidth = originalWidth
        var targetHeight = originalHeight

        if originalWidth > maxImageDimension || originalHeight > maxImageDimension {
            let scale = min(maxImageDimension / originalWidth, maxImageDimension / originalHeight)
            targetWidth = originalWidth * scale
            targetHeight = originalHeight * scale
        }

        // Create resized bitmap
        let targetSize = NSSize(width: targetWidth, height: targetHeight)
        guard let resizedRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(targetWidth),
            pixelsHigh: Int(targetHeight),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw AIGenerationError.generationFailed("Failed to create bitmap")
        }

        // Draw image into resized bitmap
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: resizedRep)
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        NSGraphicsContext.restoreGraphicsState()

        // Compress to JPEG
        guard let jpegData = resizedRep.representation(
            using: .jpeg,
            properties: [.compressionFactor: jpegCompressionQuality]
        ) else {
            throw AIGenerationError.generationFailed("Failed to compress image")
        }

        return jpegData.base64EncodedString()
    }

    // MARK: - Helpers

    private func getAccessToken() -> String? {
        KeychainHelper.get(key: "rawctl_access_token")
    }

    /// Clear prompt cache
    func clearPromptCache() {
        promptCache.removeAll()
    }
}

// MARK: - Generation State

enum AIGenerationState: Equatable {
    case idle
    case uploading(progress: Double)
    case processing(progress: Int)
    case complete
    case failed(String)

    var isActive: Bool {
        switch self {
        case .idle, .complete, .failed: return false
        default: return true
        }
    }

    var statusText: String {
        switch self {
        case .idle: return ""
        case .uploading(let progress): return "Uploading... \(Int(progress * 100))%"
        case .processing(let progress): return "Generating... \(progress)%"
        case .complete: return "Complete"
        case .failed(let error): return error
        }
    }
}

