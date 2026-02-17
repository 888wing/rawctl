//
//  AppCommandNotifications.swift
//  rawctl
//
//  Lightweight bridge between menu commands (App) and UI state (views).
//

import Foundation

extension Notification.Name {
    static let rawctlOpenFolderCommand = Notification.Name("rawctl.command.openFolder")
    static let rawctlGridViewCommand = Notification.Name("rawctl.command.view.grid")
    static let rawctlSingleViewCommand = Notification.Name("rawctl.command.view.single")
    static let rawctlExportCommand = Notification.Name("rawctl.command.export")
    static let rawctlResetAdjustmentsCommand = Notification.Name("rawctl.command.resetAdjustments")
}

