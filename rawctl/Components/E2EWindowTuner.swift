//
//  E2EWindowTuner.swift
//  rawctl
//
//  Test-only helper to make UI automation more reliable on a "live" macOS desktop.
//  In E2E mode we aggressively bring the app window to the front to reduce flakiness
//  from other apps/overlays stealing focus or intercepting clicks.
//

#if os(macOS)
import AppKit
import SwiftUI

struct E2EWindowTuner: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        // Window may be nil at creation time; defer to next runloop.
        DispatchQueue.main.async { [weak view] in
            context.coordinator.tuneIfNeeded(window: view?.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.tuneIfNeeded(window: nsView.window)
        }
    }

    final class Coordinator {
        private var tunedWindowNumber: Int?

        func tuneIfNeeded(window: NSWindow?) {
            guard let window else { return }
            let windowNumber = window.windowNumber
            guard tunedWindowNumber != windowNumber else { return }
            tunedWindowNumber = windowNumber

            // Ensure we're truly frontmost; XCUITest "activate()" is not always enough
            // when other apps show overlay windows (dictation tools, browsers, etc).
            NSApp.activate(ignoringOtherApps: true)
            window.hidesOnDeactivate = false
            window.level = .floating
            window.orderFrontRegardless()
            window.makeKey()
        }
    }
}
#endif

