//
//  QuietFilterPopover.swift
//  rawctl
//
//  Quiet filter popover replacing the persistent legacy filter bar.
//

import SwiftUI

struct QuietFilterPopover: View {
    @ObservedObject var appState: AppState
    @State private var localTagFilter = ""
    @FocusState private var isTagFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: QDSpace.lg) {
                HStack {
                    Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                        .font(QDFont.bodyMedium)
                        .foregroundStyle(QDColor.textPrimary)

                    Spacer()

                    if hasActiveFilters {
                        Button("Clear") {
                            appState.clearFilters()
                            localTagFilter = ""
                        }
                        .buttonStyle(.plain)
                        .font(QDFont.metadata)
                        .foregroundStyle(QDColor.accent)
                    }
                }

                section("Rating") {
                    HStack(spacing: QDSpace.xs) {
                        ForEach(0...5, id: \.self) { rating in
                            QuietFilterChip(
                                title: rating == 0 ? "Any" : "\(rating)+",
                                isSelected: appState.filterRating == rating
                            ) {
                                appState.filterRating = rating == 0 ? 0 : (appState.filterRating == rating ? 0 : rating)
                            }
                        }
                    }
                }

                section("Flags") {
                    HStack(spacing: QDSpace.xs) {
                        QuietFilterChip(title: "Any", isSelected: appState.filterFlag == nil) {
                            appState.filterFlag = nil
                        }
                        QuietFilterChip(title: "Picked", isSelected: appState.filterFlag == .pick) {
                            appState.filterFlag = appState.filterFlag == .pick ? nil : .pick
                        }
                        QuietFilterChip(title: "Rejected", isSelected: appState.filterFlag == .reject) {
                            appState.filterFlag = appState.filterFlag == .reject ? nil : .reject
                        }
                    }
                }

                section("Labels") {
                    HStack(spacing: QDSpace.xs) {
                        ForEach(ColorLabel.allCases.filter { $0 != .none }, id: \.self) { color in
                            Button {
                                appState.filterColor = appState.filterColor == color ? nil : color
                            } label: {
                                Circle()
                                    .fill(swiftUIColor(for: color))
                                    .frame(width: 18, height: 18)
                                    .overlay(
                                        Circle()
                                            .stroke(appState.filterColor == color ? Color.white : Color.clear, lineWidth: 1.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                section("Tags") {
                    TextField("Filter by tag", text: $localTagFilter)
                        .textFieldStyle(.plain)
                        .font(QDFont.body)
                        .foregroundStyle(QDColor.textPrimary)
                        .padding(.horizontal, QDSpace.md)
                        .frame(height: 32)
                        .background(QDColor.elevatedSurface, in: RoundedRectangle(cornerRadius: QDRadius.sm, style: .continuous))
                        .focused($isTagFieldFocused)
                }

                section("Sort") {
                    VStack(alignment: .leading, spacing: QDSpace.sm) {
                        Menu {
                            ForEach(AppState.SortCriteria.allCases, id: \.self) { criteria in
                                Button(criteria.rawValue) {
                                    appState.sortCriteria = criteria
                                }
                            }
                        } label: {
                            HStack {
                                Label(appState.sortCriteria.rawValue, systemImage: appState.sortCriteria.icon)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(QDColor.textTertiary)
                            }
                        }
                        .buttonStyle(QuietPopoverMenuButtonStyle())

                        HStack(spacing: QDSpace.xs) {
                            QuietFilterChip(title: "Ascending", isSelected: appState.sortOrder == .ascending) {
                                appState.sortOrder = .ascending
                            }
                            QuietFilterChip(title: "Descending", isSelected: appState.sortOrder == .descending) {
                                appState.sortOrder = .descending
                            }
                        }
                    }
                }
            }
            .padding(QDSpace.lg)
        }
        .frame(width: 380, height: 360)
        .background(QDColor.panelBackground, in: RoundedRectangle(cornerRadius: QDRadius.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: QDRadius.xl, style: .continuous)
                .stroke(QDColor.divider.opacity(0.74), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.34), radius: 24, x: 0, y: 16)
        .onAppear {
            localTagFilter = appState.filterTag
            DispatchQueue.main.async {
                isTagFieldFocused = true
            }
        }
        .onChange(of: localTagFilter) { _, newValue in
            appState.filterTag = newValue
        }
    }

    private var hasActiveFilters: Bool {
        appState.filterRating > 0 ||
        appState.filterColor != nil ||
        appState.filterFlag != nil ||
        !appState.filterTag.isEmpty ||
        appState.exifFilter != nil
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: QDSpace.sm) {
            Text(title)
                .font(QDFont.sectionLabel)
                .foregroundStyle(QDColor.textTertiary)
                .textCase(.uppercase)

            content()
        }
    }

    private func swiftUIColor(for label: ColorLabel) -> Color {
        let c = label.color
        return Color(red: c.r, green: c.g, blue: c.b)
    }
}

private struct QuietFilterChip: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(QDFont.metadata)
                .foregroundStyle(isSelected ? QDColor.textPrimary : QDColor.textSecondary)
                .padding(.horizontal, QDSpace.sm)
                .frame(height: 26)
                .background(
                    RoundedRectangle(cornerRadius: QDRadius.sm, style: .continuous)
                        .fill(isSelected ? QDColor.selectedSurface : QDColor.elevatedSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: QDRadius.sm, style: .continuous)
                        .stroke(isSelected ? QDColor.accentLine.opacity(0.56) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct QuietPopoverMenuButtonStyle: ButtonStyle {
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
