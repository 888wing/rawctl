//
//  SmartExportSheet.swift
//  rawctl
//
//  Smart export with preset selection and auto-categorization
//

import SwiftUI

/// Organization mode for exported files
enum ExportOrganizationMode: String, CaseIterable {
    case flat = "Flat (No folders)"
    case byRating = "By Rating (5-stars, 4-stars...)"
    case byDate = "By Date (YYYY-MM-DD)"
    case byColor = "By Color Label"
    case byFlag = "Picks / Rejects"

    var icon: String {
        switch self {
        case .flat: return "folder"
        case .byRating: return "star"
        case .byDate: return "calendar"
        case .byColor: return "paintpalette"
        case .byFlag: return "flag"
        }
    }
}

/// Smart export with presets and organization
struct SmartExportSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let assetsToExport: [PhotoAsset]

    @State private var selectedPreset: ExportPreset?
    @State private var destinationFolder: URL?
    @State private var organizationMode: ExportOrganizationMode = .byRating
    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    @State private var exportedCount = 0
    @State private var showPresetEditor = false
    @State private var showFolderPicker = false
    @State private var failedExports: [String] = []

    private var presets: [ExportPreset] {
        appState.catalog?.exportPresets ?? defaultPresets
    }

    private var defaultPresets: [ExportPreset] {
        [.clientPreview, .webGallery, .fullQuality, .socialMedia]
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            contentView
            Divider()
            footerView
        }
        .frame(width: 550, height: 580)
        .sheet(isPresented: $showPresetEditor) {
            ExportPresetEditor(appState: appState) { preset in
                if var catalog = appState.catalog {
                    catalog.addExportPreset(preset)
                    appState.catalog = catalog
                }
                selectedPreset = preset
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Export Photos")
                    .font(.title2.bold())

                Text("\(assetsToExport.count) photos selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                showPresetEditor = true
            } label: {
                Label("New Preset", systemImage: "plus")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Content

    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                presetSelectionSection
                destinationSection
                organizationSection
                summarySection
            }
            .padding()
        }
    }

    private var presetSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Preset")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(presets) { preset in
                    PresetCard(
                        preset: preset,
                        isSelected: selectedPreset?.id == preset.id,
                        onSelect: { selectedPreset = preset }
                    )
                }
            }
        }
    }

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Destination")
                .font(.headline)

            HStack {
                if let folder = destinationFolder {
                    Label(folder.lastPathComponent, systemImage: "folder.fill")
                        .lineLimit(1)
                } else {
                    Text("No folder selected")
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Choose...") {
                    selectDestinationFolder()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    private var organizationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Organization")
                .font(.headline)

            Picker("Organize files", selection: $organizationMode) {
                ForEach(ExportOrganizationMode.allCases, id: \.self) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summary")
                .font(.headline)

            if let preset = selectedPreset {
                VStack(alignment: .leading, spacing: 4) {
                    summaryRow("Format", value: "JPEG")
                    summaryRow("Quality", value: "\(preset.quality)%")
                    summaryRow("Max Size", value: preset.maxSize.map { "\($0)px" } ?? "Original")
                    summaryRow("Color Space", value: preset.colorSpace)
                    summaryRow("Watermark", value: preset.addWatermark ? "Yes" : "No")
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            } else {
                Text("Select a preset to see export settings")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func summaryRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.caption)
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            if isExporting {
                ProgressView(value: exportProgress)
                    .frame(width: 200)

                Text("\(exportedCount)/\(assetsToExport.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.escape)

            Button("Export \(assetsToExport.count) Photos") {
                Task {
                    await performExport()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedPreset == nil || destinationFolder == nil || isExporting)
            .keyboardShortcut(.return)
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Actions

    private func selectDestinationFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.title = "Select Export Destination"

        if panel.runModal() == .OK {
            destinationFolder = panel.url
        }
    }

    private func performExport() async {
        guard let preset = selectedPreset, let destination = destinationFolder else { return }

        isExporting = true
        exportedCount = 0
        exportProgress = 0

        let total = assetsToExport.count

        for (index, asset) in assetsToExport.enumerated() {
            let recipe = appState.recipes[asset.id] ?? EditRecipe()

            // Determine subfolder based on organization mode
            let targetFolder = ExportUtilities.determineTargetFolder(
                for: asset,
                recipe: recipe,
                organization: organizationMode,
                base: destination
            )

            // Create folder if needed
            do {
                try FileManager.default.createDirectory(
                    at: targetFolder,
                    withIntermediateDirectories: true
                )
            } catch {
                await MainActor.run {
                    failedExports.append("\(asset.url.lastPathComponent): folder creation failed")
                }
                continue
            }

            // Export the photo
            let outputName = asset.url.deletingPathExtension().lastPathComponent + ".jpg"
            let outputURL = targetFolder.appendingPathComponent(outputName)

            // Render and save
            let maxSizeValue = CGFloat(preset.maxSize ?? 4000)
            if let image = await ImagePipeline.shared.renderPreview(
                for: asset,
                recipe: recipe,
                maxSize: maxSizeValue
            ) {
                if let tiffData = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let jpegData = bitmap.representation(
                       using: NSBitmapImageRep.FileType.jpeg,
                       properties: [NSBitmapImageRep.PropertyKey.compressionFactor: Double(preset.quality) / 100.0]
                   ) {
                    do {
                        try jpegData.write(to: outputURL)
                    } catch {
                        await MainActor.run {
                            failedExports.append("\(asset.url.lastPathComponent): write failed")
                        }
                    }
                }
            }

            await MainActor.run {
                exportedCount = index + 1
                exportProgress = Double(index + 1) / Double(total)
            }
        }

        // Log any failures
        if !failedExports.isEmpty {
            print("[SmartExport] Failed exports: \(failedExports.joined(separator: ", "))")
        }

        await MainActor.run {
            isExporting = false

            // Open destination folder
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: destination.path)

            dismiss()
        }
    }

}

// MARK: - Preset Card

struct PresetCard: View {
    let preset: ExportPreset
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                Image(systemName: preset.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .accentColor)

                Text(preset.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)

                Text(presetDescription)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var presetDescription: String {
        var parts: [String] = []
        if let size = preset.maxSize {
            parts.append("\(size)px")
        } else {
            parts.append("Full")
        }
        parts.append("\(preset.quality)%")
        return parts.joined(separator: " · ")
    }
}

#Preview {
    SmartExportSheet(
        appState: AppState(),
        assetsToExport: []
    )
    .preferredColorScheme(.dark)
}
