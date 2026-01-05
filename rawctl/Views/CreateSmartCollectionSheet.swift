//
//  CreateSmartCollectionSheet.swift
//  rawctl
//
//  Sheet for creating a new smart collection
//

import SwiftUI

/// Sheet for creating a new smart collection
struct CreateSmartCollectionSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var collectionName: String = ""
    @State private var icon: String = "folder.badge.gearshape"
    @State private var rules: [FilterRule] = []
    @State private var ruleLogic: RuleLogic = .and

    // Available icons
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
                Text("Create Smart Collection")
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

                Button("Create Collection") {
                    createCollection()
                }
                .buttonStyle(.borderedProminent)
                .disabled(collectionName.isEmpty || rules.isEmpty)
                .keyboardShortcut(.return)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 500, height: 450)
    }

    private func createCollection() {
        let collection = SmartCollection(
            name: collectionName,
            icon: icon,
            rules: rules,
            ruleLogic: ruleLogic,
            isBuiltIn: false
        )

        if var catalog = appState.catalog {
            catalog.addSmartCollection(collection)
            appState.catalog = catalog

            // Save catalog
            Task {
                let service = CatalogService(catalogPath: CatalogService.defaultCatalogPath)
                try? await service.save(catalog)
            }
        }

        dismiss()
    }
}

/// Single rule row in the form
struct RuleRow: View {
    @Binding var rule: FilterRule
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Picker("Field", selection: $rule.field) {
                ForEach(FilterField.allCases, id: \.self) { field in
                    Text(field.displayName).tag(field)
                }
            }
            .frame(width: 120)

            Picker("Operation", selection: $rule.operation) {
                ForEach(FilterOperation.allCases, id: \.self) { op in
                    Text(op.displayName).tag(op)
                }
            }
            .frame(width: 100)

            TextField("Value", text: $rule.value)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)

            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    CreateSmartCollectionSheet(appState: AppState())
        .preferredColorScheme(.dark)
}
