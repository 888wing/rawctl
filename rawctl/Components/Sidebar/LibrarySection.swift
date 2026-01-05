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

    var body: some View {
        DisclosureGroup("Library", isExpanded: $isExpanded) {
            VStack(spacing: 2) {
                // All Photos
                LibraryRow(
                    icon: "photo.on.rectangle",
                    title: "All Photos",
                    count: appState.catalog?.totalPhotos ?? appState.assets.count,
                    isSelected: !appState.isProjectMode && appState.activeSmartCollection == nil
                ) {
                    appState.clearProjectSelection()
                }

                // Recent Imports
                LibraryRow(
                    icon: "clock.arrow.circlepath",
                    title: "Recent Imports",
                    count: recentImportsCount,
                    isSelected: false
                ) {
                    // TODO: Show recent imports
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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var recentImportsCount: Int {
        // Photos imported in last 7 days
        guard let catalog = appState.catalog else { return 0 }
        let weekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        return catalog.projects
            .filter { $0.createdAt > weekAgo }
            .reduce(0) { $0 + $1.totalPhotos }
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

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 16)

                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .accentColor : .primary)

                Spacer()

                Text("\(count)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(white: 0.2))
                    .cornerRadius(4)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
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
