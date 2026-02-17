//
//  NetworkErrorBanner.swift
//  rawctl
//
//  Top slide-in banner for network and recoverable errors
//

import SwiftUI

/// Top slide-in error banner with retry and dismiss actions
struct NetworkErrorBanner: View {
    let message: String
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void

    @State private var isVisible = false

    var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                // Error icon
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                // Message
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                // Retry button
                if let onRetry = onRetry {
                    Button {
                        onRetry()
                    } label: {
                        Text("Retry")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.red)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.white)
                            )
                    }
                    .buttonStyle(.plain)
                }

                // Dismiss button
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.white.opacity(0.2)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.red.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            )
            .padding(.horizontal, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }

}

// MARK: - View Modifier for Easy Integration

struct NetworkErrorBannerModifier: ViewModifier {
    @ObservedObject var errorHandler = ErrorHandler.shared

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content

            if let banner = errorHandler.currentBanner {
                NetworkErrorBanner(
                    message: banner.message,
                    onRetry: banner.retryAction,
                    onDismiss: { errorHandler.dismissBanner() }
                )
                .onAppear {
                    // Banner is shown via ErrorHandler state
                }
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: errorHandler.currentBanner?.id)
    }
}

extension View {
    func withNetworkErrorBanner() -> some View {
        modifier(NetworkErrorBannerModifier())
    }
}

// MARK: - Preview

#Preview {
    VStack {
        NetworkErrorBanner(
            message: "Unable to connect to server",
            onRetry: { print("Retry") },
            onDismiss: { print("Dismiss") }
        )
        .onAppear {
            // For preview, we need to show it
        }

        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(white: 0.1))
    .preferredColorScheme(.dark)
}

#Preview("In Context") {
    ZStack(alignment: .top) {
        Color(white: 0.1)

        VStack {
            // Simulated banner
            HStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Text("Network connection lost")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)

                Spacer()

                Button("Retry") {}
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white))
                    .buttonStyle(.plain)

                Button {} label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.red.opacity(0.9))
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()
        }
    }
    .preferredColorScheme(.dark)
}
