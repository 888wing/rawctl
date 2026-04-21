//
//  FilterBar.swift
//  rawctl
//
//  Filter controls for searching photos by metadata
//

import SwiftUI

/// Filter bar for searching/filtering photos
struct FilterBar: View {
    @ObservedObject var appState: AppState
    @AppStorage("latent.ui.quietDarkroom") private var quietDarkroomEnabled = true
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Filters label
                Text("Filters")
                    .font(quietDarkroomEnabled ? QDFont.bodyMedium : .caption.bold())
                    .foregroundColor(quietDarkroomEnabled ? QDColor.textSecondary : .secondary)

                // Rating filter - compact pills
                HStack(spacing: 2) {
                    ForEach(0...5, id: \.self) { rating in
                        Button {
                            appState.filterRating = appState.filterRating == rating ? 0 : rating
                        } label: {
                            if rating == 0 {
                                Image(systemName: "star")
                                    .font(.system(size: 9))
                            } else {
                                Text("≥\(rating)")
                                    .font(.system(size: 9, weight: .medium))
                            }
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(filterPillBackground(isSelected: appState.filterRating == rating))
                        .foregroundColor(filterPillForeground(isSelected: appState.filterRating == rating))
                        .cornerRadius(4)
                        .buttonStyle(.plain)
                    }
                }

                Divider()
                    .frame(height: 16)

                // Flag filter - icons only
                HStack(spacing: 3) {
                    Button {
                        appState.filterFlag = nil
                    } label: {
                        Text("All")
                            .font(.system(size: 9))
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 3)
                    .background(filterPillBackground(isSelected: appState.filterFlag == nil))
                    .foregroundColor(filterPillForeground(isSelected: appState.filterFlag == nil))
                    .cornerRadius(4)
                    .buttonStyle(.plain)

                    Button {
                        appState.filterFlag = appState.filterFlag == .pick ? nil : .pick
                    } label: {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 9))
                    }
                    .padding(4)
                    .background(appState.filterFlag == .pick ? semanticSelectedBackground(.green) : secondaryPillBackground)
                    .foregroundColor(appState.filterFlag == .pick ? .white : (quietDarkroomEnabled ? QDColor.successMuted : .green))
                    .cornerRadius(4)
                    .buttonStyle(.plain)

                    Button {
                        appState.filterFlag = appState.filterFlag == .reject ? nil : .reject
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .padding(4)
                    .background(appState.filterFlag == .reject ? semanticSelectedBackground(.red) : secondaryPillBackground)
                    .foregroundColor(appState.filterFlag == .reject ? .white : (quietDarkroomEnabled ? QDColor.dangerMuted : .red))
                    .cornerRadius(4)
                    .buttonStyle(.plain)
                }

                Divider()
                    .frame(height: 16)

                // Color filter - dots
                HStack(spacing: 2) {
                    ForEach(ColorLabel.allCases.filter { $0 != .none }, id: \.self) { color in
                        Button {
                            appState.filterColor = appState.filterColor == color ? nil : color
                        } label: {
                            Circle()
                                .fill(swiftUIColor(for: color))
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .stroke(appState.filterColor == color ? Color.white : Color.clear, lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()
                    .frame(height: 16)

                // Tag search
                HStack(spacing: 4) {
                    Image(systemName: "tag")
                        .font(.system(size: 9))
                        .foregroundColor(quietDarkroomEnabled ? QDColor.textTertiary : .secondary)

                    TextField("Tags...", text: $appState.filterTag)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10))
                        .frame(width: 60)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(secondaryPillBackground)
                .cornerRadius(4)

                // Clear button
                if hasActiveFilters {
                    Button {
                        appState.clearFilters()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(quietDarkroomEnabled ? QDColor.textSecondary : .secondary)
                    }
                    .buttonStyle(.plain)

                    Text("\(appState.filteredAssets.count)/\(appState.assets.count)")
                        .font(.system(size: 9))
                        .foregroundColor(quietDarkroomEnabled ? QDColor.textSecondary : .secondary)
                }

                // EXIF filter indicator
                if appState.exifFilter != nil {
                    HStack(spacing: 3) {
                        Image(systemName: "camera.metering.unknown")
                            .font(.system(size: 9))
                        Text("EXIF Filtering")
                            .font(.system(size: 9))
                        Button {
                            appState.exifFilter = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(quietDarkroomEnabled ? QDColor.elevatedSurface : Color.orange.opacity(0.2))
                    .foregroundColor(quietDarkroomEnabled ? QDColor.ratingMuted : .orange)
                    .cornerRadius(4)
                }

                Divider()
                    .frame(height: 16)

                // MARK: - Sort Controls
                HStack(spacing: 4) {
                    Text("Sort")
                        .font(.caption2)
                        .foregroundColor(quietDarkroomEnabled ? QDColor.textSecondary : .secondary)

                    // Sort criteria picker
                    Menu {
                        ForEach(AppState.SortCriteria.allCases, id: \.self) { criteria in
                            Button {
                                appState.sortCriteria = criteria
                            } label: {
                                HStack {
                                    Label(criteria.rawValue, systemImage: criteria.icon)
                                    if appState.sortCriteria == criteria {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: appState.sortCriteria.icon)
                            Text(appState.sortCriteria.rawValue)
                        }
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(secondaryPillBackground)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    // Sort order toggle
                    Button {
                        appState.sortOrder = appState.sortOrder == .ascending ? .descending : .ascending
                    } label: {
                        Image(systemName: appState.sortOrder.icon)
                            .font(.system(size: 10))
                            .padding(5)
                            .background(secondaryPillBackground)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help(appState.sortOrder == .ascending ? "Switch to Descending" : "Switch to Ascending")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipped()
        .background(quietDarkroomEnabled ? QDColor.panelBackground : Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
    
    private var hasActiveFilters: Bool {
        appState.filterRating > 0 ||
        appState.filterColor != nil ||
        appState.filterFlag != nil ||
        !appState.filterTag.isEmpty
    }
    
    private func swiftUIColor(for label: ColorLabel) -> Color {
        let c = label.color
        return Color(red: c.r, green: c.g, blue: c.b)
    }

    private var secondaryPillBackground: Color {
        quietDarkroomEnabled ? QDColor.elevatedSurface : Color.gray.opacity(0.2)
    }

    private func filterPillBackground(isSelected: Bool) -> Color {
        guard isSelected else { return secondaryPillBackground }
        return quietDarkroomEnabled ? QDColor.selectedSurface : .accentColor
    }

    private func filterPillForeground(isSelected: Bool) -> Color {
        if isSelected {
            return quietDarkroomEnabled ? QDColor.textPrimary : .white
        }
        return quietDarkroomEnabled ? QDColor.textSecondary : .secondary
    }

    private func semanticSelectedBackground(_ fallback: Color) -> Color {
        quietDarkroomEnabled ? QDColor.selectedSurface : fallback
    }
}

#Preview {
    FilterBar(appState: AppState())
        .frame(width: 240)
        .padding()
        .preferredColorScheme(.dark)
}
