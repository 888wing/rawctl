//
//  AIColorGradingPanel.swift
//  rawctl
//
//  AI Colour Grading panel (Gemini Flash 3) for the Inspector sidebar.
//  Analyses the current rendered photo and applies a ColorGradeDelta.
//

import SwiftUI

struct AIColorGradingPanel: View {
    @ObservedObject var appState: AppState
    @StateObject private var service = GeminiColorService.shared
    @ObservedObject private var accountService = AccountService.shared

    @State private var selectedMode: PanelMode = .auto
    @State private var selectedMoodPreset: GeminiColorService.MoodPreset = .cinematic

    // MARK: - Panel Mode

    enum PanelMode: String, CaseIterable, Identifiable {
        case auto = "Auto"
        case mood = "Mood"

        var id: String { rawValue }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            if !AppFeatures.aiColorGradingEnabled {
                proGateView
            } else {
                controlsView
            }

            if !appState.aiGradeAnalysis.isEmpty {
                analysisView
            }
        }
    }

    // MARK: - Controls

    @ViewBuilder
    private var controlsView: some View {
        // Mode picker
        Picker("Mode", selection: $selectedMode) {
            ForEach(PanelMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()

        // Mood preset (only in Mood mode)
        if selectedMode == .mood {
            Picker("Mood", selection: $selectedMoodPreset) {
                ForEach(GeminiColorService.MoodPreset.allCases) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)
        }

        // Credits hint
        HStack {
            Spacer()
            if let balance = accountService.creditsBalance {
                Text("\(balance.totalRemaining) credits remaining")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }

        // Analyse button
        Button {
            analyzeAndApply()
        } label: {
            HStack(spacing: 6) {
                if service.isAnalysing {
                    ProgressView()
                        .controlSize(.small)
                    Text("Analysing…")
                } else {
                    Image(systemName: "sparkle.magnifyingglass")
                    Text("Analyse & Apply")
                    Spacer()
                    Text("1 credit")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(service.isAnalysing || appState.currentPreviewImage == nil)

        if let error = service.lastError {
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Analysis Result

    @ViewBuilder
    private var analysisView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last Analysis")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(appState.aiGradeAnalysis)
                .font(.caption)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(6)
    }

    // MARK: - Pro Gate

    @ViewBuilder
    private var proGateView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkle.magnifyingglass")
                    .foregroundColor(.secondary)
                Text("AI Colour Grading")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                Spacer()
                ProBadge()
            }

            Text("Analyse any photo and get instant colour grading suggestions powered by Gemini Flash 3.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Upgrade to Pro") {
                appState.showAccountSheet = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Analyse

    private func analyzeAndApply() {
        guard let image = appState.currentPreviewImage else { return }
        let mode: GeminiColorService.Mode = selectedMode == .mood
            ? .mood(selectedMoodPreset.rawValue)
            : .auto

        Task {
            do {
                let result = try await service.analyzeAndGrade(
                    renderedImage: image,
                    mode: mode
                )
                await MainActor.run {
                    appState.applyColorGrade(result, mode: mode)
                }
            } catch {
                // GeminiColorService sets lastError internally
            }
        }
    }
}

// MARK: - Pro Badge

private struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.accentColor)
            .cornerRadius(3)
    }
}

// MARK: - Preview

#Preview {
    AIColorGradingPanel(appState: AppState())
        .padding()
        .frame(width: 260)
        .preferredColorScheme(.dark)
}
