//
//  QuietDarkroomTokens.swift
//  rawctl
//
//  Design tokens for the Quiet Darkroom redesign direction.
//

import SwiftUI

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

enum QDColor {
    static let appBackground = Color(hex: 0x0F1113)
    static let panelBackground = Color(hex: 0x15181B)
    static let elevatedSurface = Color(hex: 0x1B1F23)
    static let hoverSurface = Color(hex: 0x20262B)
    static let selectedSurface = Color(hex: 0x1E2933)
    static let divider = Color(hex: 0x2A3035)

    static let textPrimary = Color(hex: 0xE6E8EA)
    static let textSecondary = Color(hex: 0x9BA3AA)
    static let textTertiary = Color(hex: 0x69717A)
    static let textDisabled = Color(hex: 0x4F565D)

    static let accent = Color(hex: 0x7EA7D8)
    static let accentSubtle = Color(hex: 0x7EA7D8).opacity(0.14)
    static let accentLine = Color(hex: 0x7EA7D8).opacity(0.72)

    static let successMuted = Color(hex: 0x89B69B).opacity(0.82)
    static let dangerMuted = Color(hex: 0xC48A8A).opacity(0.82)
    static let ratingMuted = Color(hex: 0xC8B98A).opacity(0.82)
}

enum QDSpace {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}

enum QDRadius {
    static let xs: CGFloat = 5
    static let sm: CGFloat = 8
    static let md: CGFloat = 10
    static let lg: CGFloat = 14
    static let xl: CGFloat = 18
}

enum QDFont {
    static let toolbarTitle = Font.system(size: 13, weight: .semibold)
    static let toolbarItem = Font.system(size: 12, weight: .medium)
    static let sectionLabel = Font.system(size: 11, weight: .medium)
    static let sidebarRow = Font.system(size: 13, weight: .regular)
    static let body = Font.system(size: 13, weight: .regular)
    static let bodyMedium = Font.system(size: 13, weight: .medium)
    static let metadata = Font.system(size: 11, weight: .regular)
    static let numeric = Font.system(size: 12, weight: .regular, design: .monospaced)
}

enum QDMotion {
    static let fast = Animation.easeOut(duration: 0.12)
    static let standard = Animation.easeInOut(duration: 0.18)
    static let panel = Animation.easeInOut(duration: 0.22)
}
