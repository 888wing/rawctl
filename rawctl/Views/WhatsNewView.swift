//
//  WhatsNewView.swift
//  rawctl
//
//  What's New popup view shown after app updates
//

import SwiftUI

struct WhatsNewView: View {
    let release: ReleaseNote
    let onDismiss: () -> Void

    @State private var selectedTab: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Highlights
                    highlightsSection

                    Divider()
                        .padding(.horizontal)

                    // Detailed sections
                    detailedSections
                }
                .padding(.vertical, 24)
            }

            Divider()

            // Footer
            footer
        }
        .frame(width: 520, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            // App icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)

            // Version badge
            HStack(spacing: 8) {
                Text("rawctl")
                    .font(.title.bold())

                Text("v\(release.version)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
            }

            // Title
            Text(release.title)
                .font(.title2)
                .foregroundStyle(.secondary)

            // Date
            Text(release.formattedDate)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.1),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Highlights

    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Highlights")
                .font(.headline)
                .padding(.horizontal, 24)

            VStack(spacing: 12) {
                ForEach(Array(release.highlights.enumerated()), id: \.offset) { index, highlight in
                    HighlightRow(
                        icon: highlightIcon(for: index),
                        color: highlightColor(for: index),
                        text: highlight
                    )
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private func highlightIcon(for index: Int) -> String {
        let icons = ["sparkles", "wand.and.rays", "star.fill", "bolt.fill", "paintbrush.fill"]
        return icons[index % icons.count]
    }

    private func highlightColor(for index: Int) -> Color {
        let colors: [Color] = [.yellow, .purple, .blue, .orange, .green]
        return colors[index % colors.count]
    }

    // MARK: - Detailed Sections

    private var detailedSections: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(release.sections) { section in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: sectionIcon(for: section.title))
                            .font(.system(size: 12))
                            .foregroundStyle(sectionColor(for: section.title))

                        Text(section.title)
                            .font(.subheadline.bold())
                            .foregroundStyle(sectionColor(for: section.title))
                    }
                    .padding(.horizontal, 24)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(section.items, id: \.self) { item in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(Color.secondary.opacity(0.3))
                                    .frame(width: 5, height: 5)
                                    .padding(.top, 6)

                                Text(item)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.leading, 4)
                }
            }
        }
    }

    private func sectionIcon(for title: String) -> String {
        switch title.lowercased() {
        case "new features", "added":
            return "plus.circle.fill"
        case "improvements", "changed":
            return "arrow.up.circle.fill"
        case "fixed", "bug fixes":
            return "checkmark.circle.fill"
        case "white balance":
            return "thermometer.medium"
        case "effects":
            return "sparkle"
        case "organization":
            return "folder.fill"
        case "keyboard shortcuts":
            return "keyboard"
        case "performance":
            return "bolt.fill"
        case "core features":
            return "star.fill"
        case "adjustments":
            return "slider.horizontal.3"
        case "tools":
            return "wrench.and.screwdriver.fill"
        default:
            return "circle.fill"
        }
    }

    private func sectionColor(for title: String) -> Color {
        switch title.lowercased() {
        case "new features", "added":
            return .green
        case "improvements", "changed":
            return .blue
        case "fixed", "bug fixes":
            return .orange
        default:
            return .secondary
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("View All Release Notes") {
                // Could open a window with full release history
                onDismiss()
            }
            .buttonStyle(.link)
            .foregroundStyle(.secondary)

            Spacer()

            Button("Continue") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(20)
    }
}

// MARK: - Highlight Row

private struct HighlightRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
            }

            Text(text)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(white: 0.5, opacity: 0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Version History View

struct VersionHistoryView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(ReleaseHistory.notes) { release in
                    NavigationLink(value: release) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("v\(release.version)")
                                    .font(.headline)

                                if release.version == VersionTracker.currentVersion {
                                    Text("Current")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor)
                                        .clipShape(Capsule())
                                }

                                Spacer()

                                Text(release.formattedDate)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }

                            Text(release.title)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Version History")
            .navigationDestination(for: ReleaseNote.self) { release in
                ReleaseDetailView(release: release)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 500, height: 500)
    }
}

// MARK: - Release Detail View

struct ReleaseDetailView: View {
    let release: ReleaseNote

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("v\(release.version)")
                            .font(.largeTitle.bold())

                        Spacer()

                        Text(release.formattedDate)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text(release.title)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                Divider()

                // Highlights
                if !release.highlights.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Highlights")
                            .font(.headline)

                        ForEach(release.highlights, id: \.self) { highlight in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(.yellow)
                                    .padding(.top, 2)

                                Text(highlight)
                                    .font(.body)
                            }
                        }
                    }
                    .padding(.horizontal)

                    Divider()
                }

                // Sections
                ForEach(release.sections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(section.title)
                            .font(.headline)

                        ForEach(section.items, id: \.self) { item in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(Color.secondary.opacity(0.5))
                                    .frame(width: 5, height: 5)
                                    .padding(.top, 6)

                                Text(item)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Release Notes")
    }
}

// MARK: - Preview

#Preview("What's New") {
    WhatsNewView(release: ReleaseHistory.latest) {
        print("Dismissed")
    }
}

#Preview("Version History") {
    VersionHistoryView()
}
