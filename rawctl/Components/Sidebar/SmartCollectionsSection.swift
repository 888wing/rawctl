//
//  SmartCollectionsSection.swift
//  rawctl
//
//  Smart collections section of the sidebar
//

import SwiftUI

/// Smart collections section
struct SmartCollectionsSection: View {
    @ObservedObject var appState: AppState
    @State private var isExpanded = true
    @State private var showCreateCollection = false

    var body: some View {
        DisclosureGroup("Smart Collections", isExpanded: $isExpanded) {
            VStack(spacing: 2) {
                ForEach(collections) { collection in
                    SmartCollectionRow(
                        collection: collection,
                        count: countFor(collection),
                        isSelected: appState.activeSmartCollection?.id == collection.id,
                        onSelect: {
                            appState.applySmartCollection(collection)
                        }
                    )
                }

                // Create Smart Collection button
                Button {
                    showCreateCollection = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 11))
                        Text("Create Smart Collection")
                            .font(.system(size: 11))
                        Spacer()
                    }
                    .foregroundColor(.accentColor)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var collections: [SmartCollection] {
        appState.catalog?.smartCollections ?? [
            .fiveStars,
            .picks,
            .rejects,
            .unrated,
            .edited
        ]
    }

    private func countFor(_ collection: SmartCollection) -> Int {
        collection.filter(assets: appState.assets, recipes: appState.recipes).count
    }
}

/// Single smart collection row
struct SmartCollectionRow: View {
    let collection: SmartCollection
    let count: Int
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: collection.icon)
                    .font(.system(size: 11))
                    .foregroundColor(iconColor)
                    .frame(width: 14)

                Text(collection.name)
                    .font(.system(size: 11))
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
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !collection.isBuiltIn {
                Button("Edit Collection...") {
                    // Edit
                }

                Divider()

                Button("Delete Collection", role: .destructive) {
                    // Delete
                }
            }
        }
    }

    private var iconColor: Color {
        if isSelected { return .accentColor }

        // Special colors for specific collections
        switch collection.name {
        case "5 Stars": return .yellow
        case "Picks": return .green
        case "Rejects": return .red
        default: return .secondary
        }
    }
}

#Preview {
    SmartCollectionsSection(appState: AppState())
        .frame(width: 220)
        .preferredColorScheme(.dark)
}
