//
//  QuietUIState.swift
//  rawctl
//
//  UI-only state for the Quiet Darkroom shell.
//

import SwiftUI

enum QuietMode: String, CaseIterable, Identifiable {
    case library
    case cull
    case edit
    case export

    var id: String { rawValue }

    var title: String {
        switch self {
        case .library: return "Library"
        case .cull: return "Cull"
        case .edit: return "Edit"
        case .export: return "Export"
        }
    }
}

enum QuietGridDensity: String, CaseIterable, Identifiable {
    case compact
    case comfort
    case spacious

    var id: String { rawValue }

    var thumbnailMinWidth: CGFloat {
        switch self {
        case .compact: return 132
        case .comfort: return 168
        case .spacious: return 212
        }
    }

    var gap: CGFloat {
        switch self {
        case .compact: return 12
        case .comfort: return 18
        case .spacious: return 22
        }
    }
}

enum QuietOverlay: Equatable {
    case none
    case assist
    case filter
    case commandPalette
    case exportSheet
}

final class QuietUIState: ObservableObject {
    @Published var mode: QuietMode = .library
    @Published var gridDensity: QuietGridDensity = .comfort
    @Published var activeOverlay: QuietOverlay = .none
    @Published var sidebarCollapsed: Bool = false
    @Published var inspectorCollapsed: Bool = false
    @Published var isFilmstripVisible: Bool = true

    func toggleOverlay(_ overlay: QuietOverlay) {
        withAnimation(QDMotion.panel) {
            activeOverlay = activeOverlay == overlay ? .none : overlay
        }
    }

    func closeOverlay() {
        withAnimation(QDMotion.fast) {
            activeOverlay = .none
        }
    }
}
