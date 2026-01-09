//
//  EmptyStateView.swift
//  rawctl
//
//  Configurable empty state view with optional action
//

import SwiftUI

/// Style for empty state presentation
enum EmptyStateStyle {
    case standard  // System gray, neutral
    case branded   // Orange-yellow gradient for AI features
}

/// Configurable empty state view
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var action: (label: String, action: () -> Void)? = nil
    var style: EmptyStateStyle = .standard

    var body: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconBackground)
                    .frame(width: 64, height: 64)

                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(iconForeground)
            }

            // Text content
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            // Optional action button
            if let action = action {
                Button {
                    action.action()
                } label: {
                    HStack(spacing: 6) {
                        if style == .branded {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11))
                        }
                        Text(action.label)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(buttonTextColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(buttonBackground)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: 280)
        .padding(24)
    }

    // MARK: - Style Properties

    private var iconBackground: some ShapeStyle {
        switch style {
        case .standard:
            return AnyShapeStyle(Color(white: 0.15))
        case .branded:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [.orange.opacity(0.2), .yellow.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private var iconForeground: some ShapeStyle {
        switch style {
        case .standard:
            return AnyShapeStyle(Color.secondary)
        case .branded:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [.orange, .yellow],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private var buttonBackground: some ShapeStyle {
        switch style {
        case .standard:
            return AnyShapeStyle(Color.accentColor)
        case .branded:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [.orange, .yellow],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
    }

    private var buttonTextColor: Color {
        switch style {
        case .standard:
            return .white
        case .branded:
            return .black
        }
    }
}

// MARK: - Convenience Initializers

extension EmptyStateView {
    /// No photo selected state
    static var noPhotoSelected: EmptyStateView {
        EmptyStateView(
            icon: "photo",
            title: "No Photo Selected",
            subtitle: "Select a photo from the grid to start editing"
        )
    }

    /// No photos in folder state
    static func noPhotos(openFolder: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "photo.on.rectangle.angled",
            title: "No Photos",
            subtitle: "Open a folder containing RAW or JPEG files",
            action: ("Open Folder", openFolder)
        )
    }

    /// Not signed in state
    static func notSignedIn(signIn: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "person.crop.circle",
            title: "Sign In Required",
            subtitle: "Sign in to use AI features and manage credits",
            action: ("Sign In", signIn),
            style: .branded
        )
    }

    /// No credits state
    static func noCredits(buyCredits: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "sparkle",
            title: "No Credits",
            subtitle: "Purchase credits to use Nano Banana AI",
            action: ("Get Credits", buyCredits),
            style: .branded
        )
    }
}

// MARK: - Preview

#Preview("Standard Style") {
    VStack(spacing: 40) {
        EmptyStateView.noPhotoSelected

        EmptyStateView.noPhotos(openFolder: { print("Open folder") })
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(white: 0.1))
    .preferredColorScheme(.dark)
}

#Preview("Branded Style") {
    VStack(spacing: 40) {
        EmptyStateView.notSignedIn(signIn: { print("Sign in") })

        EmptyStateView.noCredits(buyCredits: { print("Buy credits") })
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(white: 0.1))
    .preferredColorScheme(.dark)
}
