//
//  NanoBananaProgressView.swift
//  rawctl
//
//  Progress overlay for Nano Banana AI processing
//

import SwiftUI

/// Progress overlay shown during Nano Banana processing
struct NanoBananaProgressView: View {
    @ObservedObject var service: NanoBananaService
    let onCancel: () -> Void
    let onDismiss: () -> Void
    
    @State private var animationPhase: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            // Content card
            VStack(spacing: 20) {
                // Icon with animation
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 32))
                        .foregroundColor(.accentColor)
                        .symbolEffect(.pulse, options: .repeating, isActive: service.state.isActive)
                }
                
                // Status text
                VStack(spacing: 8) {
                    Text(statusTitle)
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text(statusSubtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                // Progress indicator
                progressIndicator
                
                // Action button
                actionButton
            }
            .padding(32)
            .frame(width: 320)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .shadow(radius: 20)
        }
    }
    
    // MARK: - Status Properties
    
    private var iconName: String {
        switch service.state {
        case .idle:
            return "sparkles"
        case .uploading:
            return "arrow.up.circle"
        case .processing:
            return "wand.and.stars"
        case .downloading:
            return "arrow.down.circle"
        case .complete:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }
    
    private var statusTitle: String {
        switch service.state {
        case .idle:
            return "Ready"
        case .uploading:
            return "Uploading..."
        case .processing:
            return "Enhancing..."
        case .downloading:
            return "Downloading..."
        case .complete:
            return "Complete!"
        case .failed:
            return "Failed"
        }
    }
    
    private var statusSubtitle: String {
        switch service.state {
        case .idle:
            return "Preparing to process"
        case .uploading(let progress):
            return "Sending image to server (\(Int(progress * 100))%)"
        case .processing(let progress):
            return "AI is working its magic (\(progress)%)"
        case .downloading:
            return "Fetching enhanced image"
        case .complete(let url):
            return url.lastPathComponent
        case .failed(let error):
            return error
        }
    }
    
    // MARK: - Progress Indicator
    
    @ViewBuilder
    private var progressIndicator: some View {
        switch service.state {
        case .uploading(let progress):
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(width: 200)
            
        case .processing(let progress):
            VStack(spacing: 8) {
                // Animated processing bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(white: 0.2))
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.accentColor, .purple, .accentColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * CGFloat(progress) / 100)
                    }
                }
                .frame(height: 6)
                .frame(width: 200)
                
                Text("\(progress)%")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
        case .downloading:
            ProgressView()
                .progressViewStyle(.circular)
            
        case .complete:
            Image(systemName: "checkmark")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.green)
            
        case .failed:
            Image(systemName: "xmark")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.red)
            
        default:
            EmptyView()
        }
    }
    
    // MARK: - Action Button
    
    @ViewBuilder
    private var actionButton: some View {
        switch service.state {
        case .uploading, .processing, .downloading:
            Button(role: .destructive) {
                onCancel()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                    Text("Cancel")
                }
                .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.bordered)
            
        case .complete:
            Button {
                onDismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                    Text("Done")
                }
                .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            
        case .failed:
            HStack(spacing: 12) {
                Button(role: .destructive) {
                    onDismiss()
                } label: {
                    Text("Close")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.bordered)
            }
            
        default:
            EmptyView()
        }
    }
}

// MARK: - Resolution Picker

/// Popover for selecting Nano Banana resolution
struct NanoBananaResolutionPicker: View {
    @ObservedObject var accountService = AccountService.shared
    let onSelect: (NanoBananaResolution) -> Void
    let onBuyCredits: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.accentColor)
                Text("Nano Banana")
                    .font(.system(size: 13, weight: .semibold))
                
                Spacer()
                
                // Credits badge
                HStack(spacing: 4) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 9))
                    Text("\(accountService.creditsBalance?.totalRemaining ?? 0)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(white: 0.15))
                .cornerRadius(10)
            }
            
            Divider()
            
            // Resolution options
            VStack(spacing: 4) {
                ForEach(NanoBananaResolution.allCases) { resolution in
                    ResolutionRow(
                        resolution: resolution,
                        isEnabled: canAfford(resolution),
                        onSelect: { onSelect(resolution) }
                    )
                }
            }
            
            // Buy more credits
            if (accountService.creditsBalance?.totalRemaining ?? 0) < 6 {
                Divider()
                
                Button {
                    onBuyCredits()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                        Text("Get More Credits")
                            .font(.system(size: 12))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
            }
        }
        .padding(12)
        .frame(width: 240)
    }
    
    private func canAfford(_ resolution: NanoBananaResolution) -> Bool {
        (accountService.creditsBalance?.totalRemaining ?? 0) >= resolution.credits
    }
}

/// Single resolution row
private struct ResolutionRow: View {
    let resolution: NanoBananaResolution
    let isEnabled: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(resolution.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isEnabled ? .primary : .secondary)
                    
                    Text("\(resolution.maxPixels)px max")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Credits cost
                HStack(spacing: 3) {
                    Text("\(resolution.credits)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                    Image(systemName: "sparkle")
                        .font(.system(size: 9))
                }
                .foregroundColor(isEnabled ? .accentColor : .secondary.opacity(0.5))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(white: isEnabled ? 0.12 : 0.08))
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

// MARK: - Preview

#Preview("Progress - Uploading") {
    let service = NanoBananaService.shared
    return NanoBananaProgressView(
        service: service,
        onCancel: {},
        onDismiss: {}
    )
    .preferredColorScheme(.dark)
    .task {
        await MainActor.run {
            service.state = .uploading(progress: 0.45)
        }
    }
}

#Preview("Progress - Processing") {
    let service = NanoBananaService.shared
    return NanoBananaProgressView(
        service: service,
        onCancel: {},
        onDismiss: {}
    )
    .preferredColorScheme(.dark)
    .task {
        await MainActor.run {
            service.state = .processing(progress: 67)
        }
    }
}

#Preview("Resolution Picker") {
    NanoBananaResolutionPicker(
        onSelect: { _ in },
        onBuyCredits: {}
    )
    .preferredColorScheme(.dark)
}
