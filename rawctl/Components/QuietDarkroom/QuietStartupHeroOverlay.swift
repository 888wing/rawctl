//
//  QuietStartupHeroOverlay.swift
//  rawctl
//
//  Launch-time hero photo onboarding surface for the Quiet Darkroom shell.
//

import SwiftUI

struct QuietStartupHeroOverlay: View {
    let hero: AppState.StartupHeroState

    private var displayFilename: String {
        let pathExtension = (hero.filename as NSString).pathExtension
        guard !pathExtension.isEmpty else { return hero.filename }
        return (hero.filename as NSString).deletingPathExtension
    }

    var body: some View {
        HStack(spacing: QDSpace.xl) {
            Group {
                if let preview = hero.preview {
                    Image(nsImage: preview)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [
                                QDColor.selectedSurface.opacity(0.9),
                                QDColor.elevatedSurface
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        ProgressView()
                            .tint(QDColor.accent)
                    }
                }
            }
            .frame(width: 232, height: 148)
            .clipShape(RoundedRectangle(cornerRadius: QDRadius.lg, style: .continuous))

            VStack(alignment: .leading, spacing: QDSpace.sm) {
                Text(hero.sourceTitle.uppercased())
                    .font(QDFont.metadata)
                    .foregroundStyle(QDColor.textTertiary)
                    .tracking(0.8)

                Text(displayFilename)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(QDColor.textPrimary)
                    .lineLimit(1)

                Text(hero.isReady ? "Darkroom is warm. Open Edit when you're ready." : "Preparing preview, edits, and detail render.")
                    .font(QDFont.body)
                    .foregroundStyle(QDColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: QDSpace.sm) {
                    Circle()
                        .fill(hero.isReady ? QDColor.successMuted : QDColor.accent)
                        .frame(width: 8, height: 8)

                    Text(hero.isReady ? "Ready to edit" : "Warming launch preview")
                        .font(QDFont.metadata)
                        .foregroundStyle(QDColor.textSecondary)
                }
            }

            Spacer(minLength: QDSpace.xl)
        }
        .padding(QDSpace.xxl)
        .frame(maxWidth: 760, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: QDRadius.xl, style: .continuous)
                .fill(QDColor.panelBackground.opacity(0.96))
        )
        .overlay {
            RoundedRectangle(cornerRadius: QDRadius.xl, style: .continuous)
                .stroke(QDColor.divider.opacity(0.72), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.32), radius: 28, x: 0, y: 18)
        .allowsHitTesting(false)
    }
}
