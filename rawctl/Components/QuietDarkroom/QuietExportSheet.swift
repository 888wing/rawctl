//
//  QuietExportSheet.swift
//  rawctl
//
//  Quiet Darkroom export workflow overlay.
//

import SwiftUI

struct QuietExportSheet: View {
    @ObservedObject var appState: AppState
    var onClose: () -> Void

    @State private var settings = ExportSettings()
    @State private var isExporting = false
    @State private var progress = ExportService.ExportProgress()

    private var currentAssetSize: CGSize? {
        appState.selectedAsset?.imageSize
    }

    private var recipeResizeDimensions: (width: Int, height: Int)? {
        guard let asset = appState.selectedAsset,
              let recipe = appState.recipes[asset.id],
              recipe.resize.isEnabled,
              let originalSize = asset.imageSize else {
            return nil
        }

        let outputSize = recipe.resize.calculateOutputSize(originalSize: originalSize)
        return (Int(outputSize.width), Int(outputSize.height))
    }

    private var assetsToExportPreview: [PhotoAsset] {
        switch settings.exportSelection {
        case .current:
            return appState.selectedAsset.map { [$0] } ?? []
        case .selected:
            return appState.selectedAssets
        case .all:
            return appState.assets
        }
    }

    private var exportButtonTitle: String {
        let count = assetsToExportPreview.count
        if count == 0 {
            return "Export"
        }
        return "Export \(count) Photo\(count == 1 ? "" : "s")"
    }

    private var canStartExport: Bool {
        settings.destinationFolder != nil && !isExporting && !assetsToExportPreview.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(QDSpace.xl)

            Divider()
                .overlay(QDColor.divider.opacity(0.6))

            HStack(alignment: .top, spacing: QDSpace.xl) {
                ScrollView {
                    settingsColumn
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, QDSpace.xl)
                        .padding(.trailing, QDSpace.sm)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Rectangle()
                    .fill(QDColor.divider.opacity(0.6))
                    .frame(width: 1)
                    .padding(.vertical, QDSpace.xl)

                summaryColumn
                    .frame(width: 280, alignment: .topLeading)
                    .padding(.vertical, QDSpace.xl)
            }
            .padding(.horizontal, QDSpace.xl)

            Divider()
                .overlay(QDColor.divider.opacity(0.6))

            footer
                .padding(QDSpace.xl)
        }
        .frame(width: 900, height: 640)
        .background(QDColor.panelBackground, in: RoundedRectangle(cornerRadius: QDRadius.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: QDRadius.xl, style: .continuous)
                .stroke(QDColor.divider.opacity(0.72), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.42), radius: 34, x: 0, y: 22)
        .onAppear {
            if let existing = QuickExportManager.shared.loadSettings() {
                settings = existing
            }
            if appState.selectionCount > 0 {
                settings.exportSelection = .selected
            }
        }
    }

    private var recipeResizeMessage: String {
        if let recipeResizeDimensions {
            return "Using recipe resize: \(recipeResizeDimensions.width)×\(recipeResizeDimensions.height)"
        }
        return "No resize configured in the current recipe. Original size will be used."
    }

    private var summarySizeText: String {
        switch settings.sizeOption {
        case .original:
            return "Original"
        case .recipeResize:
            return recipeResizeDimensions.map { "\($0.width)×\($0.height)" } ?? "Recipe resize"
        case .size2048:
            return "2048 px"
        case .size4096:
            return "4096 px"
        case .custom:
            return "\(settings.customSize) px"
        }
    }

    @ViewBuilder
    private func exportSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        QuietInspectorSection(title: title) {
            content()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: QDSpace.xs) {
                Text("Export")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(QDColor.textPrimary)
                Text("Review output settings before rendering the delivery set.")
                    .font(QDFont.body)
                    .foregroundStyle(QDColor.textSecondary)
                Text("\(assetsToExportPreview.count) photo\(assetsToExportPreview.count == 1 ? "" : "s") in queue")
                    .font(QDFont.metadata)
                    .foregroundStyle(QDColor.textTertiary)
            }

            Spacer()

            Button {
                if isExporting {
                    Task {
                        await ExportService.shared.cancel()
                    }
                }
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(QDColor.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(QDColor.elevatedSurface, in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var settingsColumn: some View {
        VStack(alignment: .leading, spacing: QDSpace.lg) {
            exportSection("Preset") {
                VStack(alignment: .leading, spacing: QDSpace.sm) {
                    Text("Destination")
                        .font(QDFont.metadata)
                        .foregroundStyle(QDColor.textTertiary)

                    Button(action: chooseDestination) {
                        HStack {
                            VStack(alignment: .leading, spacing: QDSpace.xxs) {
                                Text(settings.destinationFolder?.lastPathComponent ?? "Choose a folder")
                                    .font(QDFont.body)
                                    .foregroundStyle(settings.destinationFolder == nil ? QDColor.textTertiary : QDColor.textPrimary)
                                if let destinationFolder = settings.destinationFolder {
                                    Text(destinationFolder.path)
                                        .font(QDFont.metadata)
                                        .foregroundStyle(QDColor.textTertiary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            Image(systemName: "folder")
                                .foregroundStyle(QDColor.textSecondary)
                        }
                    }
                    .buttonStyle(QuietExportRowButtonStyle())
                }
            }

            exportSection("Format") {
                QuietEditSliderRow(
                    title: "JPEG Quality",
                    value: Binding(
                        get: { Double(settings.quality) },
                        set: { settings.quality = Int($0) }
                    ),
                    range: 60...100,
                    step: 5,
                    defaultValue: 85,
                    display: { "\(Int($0))%" }
                )
            }

            exportSection("Size") {
                VStack(alignment: .leading, spacing: QDSpace.sm) {
                    Picker("Output Size", selection: $settings.sizeOption) {
                        ForEach(ExportSettings.SizeOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if settings.sizeOption == .custom {
                        TextField("Custom Size", value: $settings.customSize, format: .number)
                            .textFieldStyle(.plain)
                            .font(QDFont.body)
                            .foregroundStyle(QDColor.textPrimary)
                            .padding(.horizontal, QDSpace.md)
                            .frame(height: 32)
                            .background(QDColor.elevatedSurface, in: RoundedRectangle(cornerRadius: QDRadius.sm, style: .continuous))
                    }

                    if settings.sizeOption == .recipeResize {
                        Text(recipeResizeMessage)
                            .font(QDFont.metadata)
                            .foregroundStyle(QDColor.textTertiary)
                    }

                    if let currentAssetSize {
                        Text("Original: \(Int(currentAssetSize.width))×\(Int(currentAssetSize.height))")
                            .font(QDFont.metadata)
                            .foregroundStyle(QDColor.textTertiary)
                    }
                }
            }

            exportSection("Metadata") {
                HStack(spacing: QDSpace.lg) {
                    Text("Filename Suffix")
                        .font(QDFont.body)
                        .foregroundStyle(QDColor.textSecondary)

                    Spacer()

                    TextField("Suffix", text: $settings.filenameSuffix)
                        .textFieldStyle(.plain)
                        .font(QDFont.body)
                        .foregroundStyle(QDColor.textPrimary)
                        .frame(width: 148)
                        .padding(.horizontal, QDSpace.md)
                        .frame(height: 32)
                        .background(QDColor.elevatedSurface, in: RoundedRectangle(cornerRadius: QDRadius.sm, style: .continuous))
                }
            }

            exportSection("Selection") {
                Picker("Selection", selection: $settings.exportSelection) {
                    ForEach(ExportSettings.ExportSelection.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var summaryColumn: some View {
        VStack(alignment: .leading, spacing: QDSpace.lg) {
            exportSection("Delivery Set") {
                VStack(alignment: .leading, spacing: QDSpace.xs) {
                    summaryRow("Scope", value: settings.exportSelection.rawValue)
                    summaryRow("Photos", value: "\(assetsToExportPreview.count)")
                    summaryRow("Current", value: appState.selectedAsset?.filename ?? "No selection")
                }
            }

            exportSection("Output") {
                VStack(alignment: .leading, spacing: QDSpace.xs) {
                    summaryRow("Destination", value: settings.destinationFolder?.lastPathComponent ?? "Not set")
                    summaryRow("Size", value: summarySizeText)
                    summaryRow("Quality", value: "\(settings.quality)% JPEG")
                    summaryRow("Suffix", value: settings.filenameSuffix.isEmpty ? "None" : settings.filenameSuffix)
                }
            }

            if isExporting {
                exportSection("Progress") {
                    VStack(alignment: .leading, spacing: QDSpace.sm) {
                        ProgressView(
                            value: Double(progress.currentIndex),
                            total: Double(max(progress.totalCount, 1))
                        )
                        .tint(QDColor.accent)

                        HStack {
                            Text(progress.currentFilename.isEmpty ? "Preparing export…" : progress.currentFilename)
                                .font(QDFont.metadata)
                                .foregroundStyle(QDColor.textSecondary)
                                .lineLimit(1)
                            Spacer()
                            Text("\(progress.currentIndex)/\(progress.totalCount)")
                                .font(QDFont.numeric)
                                .foregroundStyle(QDColor.textTertiary)
                        }
                    }
                }
            }

            exportSection("Ready") {
                VStack(alignment: .leading, spacing: QDSpace.xs) {
                    Text(canStartExport ? "Destination and delivery settings are ready." : "Choose a destination folder before exporting.")
                        .font(QDFont.body)
                        .foregroundStyle(canStartExport ? QDColor.textSecondary : QDColor.textTertiary)
                    Text(canStartExport ? "The sheet is set up for immediate export." : "The export button will enable once the target folder is set.")
                        .font(QDFont.metadata)
                        .foregroundStyle(QDColor.textTertiary)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Cancel") {
                if isExporting {
                    Task {
                        await ExportService.shared.cancel()
                    }
                }
                onClose()
            }
            .buttonStyle(.plain)
            .foregroundStyle(QDColor.textSecondary)

            Spacer()

            Button(isExporting ? "Exporting…" : exportButtonTitle) {
                startExport()
            }
            .buttonStyle(.plain)
            .foregroundStyle(QDColor.appBackground)
            .padding(.horizontal, QDSpace.lg)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: QDRadius.sm, style: .continuous)
                    .fill(canStartExport ? QDColor.accent : QDColor.textDisabled)
            )
            .disabled(!canStartExport)
        }
    }

    @ViewBuilder
    private func summaryRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(QDFont.body)
                .foregroundStyle(QDColor.textSecondary)
            Spacer()
            Text(value)
                .font(QDFont.bodyMedium)
                .foregroundStyle(QDColor.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
                .multilineTextAlignment(.trailing)
        }
    }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose export destination folder"
        panel.prompt = "Select"

        if panel.runModal() == .OK {
            settings.destinationFolder = panel.url
        }
    }

    private func startExport() {
        guard settings.destinationFolder != nil else { return }

        appState.flushPendingRecipeSave()
        QuickExportManager.shared.saveSettings(settings)
        isExporting = true

        let assetsToExport = assetsToExportPreview
        let renderContextsByAssetID = Dictionary(
            uniqueKeysWithValues: assetsToExport.map { asset in
                (asset.id, appState.makeRenderContext(for: asset))
            }
        )

        Task {
            await ExportService.shared.startExport(
                assets: assetsToExport,
                renderContextsByAssetID: renderContextsByAssetID,
                settings: settings
            )

            await MainActor.run {
                isExporting = false
                onClose()
            }
        }

        Task {
            while isExporting {
                try? await Task.sleep(nanoseconds: 100_000_000)
                await MainActor.run {
                    progress = ExportService.shared.progress
                }
            }
        }
    }
}

private struct QuietExportRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(QDFont.body)
            .foregroundStyle(QDColor.textSecondary)
            .padding(.horizontal, QDSpace.md)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: QDRadius.sm, style: .continuous)
                    .fill(configuration.isPressed ? QDColor.hoverSurface : QDColor.elevatedSurface)
            )
    }
}
