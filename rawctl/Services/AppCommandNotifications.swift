//
//  AppCommandNotifications.swift
//  rawctl
//
//  Lightweight bridge between menu commands (App) and UI state (views).
//

import Foundation

extension Notification.Name {
    static let latentOpenFolderCommand = Notification.Name("latent.command.openFolder")
    static let latentGridViewCommand = Notification.Name("latent.command.view.grid")
    static let latentSingleViewCommand = Notification.Name("latent.command.view.single")
    static let latentExportCommand = Notification.Name("latent.command.export")
    static let latentResetAdjustmentsCommand = Notification.Name("latent.command.resetAdjustments")
}

