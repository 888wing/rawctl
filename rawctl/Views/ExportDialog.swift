//
//  ExportDialog.swift
//  rawctl
//
//  Export configuration dialog
//

import SwiftUI

/// Export dialog view
struct ExportDialog: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var settings = ExportSettings()
    @State private var isExporting = false
    @State private var progress = ExportService.ExportProgress()
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Export Photos")
                .font(.headline)
            
            Divider()
            
            // Settings form
            Form {
                // Destination
                Section("Destination") {
                    HStack {
                        if let folder = settings.destinationFolder {
                            Text(folder.lastPathComponent)
                                .foregroundColor(.primary)
                        } else {
                            Text("Choose a folder…")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Choose…") {
                            chooseDestination()
                        }
                    }
                }
                
                // Quality
                Section("Quality") {
                    HStack {
                        Slider(value: Binding(
                            get: { Double(settings.quality) },
                            set: { settings.quality = Int($0) }
                        ), in: 60...100, step: 5)
                        
                        Text("\(settings.quality)%")
                            .monospacedDigit()
                            .frame(width: 45, alignment: .trailing)
                    }
                }
                
                // Size
                Section("Size") {
                    Picker("Long Edge", selection: $settings.sizeOption) {
                        ForEach(ExportSettings.SizeOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    
                    if settings.sizeOption == .custom {
                        HStack {
                            TextField("Size", value: $settings.customSize, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Text("pixels")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Filename
                Section("Filename") {
                    HStack {
                        Text("Suffix:")
                        TextField("Suffix", text: $settings.filenameSuffix)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Text(".jpg")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Selection
                Section("Export") {
                    Picker("Photos", selection: $settings.exportSelection) {
                        ForEach(ExportSettings.ExportSelection.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .formStyle(.grouped)
            
            // Progress
            if isExporting {
                VStack(spacing: 8) {
                    ProgressView(value: Double(progress.currentIndex), total: Double(progress.totalCount))
                    HStack {
                        Text("Exporting: \(progress.currentFilename)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(progress.currentIndex)/\(progress.totalCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
            }
            
            Divider()
            
            // Buttons
            HStack {
                Button("Cancel") {
                    if isExporting {
                        Task {
                            await ExportService.shared.cancel()
                        }
                    }
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(isExporting ? "Exporting..." : "Export") {
                    startExport()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(settings.destinationFolder == nil || isExporting)
            }
        }
        .padding()
        .frame(width: 400, height: 500)
        .onAppear {
            // Set default selection based on multi-selection state
            if appState.selectionCount > 0 {
                settings.exportSelection = .selected
            }
        }
    }
    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose export destination folder"
        panel.prompt = "Select"
        
        if panel.runModal() == .OK {
            settings.destinationFolder = panel.url
        }
    }
    
    private func startExport() {
        guard settings.destinationFolder != nil else { return }
        
        // Save settings for Quick Export
        QuickExportManager.shared.saveSettings(settings)
        
        isExporting = true
        
        // Determine assets to export
        let assetsToExport: [PhotoAsset]
        switch settings.exportSelection {
        case .current:
            if let current = appState.selectedAsset {
                assetsToExport = [current]
            } else {
                assetsToExport = []
            }
        case .selected:
            assetsToExport = appState.selectedAssets
        case .all:
            assetsToExport = appState.assets
        }
        
        // Use per-photo recipes from AppState
        let recipes = appState.recipes
        
        Task {
            await ExportService.shared.startExport(
                assets: assetsToExport,
                recipes: recipes,
                settings: settings
            )
            
            await MainActor.run {
                isExporting = false
                dismiss()
            }
        }
        
        // Poll for progress updates
        Task {
            while isExporting {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                await MainActor.run {
                    progress = ExportService.shared.progress
                }
            }
        }
    }
}

#Preview {
    ExportDialog(appState: AppState())
        .preferredColorScheme(.dark)
}
