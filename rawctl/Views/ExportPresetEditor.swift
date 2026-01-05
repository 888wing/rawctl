//
//  ExportPresetEditor.swift
//  rawctl
//
//  Editor for creating/modifying export presets
//

import SwiftUI

/// Editor for export presets
struct ExportPresetEditor: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var existingPreset: ExportPreset?
    var onSave: (ExportPreset) -> Void

    @State private var name: String = ""
    @State private var icon: String = "square.and.arrow.up"
    @State private var maxSize: Int? = nil
    @State private var quality: Int = 90
    @State private var colorSpace: String = "sRGB"
    @State private var addWatermark: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            formContent
            Divider()
            footerView
        }
        .frame(width: 450, height: 480)
        .onAppear {
            loadExistingPreset()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text(existingPreset == nil ? "New Export Preset" : "Edit Preset")
                .font(.title2.bold())
            Spacer()
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Form

    private var formContent: some View {
        Form {
            basicSection
            sizeSection
            watermarkSection
        }
        .formStyle(.grouped)
        .padding()
    }

    private var basicSection: some View {
        Section("Basic") {
            TextField("Preset Name", text: $name)
                .textFieldStyle(.roundedBorder)

            iconPicker

            qualitySlider
        }
    }

    private var iconPicker: some View {
        Picker("Icon", selection: $icon) {
            Label("Upload", systemImage: "square.and.arrow.up").tag("square.and.arrow.up")
            Label("Document", systemImage: "doc").tag("doc")
            Label("Photo", systemImage: "photo").tag("photo")
            Label("Globe", systemImage: "globe").tag("globe")
            Label("Eye", systemImage: "eye").tag("eye")
            Label("Sparkles", systemImage: "sparkles").tag("sparkles")
        }
    }

    private var qualitySlider: some View {
        HStack {
            Text("Quality")
            Slider(value: qualityBinding, in: 60...100, step: 5)
            Text("\(quality)%")
                .frame(width: 40)
                .monospacedDigit()
        }
    }

    private var qualityBinding: Binding<Double> {
        Binding(
            get: { Double(quality) },
            set: { quality = Int($0) }
        )
    }

    private var sizeSection: some View {
        Section("Output Size") {
            Picker("Max Size", selection: $maxSize) {
                Text("Original").tag(nil as Int?)
                Text("4K (3840px)").tag(3840 as Int?)
                Text("1080p (1920px)").tag(1920 as Int?)
                Text("Web (1200px)").tag(1200 as Int?)
                Text("Social (1080px)").tag(1080 as Int?)
                Text("Thumbnail (600px)").tag(600 as Int?)
            }

            Picker("Color Space", selection: $colorSpace) {
                Text("sRGB").tag("sRGB")
                Text("Adobe RGB").tag("AdobeRGB")
                Text("Display P3").tag("DisplayP3")
            }
        }
    }

    private var watermarkSection: some View {
        Section("Watermark") {
            Toggle("Add Watermark", isOn: $addWatermark)

            if addWatermark {
                Text("Watermark uses your configured studio name")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.escape)

            Button("Save Preset") {
                savePreset()
            }
            .buttonStyle(.borderedProminent)
            .disabled(name.isEmpty)
            .keyboardShortcut(.return)
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Actions

    private func loadExistingPreset() {
        if let preset = existingPreset {
            name = preset.name
            icon = preset.icon
            maxSize = preset.maxSize
            quality = preset.quality
            colorSpace = preset.colorSpace
            addWatermark = preset.addWatermark
        }
    }

    private func savePreset() {
        let preset = ExportPreset(
            id: existingPreset?.id ?? UUID(),
            name: name,
            icon: icon,
            maxSize: maxSize,
            quality: quality,
            colorSpace: colorSpace,
            addWatermark: addWatermark,
            isBuiltIn: false
        )

        onSave(preset)
        dismiss()
    }
}

#Preview {
    ExportPresetEditor(
        appState: AppState(),
        onSave: { _ in }
    )
    .preferredColorScheme(.dark)
}
