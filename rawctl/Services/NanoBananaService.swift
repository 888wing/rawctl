//
//  NanoBananaService.swift
//  rawctl
//
//  AI photo enhancement service using Nano Banana
//

import Foundation
import AppKit

// MARK: - Types

/// Resolution options for Nano Banana processing
enum NanoBananaResolution: String, CaseIterable, Identifiable {
    case standard = "1k"   // 1024px
    case pro2k = "2k"      // 2048px
    case pro4k = "4k"      // 4096px
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .standard: return "Standard (1K)"
        case .pro2k: return "Pro (2K)"
        case .pro4k: return "Pro (4K)"
        }
    }
    
    var credits: Int {
        switch self {
        case .standard: return 1
        case .pro2k: return 3
        case .pro4k: return 6
        }
    }
    
    var maxPixels: Int {
        switch self {
        case .standard: return 1024
        case .pro2k: return 2048
        case .pro4k: return 4096
        }
    }
}

/// Processing state
enum NanoBananaState: Equatable {
    case idle
    case uploading(progress: Double)
    case processing(progress: Int)
    case downloading
    case complete(resultURL: URL)
    case failed(error: String)
    
    var isActive: Bool {
        switch self {
        case .idle, .complete, .failed: return false
        default: return true
        }
    }
}

/// Job status from API
struct NanoBananaJobStatus: Codable {
    let status: String  // "pending", "processing", "complete", "failed"
    let progress: Int?
    let resultUrl: String?
    let error: String?
}

/// Job creation response
struct NanoBananaJobResponse: Codable {
    let jobId: String
}

// MARK: - NanoBananaService

@MainActor
final class NanoBananaService: ObservableObject {
    static let shared = NanoBananaService()

    // API Configuration - Always use production API
    private let baseURL = "https://api.rawctl.com"

    // Request timeouts
    private let uploadTimeout: TimeInterval = 60   // 1 minute for upload
    private let pollingTimeout: TimeInterval = 10  // 10 seconds per poll
    private let downloadTimeout: TimeInterval = 60 // 1 minute for download

    // Published state
    @Published var state: NanoBananaState = .idle
    @Published var currentJobId: String?

    // Current task (for cancellation)
    private var currentTask: Task<Void, Never>?
    private var pollingTask: Task<Void, Never>?
    
    // MARK: - Main Entry Point
    
    /// Process an image with Nano Banana AI
    /// - Parameters:
    ///   - asset: The photo asset to process
    ///   - resolution: Target resolution
    /// - Returns: URL of the enhanced image file
    func processImage(
        asset: PhotoAsset,
        resolution: NanoBananaResolution
    ) async throws -> URL {
        // Check credits first
        guard AccountService.shared.hasEnoughCredits(for: "nano_banana_\(resolution.rawValue)") else {
            throw NanoBananaError.insufficientCredits
        }
        
        state = .uploading(progress: 0)
        
        // Cancel any existing task
        currentTask?.cancel()
        pollingTask?.cancel()
        
        do {
            // Step 1: Upload image and create job
            let jobId = try await uploadImage(asset: asset, resolution: resolution)
            currentJobId = jobId
            
            // Step 2: Poll for completion
            let resultURL = try await pollForCompletion(jobId: jobId)
            
            // Step 3: Download result
            state = .downloading
            let localURL = try await downloadResult(from: resultURL, for: asset)
            
            // Step 4: Refresh credits balance
            await AccountService.shared.loadCreditsBalance()
            
            state = .complete(resultURL: localURL)
            return localURL
            
        } catch {
            if Task.isCancelled {
                state = .idle
                throw NanoBananaError.cancelled
            }
            
            let errorMessage = (error as? NanoBananaError)?.localizedDescription ?? error.localizedDescription
            state = .failed(error: errorMessage)
            throw error
        }
    }
    
    /// Cancel the current processing
    func cancel() {
        currentTask?.cancel()
        pollingTask?.cancel()
        currentJobId = nil
        state = .idle
    }
    
    // MARK: - API Methods
    
    /// Upload image and create processing job
    private func uploadImage(asset: PhotoAsset, resolution: NanoBananaResolution) async throws -> String {
        guard let token = getAccessToken() else {
            throw NanoBananaError.unauthorized
        }
        
        // Read image data
        let imageData: Data
        do {
            imageData = try Data(contentsOf: asset.url)
        } catch {
            throw NanoBananaError.fileReadError
        }
        
        // Create multipart request
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "\(baseURL)/ai/nano-banana")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = uploadTimeout
        
        // Build multipart body
        var body = Data()
        
        // Add resolution field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"resolution\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(resolution.rawValue)\r\n".data(using: .utf8)!)
        
        // Add image file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(asset.filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Use URLSession delegate for upload progress
        let (data, response) = try await uploadWithProgress(request: request, body: body)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NanoBananaError.networkError
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            let result = try decoder.decode(APIResponse<NanoBananaJobResponse>.self, from: data)
            guard let jobResponse = result.data else {
                throw NanoBananaError.invalidResponse
            }
            return jobResponse.jobId
            
        case 401:
            throw NanoBananaError.unauthorized
            
        case 402:
            throw NanoBananaError.insufficientCredits
            
        default:
            if let errorResponse = try? JSONDecoder().decode(APIResponse<EmptyResponse>.self, from: data),
               let error = errorResponse.error {
                throw NanoBananaError.serverError(error.message)
            }
            throw NanoBananaError.serverError("HTTP \(httpResponse.statusCode)")
        }
    }
    
    /// Upload with progress tracking
    private func uploadWithProgress(request: URLRequest, body: Data) async throws -> (Data, URLResponse) {
        // For simplicity, we'll simulate progress during upload
        // In production, you'd use URLSessionTaskDelegate for actual progress
        
        _ = body.count // Total size for future progress tracking
        
        // Simulate upload progress
        for i in stride(from: 0.0, through: 0.9, by: 0.1) {
            try Task.checkCancellation()
            state = .uploading(progress: i)
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }
        
        var req = request
        req.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: req)
        
        state = .uploading(progress: 1.0)
        
        return (data, response)
    }
    
    /// Poll for job completion
    private func pollForCompletion(jobId: String) async throws -> URL {
        guard let token = getAccessToken() else {
            throw NanoBananaError.unauthorized
        }
        
        state = .processing(progress: 0)
        
        let maxAttempts = 120  // 2 minutes max
        var attempts = 0
        
        while attempts < maxAttempts {
            try Task.checkCancellation()

            var request = URLRequest(url: URL(string: "\(baseURL)/ai/jobs/\(jobId)")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = pollingTimeout

            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw NanoBananaError.networkError
            }
            
            let status = try JSONDecoder().decode(APIResponse<NanoBananaJobStatus>.self, from: data)
            
            guard let jobStatus = status.data else {
                throw NanoBananaError.invalidResponse
            }
            
            switch jobStatus.status {
            case "complete":
                guard let resultUrlString = jobStatus.resultUrl,
                      let resultURL = URL(string: resultUrlString) else {
                    throw NanoBananaError.invalidResponse
                }
                return resultURL
                
            case "failed":
                throw NanoBananaError.processingFailed(jobStatus.error ?? "Unknown error")
                
            case "processing", "pending":
                state = .processing(progress: jobStatus.progress ?? 0)
                
            default:
                break
            }
            
            // Wait before next poll
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            attempts += 1
        }
        
        throw NanoBananaError.timeout
    }
    
    /// Download result image
    private func downloadResult(from url: URL, for asset: PhotoAsset) async throws -> URL {
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NanoBananaError.downloadFailed
        }
        
        // Save to file alongside original
        let originalURL = asset.url
        let directory = originalURL.deletingLastPathComponent()
        let baseName = originalURL.deletingPathExtension().lastPathComponent
        let outputURL = directory.appendingPathComponent("\(baseName)_enhanced.jpg")
        
        try data.write(to: outputURL)
        
        return outputURL
    }
    
    // MARK: - Advanced Processing
    
    /// Process with advanced configuration (inpaint, style, restore)
    func processAdvanced(
        asset: PhotoAsset,
        config: AIEditConfig
    ) async throws -> AIEdit {
        let editId = UUID()
        let operation = config.operation
        let resolution = config.resolution
        
        // Check credits
        let creditCost = operation.credits(for: resolution)
        guard (AccountService.shared.creditsBalance?.totalRemaining ?? 0) >= creditCost else {
            throw NanoBananaError.insufficientCredits
        }
        
        state = .uploading(progress: 0)
        
        do {
            // Save mask if needed
            var maskPath: String?
            if let mask = config.mask, !mask.isEmpty {
                let maskURL = CacheManager.shared.aiMaskPath(
                    assetFingerprint: asset.fingerprint,
                    editId: editId
                )
                let imageSize = CGSize(
                    width: asset.metadata?.width ?? 1000,
                    height: asset.metadata?.height ?? 1000
                )
                try mask.save(to: maskURL, targetSize: imageSize)
                maskPath = maskURL.lastPathComponent
            }
            
            // Save reference if needed
            var referencePath: String?
            if let refURL = config.referenceURL {
                let refDestURL = CacheManager.shared.aiReferencePath(
                    assetFingerprint: asset.fingerprint,
                    editId: editId
                )
                try FileManager.default.copyItem(at: refURL, to: refDestURL)
                referencePath = refDestURL.lastPathComponent
            }
            
            // Upload and process
            let jobId = try await uploadAdvanced(
                asset: asset,
                config: config,
                maskPath: maskPath != nil ? CacheManager.shared.aiMaskPath(assetFingerprint: asset.fingerprint, editId: editId) : nil
            )
            currentJobId = jobId
            
            // Poll for completion
            let resultRemoteURL = try await pollForCompletion(jobId: jobId)
            
            // Download result to cache
            state = .downloading
            let resultURL = CacheManager.shared.aiResultPath(
                assetFingerprint: asset.fingerprint,
                editId: editId
            )
            try await downloadToCache(from: resultRemoteURL, to: resultURL)
            
            // Refresh credits
            await AccountService.shared.loadCreditsBalance()
            
            // Create AIEdit record
            let edit = AIEdit(
                id: editId,
                operation: operation,
                resolution: resolution,
                prompt: config.prompt,
                maskPath: maskPath,
                referencePath: referencePath,
                resultPath: resultURL.lastPathComponent,
                restoreType: config.restoreType,
                strength: config.strength,
                createdAt: Date(),
                enabled: true
            )
            
            state = .complete(resultURL: resultURL)
            return edit
            
        } catch {
            if Task.isCancelled {
                state = .idle
                throw NanoBananaError.cancelled
            }
            
            let errorMessage = (error as? NanoBananaError)?.localizedDescription ?? error.localizedDescription
            state = .failed(error: errorMessage)
            throw error
        }
    }
    
    /// Upload with advanced parameters
    private func uploadAdvanced(
        asset: PhotoAsset,
        config: AIEditConfig,
        maskPath: URL?
    ) async throws -> String {
        guard let token = getAccessToken() else {
            throw NanoBananaError.unauthorized
        }
        
        // Read image data
        let imageData = try Data(contentsOf: asset.url)
        
        // Read mask if exists
        var maskData: Data?
        if let maskURL = maskPath {
            maskData = try? Data(contentsOf: maskURL)
        }
        
        // Read reference if exists
        var referenceData: Data?
        if let refURL = config.referenceURL {
            referenceData = try? Data(contentsOf: refURL)
        }
        
        // Build multipart request
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "\(baseURL)/ai/nano-banana")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Operation
        body.appendMultipart(name: "operation", value: config.operation.rawValue, boundary: boundary)
        
        // Resolution
        body.appendMultipart(name: "resolution", value: config.resolution.rawValue, boundary: boundary)
        
        // Image
        body.appendMultipart(name: "image", filename: asset.filename, data: imageData, boundary: boundary)
        
        // Prompt
        if let prompt = config.prompt {
            body.appendMultipart(name: "prompt", value: prompt, boundary: boundary)
        }
        
        // Mask
        if let maskData = maskData {
            body.appendMultipart(name: "mask", filename: "mask.png", data: maskData, boundary: boundary, mimeType: "image/png")
        }
        
        // Reference
        if let refData = referenceData {
            body.appendMultipart(name: "reference", filename: "reference.jpg", data: refData, boundary: boundary, mimeType: "image/jpeg")
        }
        
        // Strength
        if let strength = config.strength {
            body.appendMultipart(name: "strength", value: String(strength), boundary: boundary)
        }
        
        // Restore type
        if let restoreType = config.restoreType {
            body.appendMultipart(name: "restoreType", value: restoreType.rawValue, boundary: boundary)
        }
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Upload
        let (data, response) = try await uploadWithProgress(request: request, body: body)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NanoBananaError.networkError
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let result = try JSONDecoder().decode(APIResponse<NanoBananaJobResponse>.self, from: data)
            guard let jobResponse = result.data else {
                throw NanoBananaError.invalidResponse
            }
            return jobResponse.jobId
            
        case 401:
            throw NanoBananaError.unauthorized
            
        case 402:
            throw NanoBananaError.insufficientCredits
            
        default:
            if let errorResponse = try? JSONDecoder().decode(APIResponse<EmptyResponse>.self, from: data),
               let error = errorResponse.error {
                throw NanoBananaError.serverError(error.message)
            }
            throw NanoBananaError.serverError("HTTP \(httpResponse.statusCode)")
        }
    }
    
    /// Download result to local cache
    private func downloadToCache(from url: URL, to localURL: URL) async throws {
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NanoBananaError.downloadFailed
        }
        
        try data.write(to: localURL)
    }
    
    // MARK: - Helpers
    
    private func getAccessToken() -> String? {
        KeychainHelper.get(key: "rawctl_access_token")
    }
}

// MARK: - Data Extension for Multipart

private extension Data {
    mutating func appendMultipart(name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }
    
    mutating func appendMultipart(name: String, filename: String, data: Data, boundary: String, mimeType: String = "application/octet-stream") {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }
}

// MARK: - Errors

enum NanoBananaError: LocalizedError {
    case insufficientCredits
    case unauthorized
    case networkError
    case invalidResponse
    case fileReadError
    case serverError(String)
    case processingFailed(String)
    case downloadFailed
    case timeout
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .insufficientCredits:
            return "Not enough credits. Please purchase more credits to continue."
        case .unauthorized:
            return "Please sign in to use Nano Banana."
        case .networkError:
            return "Network error. Please check your connection."
        case .invalidResponse:
            return "Invalid response from server."
        case .fileReadError:
            return "Failed to read the image file."
        case .serverError(let message):
            return "Server error: \(message)"
        case .processingFailed(let message):
            return "Processing failed: \(message)"
        case .downloadFailed:
            return "Failed to download the enhanced image."
        case .timeout:
            return "Processing timed out. Please try again."
        case .cancelled:
            return "Processing was cancelled."
        }
    }
}
