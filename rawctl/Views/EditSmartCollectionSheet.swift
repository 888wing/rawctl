//
//  EditSmartCollectionSheet.swift
//  rawctl
//
//  Sheet for editing an existing smart collection
//

import SwiftUI

/// Sheet for editing a smart collection
struct EditSmartCollectionSheet: View {
    @ObservedObject var appState: AppState
    let collection: SmartCollection
    @Environment(\.dismiss) private var dismiss

    @State private var collectionName: String = ""
    @State private var icon: String = "folder.badge.gearshape"
    @State private var rules: [FilterRule] = []
    @State private var ruleLogic: RuleLogic = .and
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""

    // Available icons (same as CreateSmartCollectionSheet)
    private let icons = [
        "folder.badge.gearshape",
        "star.fill",
        "flag.fill",
        "heart.fill",
        "checkmark.circle.fill",
        "tag.fill",
        "photo.stack.fill"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Smart Collection")
                    .font(.title2.bold())
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Form
            Form {
                Section("Collection Details") {
                    TextField("Collection Name", text: $collectionName)
                        .textFieldStyle(.roundedBorder)

                    Picker("Icon", selection: $icon) {
                        ForEach(icons, id: \.self) { iconName in
                            Image(systemName: iconName)
                                .tag(iconName)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Match") {
                    Picker("Photos that match", selection: $ruleLogic) {
                        Text("All of the following").tag(RuleLogic.and)
                        Text("Any of the following").tag(RuleLogic.or)
                    }
                }

                Section("Rules") {
                    ForEach(rules.indices, id: \.self) { index in
                        RuleRow(rule: $rules[index]) {
                            rules.remove(at: index)
                        }
                    }

                    Button {
                        rules.append(FilterRule(field: .rating, operation: .greaterThanOrEqual, value: "4"))
                    } label: {
                        Label("Add Rule", systemImage: "plus.circle")
                    }
                }
            }
            .formStyle(.grouped)
            .padding()

            Divider()

            // Footer
            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button("Save Changes") {
                    saveCollection()
                }
                .buttonStyle(.borderedProminent)
                .disabled(collectionName.isEmpty || rules.isEmpty)
                .keyboardShortcut(.return)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 500, height: 450)
        .alert("Save Error", isPresented: $showSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveErrorMessage)
        }
        .onAppear {
            // Pre-populate with existing collection values
            collectionName = collection.name
            icon = collection.icon
            rules = collection.rules
            ruleLogic = collection.ruleLogic
        }
    }

    private func saveCollection() {
        // Create updated collection with same ID
        let updatedCollection = SmartCollection(
            id: collection.id,  // Keep the same ID
            name: collectionName,
            icon: icon,
            rules: rules,
            ruleLogic: ruleLogic,
            sortOrder: collection.sortOrder,  // Keep existing sort order
            isBuiltIn: false
        )

        if var catalog = appState.catalog {
            catalog.updateSmartCollection(updatedCollection)
            appState.catalog = catalog

            // Update active collection if it's the one being edited
            if appState.activeSmartCollection?.id == collection.id {
                appState.activeSmartCollection = updatedCollection
            }

            // Save catalog
            Task {
                do {
                    let service = CatalogService(catalogPath: CatalogService.defaultCatalogPath)
                    try await service.save(catalog)
                } catch {
                    await MainActor.run {
                        saveErrorMessage = "Failed to save: \(error.localizedDescription)"
                        showSaveError = true
                    }
                    return
                }
            }
        }

        dismiss()
    }
}

#Preview {
    EditSmartCollectionSheet(
        appState: AppState(),
        collection: SmartCollection(
            name: "Test Collection",
            icon: "star.fill",
            rules: [FilterRule(field: .rating, operation: .greaterThanOrEqual, value: "4")],
            ruleLogic: .and,
            isBuiltIn: false
        )
    )
    .preferredColorScheme(.dark)
}
