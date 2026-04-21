//
//  GeneralSettingsView.swift
//  rawctl
//
//  General application preferences for startup experience and preview caching.
//

import SwiftUI
import AppKit

struct GeneralSettingsView: View {
    @ObservedObject private var folderManager = FolderManager.shared
    @AppStorage(AppPreferences.startupRestoreModeKey)
    private var startupRestoreModeRawValue = AppPreferences.defaultStartupRestoreMode.rawValue
    @AppStorage(AppPreferences.startupSurfaceModeKey)
    private var startupPresentationModeRawValue = AppPreferences.defaultStartupPresentationMode.rawValue
    @AppStorage("latent.ui.quietDarkroom")
    private var quietDarkroomEnabled = true
    @AppStorage(AppPreferences.persistentPreviewDiskCacheEnabledKey)
    private var persistentPreviewDiskCacheEnabled = AppPreferences.defaultPersistentPreviewDiskCacheEnabled

    @State private var previewCacheUsage = ImagePipeline.PersistentPreviewCacheTelemetry(entryCount: 0, totalBytes: 0)
    @State private var previewCacheBudget = AppPreferences.persistentPreviewBudget()
    @State private var isClearingPreviewCache = false

    private let columns = [
        GridItem(.flexible(minimum: 280), spacing: QDSpace.lg, alignment: .top),
        GridItem(.flexible(minimum: 280), spacing: QDSpace.lg, alignment: .top)
    ]

    private var startupRestoreMode: StartupRestoreMode {
        get { StartupRestoreMode(rawValue: startupRestoreModeRawValue) ?? AppPreferences.defaultStartupRestoreMode }
        nonmutating set { startupRestoreModeRawValue = newValue.rawValue }
    }

    private var startupPresentationMode: StartupPresentationMode {
        get {
            switch startupPresentationModeRawValue {
            case StartupPresentationMode.directLibrary.rawValue, "lastOpenedFolder":
                return .directLibrary
            case StartupPresentationMode.preloadImage.rawValue:
                return .preloadImage
            default:
                return AppPreferences.defaultStartupPresentationMode
            }
        }
        nonmutating set { startupPresentationModeRawValue = newValue.rawValue }
    }

    private var defaultFolder: FolderSource? {
        folderManager.sources.first(where: \.isDefault)
    }

    private var pageBackground: some View {
        LinearGradient(
            colors: quietDarkroomEnabled
                ? [QDColor.appBackground, QDColor.panelBackground.opacity(0.96)]
                : [Color(nsColor: .windowBackgroundColor), Color(nsColor: .underPageBackgroundColor)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var cardFill: Color {
        quietDarkroomEnabled ? QDColor.panelBackground : Color(nsColor: .controlBackgroundColor)
    }

    private var cardBorder: Color {
        quietDarkroomEnabled ? QDColor.divider.opacity(0.72) : Color.black.opacity(0.08)
    }

    private var primaryText: Color {
        quietDarkroomEnabled ? QDColor.textPrimary : .primary
    }

    private var secondaryText: Color {
        quietDarkroomEnabled ? QDColor.textSecondary : .secondary
    }

    private var tertiaryText: Color {
        quietDarkroomEnabled ? QDColor.textTertiary : .secondary.opacity(0.8)
    }

    private var accent: Color {
        quietDarkroomEnabled ? QDColor.accent : .accentColor
    }

    private var cacheUsageText: String {
        if previewCacheUsage.entryCount == 0 {
            return "Empty"
        }
        let bytes = ByteCountFormatter.string(fromByteCount: previewCacheUsage.totalBytes, countStyle: .file)
        return "\(previewCacheUsage.entryCount) previews · \(bytes)"
    }

    private var cacheUsageFraction: Double {
        guard previewCacheBudget.bytes > 0 else { return 0 }
        return min(1, Double(previewCacheUsage.totalBytes) / Double(previewCacheBudget.bytes))
    }

    var body: some View {
        ZStack {
            pageBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: QDSpace.xl) {
                    header

                    LazyVGrid(columns: columns, alignment: .leading, spacing: QDSpace.lg) {
                        launchCard
                        appearanceCard
                        defaultFolderCard
                        previewCacheCard
                    }
                }
                .padding(QDSpace.xxl)
            }
            .scrollIndicators(.hidden)
        }
        .frame(minWidth: 700, minHeight: 580, alignment: .topLeading)
        .task {
            previewCacheBudget = AppPreferences.persistentPreviewBudget()
            await refreshPreviewCacheUsage()
        }
        .onChange(of: previewCacheBudget) { _, newBudget in
            UserDefaults.standard.set(newBudget.rawValue, forKey: AppPreferences.persistentPreviewDiskCacheMaxBytesKey)
            Task {
                await ImagePipeline.shared.trimPersistentPreviewCache(to: newBudget.bytes)
                await refreshPreviewCacheUsage()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: QDSpace.sm) {
            Text("General")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(primaryText)

            Text("Control how Latent opens, which shell it uses, and how much preview cache it keeps ready across launches.")
                .font(QDFont.body)
                .foregroundStyle(secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var launchCard: some View {
        settingsCard(
            title: "Launch",
            subtitle: "Separate what Latent restores from how the first screen is presented."
        ) {
            settingsSubsection(title: "Launch Source")
            VStack(spacing: QDSpace.sm) {
                ForEach(StartupRestoreMode.allCases) { mode in
                    choiceTile(
                        title: mode.title,
                        subtitle: mode.description,
                        symbolName: mode.symbolName,
                        isSelected: startupRestoreMode == mode
                    ) {
                        startupRestoreMode = mode
                    }
                }
            }

            Divider().overlay(cardBorder)
                .padding(.vertical, QDSpace.md)

            settingsSubsection(title: "Launch Preview")
            VStack(spacing: QDSpace.sm) {
                ForEach(StartupPresentationMode.allCases) { mode in
                    choiceTile(
                        title: mode.title,
                        subtitle: mode.description,
                        symbolName: mode.symbolName,
                        isSelected: startupPresentationMode == mode
                    ) {
                        startupPresentationMode = mode
                    }
                }
            }
        }
    }

    private var appearanceCard: some View {
        settingsCard(
            title: "Appearance",
            subtitle: "Surface the global UI shell switch instead of hiding it behind internal state."
        ) {
            toggleTile(
                title: "Use Quiet Darkroom",
                subtitle: "Switch the main window between the Quiet redesign and the legacy shell.",
                isOn: $quietDarkroomEnabled
            )

            Text("Changes apply immediately to the main window.")
                .font(QDFont.metadata)
                .foregroundStyle(tertiaryText)
        }
    }

    private var defaultFolderCard: some View {
        settingsCard(
            title: "Default Folder",
            subtitle: "Pick the pinned library folder used by the Default Folder launch source and as a fallback."
        ) {
            if folderManager.sources.isEmpty {
                VStack(alignment: .leading, spacing: QDSpace.sm) {
                    Text("No saved folders yet")
                        .font(QDFont.bodyMedium)
                        .foregroundStyle(primaryText)

                    Text("Add a folder here or keep managing folder sources from the sidebar.")
                        .font(QDFont.metadata)
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                VStack(spacing: QDSpace.sm) {
                    ForEach(folderManager.sources) { source in
                        folderTile(source)
                    }
                }
            }

            Button {
                addSavedFolder()
            } label: {
                Label("Add Folder…", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .tint(accent)
        }
    }

    private var previewCacheCard: some View {
        settingsCard(
            title: "Preview Cache",
            subtitle: "Persistent edited previews make the second trip into Edit much faster."
        ) {
            toggleTile(
                title: "Use Persistent Preview Cache",
                subtitle: "Store rendered previews on disk using asset fingerprint, recipe hash, and target size.",
                isOn: $persistentPreviewDiskCacheEnabled
            )

            VStack(alignment: .leading, spacing: QDSpace.sm) {
                settingsSubsection(title: "Cache Budget")

                Picker("Cache Budget", selection: $previewCacheBudget) {
                    ForEach(PreviewCacheBudget.allCases) { budget in
                        Text(budget.title).tag(budget)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!persistentPreviewDiskCacheEnabled)

                Text(previewCacheBudget.description)
                    .font(QDFont.metadata)
                    .foregroundStyle(secondaryText)
            }

            VStack(alignment: .leading, spacing: QDSpace.sm) {
                HStack {
                    Text("Disk Usage")
                        .font(QDFont.bodyMedium)
                        .foregroundStyle(primaryText)
                    Spacer()
                    Text(cacheUsageText)
                        .font(QDFont.metadata)
                        .foregroundStyle(secondaryText)
                }

                ProgressView(value: cacheUsageFraction)
                    .tint(accent)
            }

            HStack {
                Text("Budget")
                    .font(QDFont.metadata)
                    .foregroundStyle(tertiaryText)
                Spacer()
                Text(previewCacheBudget.title)
                    .font(QDFont.metadata)
                    .foregroundStyle(secondaryText)
            }

            Button(isClearingPreviewCache ? "Clearing Preview Cache…" : "Clear Preview Cache") {
                Task {
                    await clearPreviewCache()
                }
            }
            .buttonStyle(.bordered)
            .disabled(isClearingPreviewCache)
        }
    }

    private func settingsCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: QDSpace.lg) {
            VStack(alignment: .leading, spacing: QDSpace.xs) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(primaryText)

                Text(subtitle)
                    .font(QDFont.metadata)
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content()
        }
        .padding(QDSpace.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: QDRadius.xl, style: .continuous)
                .fill(cardFill)
        )
        .overlay {
            RoundedRectangle(cornerRadius: QDRadius.xl, style: .continuous)
                .stroke(cardBorder, lineWidth: 1)
        }
    }

    private func settingsSubsection(title: String) -> some View {
        Text(title.uppercased())
            .font(QDFont.sectionLabel)
            .foregroundStyle(tertiaryText)
    }

    private func choiceTile(
        title: String,
        subtitle: String,
        symbolName: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: QDSpace.md) {
                Image(systemName: symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? accent : secondaryText)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: QDSpace.xs) {
                    HStack(spacing: QDSpace.sm) {
                        Text(title)
                            .font(QDFont.bodyMedium)
                            .foregroundStyle(primaryText)

                        if isSelected {
                            Text("Selected")
                                .font(QDFont.metadata)
                                .foregroundStyle(accent)
                                .padding(.horizontal, QDSpace.sm)
                                .padding(.vertical, 4)
                                .background(accent.opacity(0.16), in: Capsule())
                        }
                    }

                    Text(subtitle)
                        .font(QDFont.metadata)
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(QDSpace.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: QDRadius.lg, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.12) : (quietDarkroomEnabled ? QDColor.elevatedSurface : Color.white.opacity(0.55)))
            )
            .overlay {
                RoundedRectangle(cornerRadius: QDRadius.lg, style: .continuous)
                    .stroke(isSelected ? accent.opacity(0.45) : cardBorder.opacity(0.7), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func toggleTile(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: QDSpace.sm) {
            Toggle(isOn: isOn) {
                VStack(alignment: .leading, spacing: QDSpace.xs) {
                    Text(title)
                        .font(QDFont.bodyMedium)
                        .foregroundStyle(primaryText)

                    Text(subtitle)
                        .font(QDFont.metadata)
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.switch)
        }
        .padding(QDSpace.md)
        .background(
            RoundedRectangle(cornerRadius: QDRadius.lg, style: .continuous)
                .fill(quietDarkroomEnabled ? QDColor.elevatedSurface : Color.white.opacity(0.55))
        )
        .overlay {
            RoundedRectangle(cornerRadius: QDRadius.lg, style: .continuous)
                .stroke(cardBorder.opacity(0.7), lineWidth: 1)
        }
    }

    private func folderTile(_ source: FolderSource) -> some View {
        Button {
            folderManager.setAsDefault(source.id)
        } label: {
            HStack(alignment: .top, spacing: QDSpace.md) {
                Image(systemName: source.isDefault ? "star.fill" : "folder")
                    .foregroundStyle(source.isDefault ? accent : secondaryText)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: QDSpace.xs) {
                    HStack(spacing: QDSpace.sm) {
                        Text(source.name)
                            .font(QDFont.bodyMedium)
                            .foregroundStyle(primaryText)
                            .lineLimit(1)

                        if source.isDefault {
                            Text("Default")
                                .font(QDFont.metadata)
                                .foregroundStyle(accent)
                                .padding(.horizontal, QDSpace.sm)
                                .padding(.vertical, 4)
                                .background(accent.opacity(0.16), in: Capsule())
                        }
                    }

                    Text(source.url.path)
                        .font(QDFont.metadata)
                        .foregroundStyle(secondaryText)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(QDSpace.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: QDRadius.lg, style: .continuous)
                    .fill(source.isDefault ? accent.opacity(0.12) : (quietDarkroomEnabled ? QDColor.elevatedSurface : Color.white.opacity(0.55)))
            )
            .overlay {
                RoundedRectangle(cornerRadius: QDRadius.lg, style: .continuous)
                    .stroke(source.isDefault ? accent.opacity(0.45) : cardBorder.opacity(0.7), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func addSavedFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose a Library Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Add Folder"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        _ = folderManager.addFolder(url)
    }

    private func refreshPreviewCacheUsage() async {
        let usage = await ImagePipeline.shared.persistentPreviewCacheUsage()
        await MainActor.run {
            previewCacheUsage = usage
        }
    }

    private func clearPreviewCache() async {
        await MainActor.run {
            isClearingPreviewCache = true
        }
        await ImagePipeline.shared.clearPersistentPreviewCache()
        await refreshPreviewCacheUsage()
        await MainActor.run {
            isClearingPreviewCache = false
        }
    }
}

#Preview {
    GeneralSettingsView()
        .preferredColorScheme(.dark)
}
