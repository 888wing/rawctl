//
//  RenderQueue.swift
//  rawctl
//
//  Priority-based render queue for efficient image processing
//

import Foundation
import AppKit

/// Priority-based render queue for managing image rendering tasks
actor RenderQueue {
    static let shared = RenderQueue()
    
    // MARK: - Priority Levels
    
    enum Priority: Int, Comparable {
        case low = 0        // Background prefetch
        case normal = 1     // Adjacent photos
        case high = 2       // Visible thumbnails
        case urgent = 3     // Currently selected photo
        
        static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    // MARK: - Render Job
    
    struct RenderJob: Identifiable {
        let id: UUID = UUID()
        let assetId: UUID
        let asset: PhotoAsset
        let recipe: EditRecipe
        let priority: Priority
        let maxSize: CGFloat
        let completion: @Sendable (NSImage?) async -> Void
        let createdAt: Date = Date()
    }
    
    // MARK: - State
    
    private var queue: [RenderJob] = []
    private var activeJobs: Set<UUID> = []
    private let maxConcurrent = 2
    private var isProcessing = false
    
    // MARK: - Public API
    
    /// Enqueue a render job with priority
    func enqueue(
        asset: PhotoAsset,
        recipe: EditRecipe,
        priority: Priority,
        maxSize: CGFloat = 1600,
        completion: @escaping @Sendable (NSImage?) async -> Void
    ) {
        // Cancel existing jobs for same asset (superseded)
        queue.removeAll { $0.assetId == asset.id }
        
        let job = RenderJob(
            assetId: asset.id,
            asset: asset,
            recipe: recipe,
            priority: priority,
            maxSize: maxSize,
            completion: completion
        )
        
        // Insert by priority (higher priority first)
        let insertIndex = queue.firstIndex { $0.priority < job.priority } ?? queue.endIndex
        queue.insert(job, at: insertIndex)
        
        processNextIfNeeded()
    }
    
    /// Cancel all jobs for a specific asset
    func cancel(for assetId: UUID) {
        queue.removeAll { $0.assetId == assetId }
    }
    
    /// Cancel all pending jobs
    func cancelAll() {
        queue.removeAll()
    }
    
    /// Get queue status for debugging
    var queueStatus: (pending: Int, active: Int) {
        (queue.count, activeJobs.count)
    }
    
    // MARK: - Processing
    
    private func processNextIfNeeded() {
        guard activeJobs.count < maxConcurrent, !queue.isEmpty else { return }
        
        let job = queue.removeFirst()
        activeJobs.insert(job.id)
        
        Task {
            let result = await ImagePipeline.shared.renderPreview(
                for: job.asset,
                recipe: job.recipe,
                maxSize: job.maxSize
            )
            
            // Call completion
            await job.completion(result)
            
            // Mark as done and process next
            activeJobs.remove(job.id)
            processNextIfNeeded()
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Request urgent render (for currently selected photo)
    func renderUrgent(
        asset: PhotoAsset,
        recipe: EditRecipe,
        maxSize: CGFloat = 1600
    ) async -> NSImage? {
        // Cancel lower priority jobs for this asset
        cancel(for: asset.id)
        
        // For urgent requests, bypass queue and render directly
        return await ImagePipeline.shared.renderPreview(
            for: asset,
            recipe: recipe,
            maxSize: maxSize
        )
    }
    
    /// Prefetch adjacent photos at low priority
    func prefetch(assets: [PhotoAsset], recipes: [UUID: EditRecipe]) {
        for asset in assets {
            let recipe = recipes[asset.id] ?? EditRecipe()
            enqueue(
                asset: asset,
                recipe: recipe,
                priority: .low,
                maxSize: 800
            ) { _ in
                // Prefetch completion - just cache, no callback needed
            }
        }
    }
}

// MARK: - Thumbnail Priority Queue

extension ThumbnailService {
    /// Priority queue for thumbnail loading
    actor ThumbnailQueue {
        private var priorityAssets: Set<UUID> = []
        
        func setPriority(_ assetIds: [UUID]) {
            priorityAssets = Set(assetIds)
        }
        
        func isPriority(_ assetId: UUID) -> Bool {
            priorityAssets.contains(assetId)
        }
        
        func clear() {
            priorityAssets.removeAll()
        }
    }
}
