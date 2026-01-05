//
//  ExportProgressView.swift
//  rawctl
//
//  Shows active export progress with cancel option
//

import SwiftUI
import UserNotifications

/// Floating export progress indicator
struct ExportProgressView: View {
    @ObservedObject var appState: AppState
    @State private var progress: ExportService.ExportProgress = ExportService.ExportProgress()
    @State private var updateTask: Task<Void, Never>?

    var body: some View {
        if progress.isExporting {
            HStack(spacing: 12) {
                // Progress indicator
                CircularProgressView(progress: progressValue)
                    .frame(width: 32, height: 32)

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text("Exporting...")
                        .font(.caption.bold())

                    Text(progress.currentFilename)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Text("\(progress.currentIndex) of \(progress.totalCount)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Cancel button
                Button {
                    Task {
                        await ExportService.shared.cancel()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Cancel export")
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .shadow(radius: 5)
            .frame(width: 280)
        }
    }

    private var progressValue: Double {
        guard progress.totalCount > 0 else { return 0 }
        return Double(progress.currentIndex) / Double(progress.totalCount)
    }
}

/// Circular progress indicator
struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 3)

            // Progress circle
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)

            // Percentage
            Text("\(Int(progress * 100))")
                .font(.system(size: 9, weight: .bold).monospacedDigit())
                .foregroundColor(.primary)
        }
    }
}

/// Export queue manager for background batch exports
actor ExportQueueManager {
    static let shared = ExportQueueManager()

    private var queue: [ExportQueueItem] = []
    private var isProcessing = false

    struct ExportQueueItem: Identifiable {
        let id: UUID = UUID()
        let assets: [PhotoAsset]
        let recipes: [UUID: EditRecipe]
        let preset: ExportPreset
        let destination: URL
        let organization: ExportOrganizationMode
        var status: QueueStatus = .pending
        var completedCount: Int = 0
        var failedCount: Int = 0
        var errorMessages: [String] = []

        enum QueueStatus {
            case pending
            case processing
            case completed
            case failed
        }
    }

    /// Add export job to queue
    func enqueue(
        assets: [PhotoAsset],
        recipes: [UUID: EditRecipe],
        preset: ExportPreset,
        destination: URL,
        organization: ExportOrganizationMode
    ) {
        let item = ExportQueueItem(
            assets: assets,
            recipes: recipes,
            preset: preset,
            destination: destination,
            organization: organization
        )
        queue.append(item)

        if !isProcessing {
            Task {
                await processQueue()
            }
        }
    }

    /// Process queue items
    private func processQueue() async {
        isProcessing = true

        while let index = queue.firstIndex(where: { $0.status == .pending }) {
            queue[index].status = .processing

            let item = queue[index]

            do {
                try await processItem(item)
                queue[index].status = .completed

                // Notify completion
                await notifyCompletion(item)
            } catch {
                queue[index].status = .failed
                queue[index].failedCount += 1
                queue[index].errorMessages.append(error.localizedDescription)
            }
        }

        isProcessing = false
    }

    private func processItem(_ item: ExportQueueItem) async throws {
        for asset in item.assets {
            let recipe = item.recipes[asset.id] ?? EditRecipe()

            // Determine target folder
            let targetFolder = determineFolder(
                for: asset,
                recipe: recipe,
                preset: item.preset,
                organization: item.organization,
                base: item.destination
            )

            // Create folder if needed
            try FileManager.default.createDirectory(
                at: targetFolder,
                withIntermediateDirectories: true
            )

            // Render and export
            let maxSizeValue = CGFloat(item.preset.maxSize ?? 4000)
            if let image = await ImagePipeline.shared.renderPreview(
                for: asset,
                recipe: recipe,
                maxSize: maxSizeValue
            ) {
                let outputName = asset.url.deletingPathExtension().lastPathComponent + ".jpg"
                let outputURL = targetFolder.appendingPathComponent(outputName)

                if let tiffData = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let jpegData = bitmap.representation(
                       using: NSBitmapImageRep.FileType.jpeg,
                       properties: [NSBitmapImageRep.PropertyKey.compressionFactor: Double(item.preset.quality) / 100.0]
                   ) {
                    try jpegData.write(to: outputURL)
                }
            }
        }
    }

    private func determineFolder(
        for asset: PhotoAsset,
        recipe: EditRecipe,
        preset: ExportPreset,
        organization: ExportOrganizationMode,
        base: URL
    ) -> URL {
        switch organization {
        case .flat:
            return base

        case .byRating:
            let rating = recipe.rating
            let folderName = rating > 0 ? "\(rating)-stars" : "unrated"
            return base.appendingPathComponent(folderName)

        case .byDate:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let folderName = formatter.string(from: asset.creationDate ?? Date())
            return base.appendingPathComponent(folderName)

        case .byColor:
            return base.appendingPathComponent(recipe.colorLabel.displayName)

        case .byFlag:
            switch recipe.flag {
            case .pick: return base.appendingPathComponent("Picks")
            case .reject: return base.appendingPathComponent("Rejects")
            case .none: return base.appendingPathComponent("Unflagged")
            }
        }
    }

    private func notifyCompletion(_ item: ExportQueueItem) async {
        let content = UNMutableNotificationContent()
        content.title = "Export Complete"
        content.body = "\(item.assets.count) photos exported"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Get queue status
    var queueStatus: [ExportQueueItem] {
        queue
    }

    /// Clear completed items
    func clearCompleted() {
        queue.removeAll { $0.status == .completed }
    }
}

#Preview {
    VStack {
        ExportProgressView(appState: AppState())
            .padding()
    }
    .preferredColorScheme(.dark)
}
