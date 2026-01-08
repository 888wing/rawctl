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
    @State private var collectionToEdit: SmartCollection?
    @State private var showDeleteConfirmation = false
    @State private var collectionToDelete: SmartCollection?

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
                        },
                        onEdit: {
                            collectionToEdit = collection
                        },
                        onDelete: {
                            collectionToDelete = collection
                            showDeleteConfirmation = true
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
        .sheet(isPresented: $showCreateCollection) {
            CreateSmartCollectionSheet(appState: appState)
        }
        .sheet(item: $collectionToEdit) { collection in
            EditSmartCollectionSheet(appState: appState, collection: collection)
        }
        .alert("Delete Collection", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteCollection()
            }
        } message: {
            if let collection = collectionToDelete {
                Text("Are you sure you want to delete \"\(collection.name)\"? This cannot be undone.")
            }
        }
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

    private func deleteCollection() {
        guard let collection = collectionToDelete else { return }

        // Clear active collection if it's being deleted
        if appState.activeSmartCollection?.id == collection.id {
            appState.applySmartCollection(nil)
        }

        // Remove from catalog
        if var catalog = appState.catalog {
            catalog.removeSmartCollection(collection.id)
            appState.catalog = catalog

            // Save catalog
            Task {
                do {
                    let service = CatalogService(catalogPath: CatalogService.defaultCatalogPath)
                    try await service.save(catalog)
                } catch {
                    print("[SmartCollectionsSection] Failed to save catalog: \(error)")
                }
            }
        }

        collectionToDelete = nil
    }
}

/// Single smart collection row
struct SmartCollectionRow: View {
    let collection: SmartCollection
    let count: Int
    let isSelected: Bool
    let onSelect: () -> Void
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

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
                    onEdit?()
                }

                Divider()

                Button("Delete Collection", role: .destructive) {
                    onDelete?()
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
