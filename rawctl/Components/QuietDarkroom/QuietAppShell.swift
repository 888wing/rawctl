//
//  QuietAppShell.swift
//  rawctl
//
//  Custom shell for the Quiet Darkroom redesign.
//

import SwiftUI

struct QuietAppShell<Sidebar: View, Workspace: View, Inspector: View, Overlay: View>: View {
    @ObservedObject var uiState: QuietUIState
    var sourceTitle: String
    var sidebar: Sidebar
    var workspace: Workspace
    var inspector: Inspector
    var overlay: Overlay
    var onSearch: () -> Void = {}
    var onAssist: () -> Void = {}
    var onExport: () -> Void = {}

    init(
        uiState: QuietUIState,
        sourceTitle: String,
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder workspace: () -> Workspace,
        @ViewBuilder inspector: () -> Inspector,
        @ViewBuilder overlay: () -> Overlay,
        onSearch: @escaping () -> Void = {},
        onAssist: @escaping () -> Void = {},
        onExport: @escaping () -> Void = {}
    ) {
        self.uiState = uiState
        self.sourceTitle = sourceTitle
        self.sidebar = sidebar()
        self.workspace = workspace()
        self.inspector = inspector()
        self.overlay = overlay()
        self.onSearch = onSearch
        self.onAssist = onAssist
        self.onExport = onExport
    }

    private var showsSidebar: Bool {
        !uiState.sidebarCollapsed && uiState.mode != .edit && uiState.mode != .export
    }

    private var showsInspector: Bool {
        !uiState.inspectorCollapsed && uiState.mode != .export
    }

    private var sidebarWidth: CGFloat {
        uiState.mode == .cull ? 224 : 240
    }

    private var inspectorWidth: CGFloat {
        uiState.mode == .edit ? 372 : 320
    }

    var body: some View {
        VStack(spacing: 0) {
            QuietModeToolbar(
                uiState: uiState,
                sourceTitle: sourceTitle,
                onSearch: onSearch,
                onAssist: onAssist,
                onExport: onExport
            )

            ZStack(alignment: .top) {
                HStack(spacing: QDSpace.lg) {
                    if showsSidebar {
                        sidebar
                            .frame(width: sidebarWidth)
                    }

                    workspace
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if showsInspector {
                        inspector
                            .frame(width: inspectorWidth)
                    }
                }
                .padding(QDSpace.xl)

                overlay
            }
            .background(QDColor.appBackground)
        }
        .background(QDColor.appBackground)
        .frame(minWidth: 960, minHeight: 640)
    }
}
