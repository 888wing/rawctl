//
//  ExportService.swift
//  rawctl
//
//  Export queue and JPG rendering
//

import Foundation
import AppKit
import CoreImage

/// Actor managing export queue
actor ExportService {
    static let shared = ExportService()
    
    private var jobs: [ExportJob] = []
    private var currentTask: Task<Void, Never>?
    private var isExporting = false
    
    /// Observable state for UI
    @MainActor var progress: ExportProgress = ExportProgress()
    
    struct ExportProgress {
        var isExporting: Bool = false
        var currentIndex: Int = 0
        var totalCount: Int = 0
        var failedCount: Int = 0
        var currentFilename: String = ""
    }
    
    /// Start export with given jobs
    func startExport(
        assets: [PhotoAsset],
        recipes: [UUID: EditRecipe],
        settings: ExportSettings,
        localNodesByURL: [URL: [ColorNode]] = [:]
    ) async {
        guard let destination = settings.destinationFolder else { return }
        
        // Create jobs
        jobs = assets.map { asset in
            let recipe = recipes[asset.id] ?? EditRecipe()
            let localNodes = localNodesByURL[asset.url] ?? []
            return ExportJob(asset: asset, recipe: recipe, localNodes: localNodes, settings: settings)
        }
        
        let totalCount = jobs.count
        
        // Update progress
        await MainActor.run {
            progress = ExportProgress(
                isExporting: true,
                currentIndex: 0,
                totalCount: totalCount,
                failedCount: 0,
                currentFilename: ""
            )
        }
        
        isExporting = true
        
        // Process each job
        for (index, job) in jobs.enumerated() {
            guard isExporting else { break }
            
            var mutableJob = job
            
            await MainActor.run {
                progress.currentIndex = index + 1
                progress.currentFilename = job.asset.filename
            }
            
            mutableJob.status = .processing
            
            do {
                try await exportJob(mutableJob, to: destination)
                mutableJob.status = .completed
            } catch {
                mutableJob.status = .failed
                mutableJob.error = error.localizedDescription
                await MainActor.run {
                    progress.failedCount += 1
                }
            }
            
            jobs[index] = mutableJob
        }
        
        // Done
        isExporting = false
        await MainActor.run {
            progress.isExporting = false
        }
    }
    
    /// Cancel current export
    func cancel() async {
        isExporting = false
        currentTask?.cancel()
    }
    
    private func exportJob(_ job: ExportJob, to destination: URL) async throws {
        print("[Export] Starting export for: \(job.asset.filename)")

        // Determine output size and whether to use recipe resize
        let maxSize = job.settings.getMaxSize(customSize: job.settings.customSize)
        let useRecipeResize = job.settings.sizeOption.usesRecipeResize
        print("[Export] Max size: \(String(describing: maxSize)), useRecipeResize: \(useRecipeResize)")

        // Render with ImagePipeline
        guard let cgImage = await ImagePipeline.shared.renderForExport(
            for: job.asset,
            recipe: job.recipe,
            maxSize: maxSize,
            useRecipeResize: useRecipeResize,
            localNodes: job.localNodes
        ) else {
            print("[Export] ERROR: renderForExport returned nil")
            throw ExportError.renderFailed
        }
        
        print("[Export] Rendered image size: \(cgImage.width)x\(cgImage.height)")
        
        // Create output filename
        let originalName = job.asset.url.deletingPathExtension().lastPathComponent
        let outputName = "\(originalName)\(job.settings.filenameSuffix).jpg"
        let outputURL = destination.appendingPathComponent(outputName)
        
        print("[Export] Writing to: \(outputURL.path)")
        
        // Write JPG
        try writeJPG(cgImage, to: outputURL, quality: job.settings.quality)
        print("[Export] Success: \(outputName)")
    }
    
    private func writeJPG(_ image: CGImage, to url: URL, quality: Int) throws {
        // Create destination with sRGB color space
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            "public.jpeg" as CFString,
            1,
            nil
        ) else {
            throw ExportError.cannotCreateDestination
        }
        
        // Set options
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: Double(quality) / 100.0,
            kCGImagePropertyProfileName: "sRGB" as CFString
        ]
        
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else {
            throw ExportError.writeFailed
        }
    }
}

enum ExportError: LocalizedError {
    case renderFailed
    case cannotCreateDestination
    case writeFailed
    
    var errorDescription: String? {
        switch self {
        case .renderFailed:
            return "Failed to render image"
        case .cannotCreateDestination:
            return "Cannot create output file"
        case .writeFailed:
            return "Failed to write file"
        }
    }
}
