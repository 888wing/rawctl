//
//  BatchRatingSheet.swift
//  rawctl
//
//  Apply ratings/flags to multiple selected photos
//

import SwiftUI

/// Sheet for batch applying ratings and flags
struct BatchRatingSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let selectedAssets: [PhotoAsset]

    @State private var newRating: Int?
    @State private var newFlag: Flag?
    @State private var newColorLabel: ColorLabel?
    @State private var addTags: String = ""
    @State private var isApplying = false
    @State private var appliedCount = 0

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            optionsForm
            Divider()
            footerView
        }
        .frame(width: 500, height: 420)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("Batch Edit")
                .font(.title2.bold())
            Spacer()
            Text("\(selectedAssets.count) photos selected")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Form

    private var optionsForm: some View {
        Form {
            ratingSection
            flagSection
            colorSection
            tagsSection
        }
        .formStyle(.grouped)
        .padding()
    }

    private var ratingSection: some View {
        Section("Rating") {
            HStack(spacing: 12) {
                Button("Clear") { newRating = 0 }
                    .buttonStyle(.bordered)
                    .overlay(newRating == 0 ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(6)

                ForEach([1, 2, 3, 4, 5], id: \.self) { rating in
                    Button {
                        newRating = rating
                    } label: {
                        Text(String(repeating: "★", count: rating))
                            .foregroundColor(.yellow)
                    }
                    .buttonStyle(.bordered)
                    .overlay(newRating == rating ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(6)
                }

                Spacer()

                Button("Skip") { newRating = nil }
                    .font(.caption)
            }
        }
    }

    private var flagSection: some View {
        Section("Flag") {
            HStack(spacing: 12) {
                Button {
                    newFlag = .pick
                } label: {
                    Label("Pick", systemImage: "flag.fill")
                }
                .buttonStyle(.bordered)
                .tint(.green)
                .overlay(newFlag == .pick ? Color.green.opacity(0.2) : Color.clear)
                .cornerRadius(6)

                Button {
                    newFlag = .reject
                } label: {
                    Label("Reject", systemImage: "xmark.circle.fill")
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .overlay(newFlag == .reject ? Color.red.opacity(0.2) : Color.clear)
                .cornerRadius(6)

                Button("Unflag") { newFlag = .some(.none) }
                    .buttonStyle(.bordered)
                    .overlay(newFlag == .some(.none) ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(6)

                Spacer()

                Button("Skip") { newFlag = nil }
                    .font(.caption)
            }
        }
    }

    private var colorSection: some View {
        Section("Color Label") {
            HStack(spacing: 12) {
                ForEach(ColorLabel.allCases, id: \.self) { color in
                    ColorLabelButton(
                        color: color,
                        isSelected: newColorLabel == color,
                        action: { newColorLabel = color }
                    )
                }

                Spacer()

                Button("Skip") { newColorLabel = nil }
                    .font(.caption)
            }
        }
    }

    private var tagsSection: some View {
        Section("Tags") {
            TextField("Add tags (comma separated)", text: $addTags)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            if isApplying {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Applied to \(appliedCount)/\(selectedAssets.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Cancel") { dismiss() }
                .keyboardShortcut(.escape)

            Button("Apply Changes") { applyChanges() }
                .buttonStyle(.borderedProminent)
                .disabled(!hasChanges || isApplying)
                .keyboardShortcut(.return)
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Helpers

    private var hasChanges: Bool {
        newRating != nil || newFlag != nil || newColorLabel != nil || !addTags.isEmpty
    }

    private func applyChanges() {
        isApplying = true
        appliedCount = 0

        let tagsToAdd = addTags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        for asset in selectedAssets {
            var recipe = appState.recipes[asset.id] ?? EditRecipe()

            if let rating = newRating {
                recipe.rating = rating
            }

            if let flag = newFlag {
                recipe.flag = flag
            }

            if let color = newColorLabel {
                recipe.colorLabel = color
            }

            if !tagsToAdd.isEmpty {
                for tag in tagsToAdd {
                    if !recipe.tags.contains(tag) {
                        recipe.tags.append(tag)
                    }
                }
            }

            appState.recipes[asset.id] = recipe
            appliedCount += 1
        }

        appState.saveCurrentRecipe()
        isApplying = false
        dismiss()
    }
}

/// Color label selection button
struct ColorLabelButton: View {
    let color: ColorLabel
    let isSelected: Bool
    let action: () -> Void

    private var fillColor: Color {
        let rgb = color.color
        return Color(red: rgb.r, green: rgb.g, blue: rgb.b)
    }

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(fillColor)
                .frame(width: 24, height: 24)
                .overlay(selectionOverlay)
        }
        .buttonStyle(.plain)
    }

    private var selectionOverlay: some View {
        Circle()
            .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
    }
}

#Preview {
    BatchRatingSheet(
        appState: AppState(),
        selectedAssets: []
    )
    .preferredColorScheme(.dark)
}
