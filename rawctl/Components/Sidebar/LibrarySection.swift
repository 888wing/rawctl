//
//  LibrarySection.swift
//  rawctl
//
//  Library section of the sidebar (All Photos, Recent, Quick Collection)
//

import SwiftUI

/// Library section showing overview entries
struct LibrarySection: View {
    @ObservedObject var appState: AppState
    @State private var isExpanded = true
    @AppStorage("latent.ui.quietDarkroom") private var quietDarkroomEnabled = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 2) {
                // All Photos
                LibraryRow(
                    icon: "photo.on.rectangle",
                    title: "All Photos",
                    count: appState.catalog?.totalPhotos ?? appState.assets.count,
                    isSelected: !appState.isProjectMode && appState.activeSmartCollection == nil && !appState.isRecentImportsMode
                ) {
                    appState.showAllPhotosInLibrary()
                }

                // Recent Imports
                if AppFeatures.recentImportsEntryPointEnabled {
                    LibraryRow(
                        icon: "clock.arrow.circlepath",
                        title: "Recent Imports",
                        count: recentImportsCount,
                        isSelected: appState.isRecentImportsMode
                    ) {
                        appState.applyRecentImportsFilter(days: 7)
                    }
                }

                // Quick Collection (starred/favorited)
                LibraryRow(
                    icon: "star.fill",
                    title: "Quick Collection",
                    count: quickCollectionCount,
                    isSelected: isQuickCollectionActive
                ) {
                    appState.applySmartCollection(.fiveStars)
                }
            }
            .padding(.vertical, 4)
        } label: {
            sidebarSectionLabel("Library")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func sidebarSectionLabel(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(quietDarkroomEnabled ? QDFont.sectionLabel : .caption.bold())
                .foregroundColor(quietDarkroomEnabled ? QDColor.textTertiary : .secondary)
                .textCase(quietDarkroomEnabled ? .uppercase : nil)
            Spacer()
        }
    }

    private var recentImportsCount: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? .distantPast
        return appState.assets.filter { asset in
            guard let date = asset.metadata?.dateTime ?? asset.creationDate ?? asset.modificationDate else {
                return false
            }
            return date >= weekAgo
        }.count
    }

    private var quickCollectionCount: Int {
        appState.assets.filter { asset in
            (appState.recipes[asset.id]?.rating ?? 0) >= 5
        }.count
    }

    private var isQuickCollectionActive: Bool {
        appState.activeSmartCollection?.id == SmartCollection.fiveStars.id
    }
}

/// Single row in library section
struct LibraryRow: View {
    let icon: String
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    @AppStorage("latent.ui.quietDarkroom") private var quietDarkroomEnabled = true

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? (quietDarkroomEnabled ? QDColor.accent : .accentColor) : (quietDarkroomEnabled ? QDColor.textSecondary : .secondary))
                    .frame(width: 16)

                Text(title)
                    .font(quietDarkroomEnabled ? QDFont.sidebarRow : .system(size: 12))
                    .foregroundColor(isSelected ? (quietDarkroomEnabled ? QDColor.textPrimary : .accentColor) : (quietDarkroomEnabled ? QDColor.textSecondary : .primary))

                Spacer()

                Text("\(count)")
                    .font(.system(size: 10))
                    .foregroundColor(quietDarkroomEnabled ? QDColor.textTertiary : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(quietDarkroomEnabled ? QDColor.elevatedSurface : Color(white: 0.2))
                    .cornerRadius(4)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isSelected ? (quietDarkroomEnabled ? QDColor.selectedSurface : Color.accentColor.opacity(0.15)) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LibrarySection(appState: AppState())
        .frame(width: 220)
        .preferredColorScheme(.dark)
}
