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
    
    var body: some View {
        HStack(spacing: 12) {
            // Filters label
            Text("Filters")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            
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
                    .background(appState.filterRating == rating ? Color.accentColor : Color.gray.opacity(0.2))
                    .foregroundColor(appState.filterRating == rating ? .white : .secondary)
                    .cornerRadius(4)
                    .buttonStyle(.plain)
                }
            }
            
            Divider()
                .frame(height: 16)
            
            // Flag filter - icons only
            HStack(spacing: 3) {
                Button {
                    appState.filterFlag = appState.filterFlag == nil ? nil : nil
                    appState.filterFlag = nil
                } label: {
                    Text("All")
                        .font(.system(size: 9))
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .background(appState.filterFlag == nil ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundColor(appState.filterFlag == nil ? .white : .secondary)
                .cornerRadius(4)
                .buttonStyle(.plain)
                
                Button {
                    appState.filterFlag = appState.filterFlag == .pick ? nil : .pick
                } label: {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 9))
                }
                .padding(4)
                .background(appState.filterFlag == .pick ? Color.green : Color.gray.opacity(0.2))
                .foregroundColor(appState.filterFlag == .pick ? .white : .green)
                .cornerRadius(4)
                .buttonStyle(.plain)
                
                Button {
                    appState.filterFlag = appState.filterFlag == .reject ? nil : .reject
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                }
                .padding(4)
                .background(appState.filterFlag == .reject ? Color.red : Color.gray.opacity(0.2))
                .foregroundColor(appState.filterFlag == .reject ? .white : .red)
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
                    .foregroundColor(.secondary)
                
                TextField("Tags...", text: $appState.filterTag)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10))
                    .frame(width: 60)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(white: 0.15))
            .cornerRadius(4)
            
            // Clear button
            if hasActiveFilters {
                Button {
                    appState.clearFilters()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Text("\(appState.filteredAssets.count)/\(appState.assets.count)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
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
                .background(Color.orange.opacity(0.2))
                .foregroundColor(.orange)
                .cornerRadius(4)
            }
            
            Spacer()
            
            // MARK: - Sort Controls
            
            HStack(spacing: 4) {
                Text("Sort")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
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
                    .background(Color.gray.opacity(0.2))
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
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help(appState.sortOrder == .ascending ? "Switch to Descending" : "Switch to Ascending")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
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
}

#Preview {
    FilterBar(appState: AppState())
        .frame(width: 240)
        .padding()
        .preferredColorScheme(.dark)
}
