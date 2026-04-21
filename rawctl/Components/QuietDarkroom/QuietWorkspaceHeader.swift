//
//  QuietWorkspaceHeader.swift
//  rawctl
//
//  Compact library header with density, sort, and filter actions.
//

import SwiftUI

struct QuietWorkspaceHeader: View {
    var title: String
    var count: Int
    var filterChips: [String]
    @Binding var gridDensity: QuietGridDensity
    @Binding var sortCriteria: AppState.SortCriteria
    @Binding var sortOrder: AppState.SortOrder
    var onToggleFilters: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: QDSpace.sm) {
            HStack(alignment: .center, spacing: QDSpace.md) {
                VStack(alignment: .leading, spacing: QDSpace.xs) {
                    Text(title)
                        .font(QDFont.bodyMedium)
                        .foregroundStyle(QDColor.textPrimary)
                        .lineLimit(1)

                    Text("\(count) photo\(count == 1 ? "" : "s")")
                        .font(QDFont.metadata)
                        .foregroundStyle(QDColor.textTertiary)
                }

                Spacer()

                HStack(spacing: QDSpace.sm) {
                    Button(action: onToggleFilters) {
                        HStack(spacing: QDSpace.xs) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            Text(filterChips.isEmpty ? "Filter" : "Filters")
                        }
                    }
                    .buttonStyle(QuietToolbarCapsuleButtonStyle())

                    Menu {
                        ForEach(QuietGridDensity.allCases) { density in
                            Button(density.title) {
                                gridDensity = density
                            }
                        }
                    } label: {
                        HStack(spacing: QDSpace.xs) {
                            Image(systemName: "square.grid.2x2")
                            Text(gridDensity.title)
                        }
                    }
                    .buttonStyle(QuietToolbarCapsuleButtonStyle())

                    Menu {
                        ForEach(AppState.SortCriteria.allCases, id: \.self) { criteria in
                            Button {
                                sortCriteria = criteria
                            } label: {
                                HStack {
                                    Label(criteria.rawValue, systemImage: criteria.icon)
                                    if sortCriteria == criteria {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }

                        Divider()

                        Button {
                            sortOrder = .ascending
                        } label: {
                            HStack {
                                Text("Ascending")
                                if sortOrder == .ascending {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }

                        Button {
                            sortOrder = .descending
                        } label: {
                            HStack {
                                Text("Descending")
                                if sortOrder == .descending {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: QDSpace.xs) {
                            Image(systemName: sortCriteria.icon)
                            Text(sortCriteria.rawValue)
                            Image(systemName: sortOrder.icon)
                        }
                    }
                    .buttonStyle(QuietToolbarCapsuleButtonStyle())
                }
            }

            if !filterChips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: QDSpace.xs) {
                        ForEach(filterChips, id: \.self) { chip in
                            Text(chip)
                                .font(QDFont.metadata)
                                .foregroundStyle(QDColor.textSecondary)
                                .padding(.horizontal, QDSpace.sm)
                                .frame(height: 24)
                                .background(QDColor.elevatedSurface, in: Capsule())
                        }
                    }
                }
            }
        }
        .padding(.horizontal, QDSpace.lg)
        .padding(.top, QDSpace.md)
        .padding(.bottom, QDSpace.sm)
    }
}

private struct QuietToolbarCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(QDFont.toolbarItem)
            .foregroundStyle(QDColor.textSecondary)
            .padding(.horizontal, QDSpace.md)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: QDRadius.sm, style: .continuous)
                    .fill(configuration.isPressed ? QDColor.hoverSurface : QDColor.elevatedSurface)
            )
    }
}

extension QuietGridDensity {
    var title: String {
        switch self {
        case .compact: return "Compact"
        case .comfort: return "Comfort"
        case .spacious: return "Spacious"
        }
    }
}
