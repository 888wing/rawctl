//
//  RawctlViewCommands.swift
//  rawctl
//
//  Menu commands that operate on the focused window's AppState.
//

import SwiftUI

struct RawctlViewCommands: Commands {
    var body: some Commands {
        let isE2E = ProcessInfo.processInfo.environment["RAWCTL_E2E_STATUS"] == "1"
        let gridTitle = isE2E ? "Grid View (E2E)" : "Grid View"
        let singleTitle = isE2E ? "Single View (E2E)" : "Single View"

        // Inject into the system View menu (toolbar command group) to avoid duplicate top-level menus.
        CommandGroup(after: .toolbar) {
            Divider()

            Button(gridTitle) {
                if isE2E {
                    UserDefaults.standard.set("grid", forKey: "rawctl.e2e.lastCommand")
                }
                NotificationCenter.default.post(name: .rawctlGridViewCommand, object: nil)
            }
            .keyboardShortcut("1", modifiers: .command)

            Button(singleTitle) {
                if isE2E {
                    UserDefaults.standard.set("single", forKey: "rawctl.e2e.lastCommand")
                }
                NotificationCenter.default.post(name: .rawctlSingleViewCommand, object: nil)
            }
            .keyboardShortcut("2", modifiers: .command)
        }
    }
}
