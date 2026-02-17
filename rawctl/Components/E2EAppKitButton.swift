//
//  E2EAppKitButton.swift
//  rawctl
//
//  AppKit-backed button used only by the E2E/UI test harness.
//  XCUITest can be flaky clicking SwiftUI Buttons on some toolchains; NSButton is more reliable.
//

#if os(macOS)
import AppKit
import SwiftUI

struct E2EAppKitButton: NSViewRepresentable {
    let title: String
    let identifier: String
    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: title, target: context.coordinator, action: #selector(Coordinator.invoke))
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentHuggingPriority(.required, for: .vertical)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .vertical)
        button.sizeToFit()

        // Both identifiers are helpful: accessibility for XCUITest queries, UI identifier for AppKit debugging.
        button.identifier = NSUserInterfaceItemIdentifier(identifier)
        button.setAccessibilityIdentifier(identifier)
        button.setAccessibilityLabel(identifier)

        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        context.coordinator.action = action
        nsView.title = title
        nsView.identifier = NSUserInterfaceItemIdentifier(identifier)
        nsView.setAccessibilityIdentifier(identifier)
        nsView.setAccessibilityLabel(identifier)
        nsView.sizeToFit()
    }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func invoke() {
            action()
        }
    }
}
#endif
