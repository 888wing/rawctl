//
//  QuietPhotoCard.swift
//  rawctl
//
//  Photo-first thumbnail card used by the Quiet Darkroom grid.
//

import SwiftUI

struct QuietPhotoCard<Thumbnail: View, TopLeading: View, TopTrailing: View, HoverOverlay: View>: View {
    var filename: String
    var isSelected: Bool
    var isRejected: Bool = false
    var rating: Int = 0
    var formatLabel: String
    var isHovering: Bool
    var thumbnailHeight: CGFloat
    var thumbnail: Thumbnail
    var topLeading: TopLeading
    var topTrailing: TopTrailing
    var hoverOverlay: HoverOverlay

    init(
        filename: String,
        isSelected: Bool,
        isRejected: Bool = false,
        rating: Int = 0,
        formatLabel: String,
        isHovering: Bool,
        thumbnailHeight: CGFloat,
        @ViewBuilder thumbnail: () -> Thumbnail,
        @ViewBuilder topLeading: () -> TopLeading,
        @ViewBuilder topTrailing: () -> TopTrailing,
        @ViewBuilder hoverOverlay: () -> HoverOverlay
    ) {
        self.filename = filename
        self.isSelected = isSelected
        self.isRejected = isRejected
        self.rating = rating
        self.formatLabel = formatLabel
        self.isHovering = isHovering
        self.thumbnailHeight = thumbnailHeight
        self.thumbnail = thumbnail()
        self.topLeading = topLeading()
        self.topTrailing = topTrailing()
        self.hoverOverlay = hoverOverlay()
    }

    var body: some View {
        RoundedRectangle(cornerRadius: QDRadius.md, style: .continuous)
            .fill(QDColor.elevatedSurface)
            .overlay {
                thumbnail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .opacity(isRejected ? 0.48 : 1.0)
            }
            .overlay(alignment: .topLeading) {
                topLeading
                    .padding(QDSpace.sm)
            }
            .overlay(alignment: .topTrailing) {
                topTrailing
                    .padding(QDSpace.sm)
            }
            .overlay(alignment: .bottom) {
                if isHovering || isSelected {
                    metadataStrip
                }
            }
            .overlay(alignment: .bottom) {
                if isHovering {
                    hoverOverlay
                        .padding(.bottom, 34)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: QDRadius.md, style: .continuous)
                    .stroke(
                        isSelected ? QDColor.accentLine : (isHovering ? QDColor.divider.opacity(0.82) : .clear),
                        lineWidth: isSelected ? 1.2 : 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: QDRadius.md, style: .continuous))
            .frame(height: thumbnailHeight)
    }

    private var metadataStrip: some View {
        HStack(spacing: QDSpace.sm) {
            Text(stars)
                .font(QDFont.metadata)
                .foregroundStyle(rating > 0 ? QDColor.ratingMuted : QDColor.textTertiary)
                .frame(width: 48, alignment: .leading)

            Text(filename)
                .font(QDFont.metadata)
                .foregroundStyle(QDColor.textSecondary)
                .lineLimit(1)

            Spacer(minLength: QDSpace.sm)

            Text(formatLabel)
                .font(QDFont.metadata)
                .foregroundStyle(QDColor.textTertiary)
        }
        .padding(.horizontal, QDSpace.sm)
        .frame(height: 28)
        .background(
            LinearGradient(
                colors: [
                    QDColor.appBackground.opacity(0.0),
                    QDColor.appBackground.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var stars: String {
        guard rating > 0 else { return "—" }
        return String(repeating: "★", count: min(max(rating, 0), 5))
    }
}

struct QuietStatusChip: View {
    var title: String
    var color: Color

    var body: some View {
        Text(title)
            .font(QDFont.metadata)
            .foregroundStyle(color)
            .padding(.horizontal, QDSpace.sm)
            .frame(height: 22)
            .background(QDColor.appBackground.opacity(0.82), in: Capsule())
    }
}
