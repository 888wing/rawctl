//
//  ThumbnailHoverBar.swift
//  rawctl
//
//  Quick rating/flag controls shown on thumbnail hover
//

import SwiftUI

/// Quick action bar shown when hovering over a thumbnail
struct ThumbnailHoverBar: View {
    let rating: Int
    let flag: Flag
    let onRatingChange: (Int) -> Void
    let onFlagChange: (Flag) -> Void
    
    var body: some View {
        HStack(spacing: 2) {
            // Rating stars (compact)
            HStack(spacing: 1) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        // Toggle: if already this rating, clear it
                        onRatingChange(star == rating ? 0 : star)
                    } label: {
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.system(size: 10))
                            .foregroundStyle(star <= rating ? .yellow : .white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Divider()
                .frame(height: 12)
                .padding(.horizontal, 4)
            
            // Flag buttons
            HStack(spacing: 4) {
                // Pick
                Button {
                    onFlagChange(flag == .pick ? .none : .pick)
                } label: {
                    Image(systemName: flag == .pick ? "flag.fill" : "flag")
                        .font(.system(size: 10))
                        .foregroundStyle(flag == .pick ? .green : .white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Pick (P)")
                
                // Reject
                Button {
                    onFlagChange(flag == .reject ? .none : .reject)
                } label: {
                    Image(systemName: flag == .reject ? "xmark.circle.fill" : "xmark.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(flag == .reject ? .red : .white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Reject (X)")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.black.opacity(0.7))
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.1), lineWidth: 0.5)
                )
        )
    }
}

/// Overlay modifier for thumbnails
struct ThumbnailHoverOverlay: ViewModifier {
    let isHovered: Bool
    let rating: Int
    let flag: Flag
    let onRatingChange: (Int) -> Void
    let onFlagChange: (Flag) -> Void
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isHovered {
                    ThumbnailHoverBar(
                        rating: rating,
                        flag: flag,
                        onRatingChange: onRatingChange,
                        onFlagChange: onFlagChange
                    )
                    .padding(.bottom, 6)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

extension View {
    func thumbnailHoverBar(
        isHovered: Bool,
        rating: Int,
        flag: Flag,
        onRatingChange: @escaping (Int) -> Void,
        onFlagChange: @escaping (Flag) -> Void
    ) -> some View {
        modifier(ThumbnailHoverOverlay(
            isHovered: isHovered,
            rating: rating,
            flag: flag,
            onRatingChange: onRatingChange,
            onFlagChange: onFlagChange
        ))
    }
}

#Preview {
    VStack(spacing: 20) {
        // Sample thumbnail with hover bar
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 150, height: 100)
            
            Text("Photo")
                .foregroundColor(.secondary)
        }
        .thumbnailHoverBar(
            isHovered: true,
            rating: 3,
            flag: .pick,
            onRatingChange: { print("Rating: \($0)") },
            onFlagChange: { print("Flag: \($0)") }
        )
        
        // Standalone bar
        ThumbnailHoverBar(
            rating: 0,
            flag: .none,
            onRatingChange: { _ in },
            onFlagChange: { _ in }
        )
        
        ThumbnailHoverBar(
            rating: 5,
            flag: .reject,
            onRatingChange: { _ in },
            onFlagChange: { _ in }
        )
    }
    .padding()
    .preferredColorScheme(.dark)
}
