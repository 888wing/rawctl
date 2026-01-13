//
//  AppKitThumbnailView.swift
//  rawctl
//
//  AppKit-based thumbnail click handling for instant response
//  Replaces SwiftUI gesture stack to eliminate ~200-300ms click delay
//

import SwiftUI
import AppKit

/// Protocol for thumbnail interaction callbacks
protocol ThumbnailInteractionDelegate: AnyObject {
    func handleSingleClick(modifiers: NSEvent.ModifierFlags)
    func handleDoubleClick()
}

/// AppKit NSView for immediate click response
/// Uses direct mouseDown/mouseUp events instead of SwiftUI gesture recognition
final class ThumbnailNSView: NSView {
    weak var delegate: ThumbnailInteractionDelegate?

    /// Visual feedback state
    private var isPressed = false

    /// Double-click gesture recognizer
    private var doubleClickRecognizer: NSClickGestureRecognizer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupDoubleClickRecognizer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDoubleClickRecognizer()
    }

    private func setupDoubleClickRecognizer() {
        let recognizer = NSClickGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        recognizer.numberOfClicksRequired = 2
        recognizer.buttonMask = 0x1  // Only handle left-click (primary button)
        recognizer.delaysPrimaryMouseButtonEvents = false  // Critical: don't delay single clicks
        addGestureRecognizer(recognizer)
        doubleClickRecognizer = recognizer
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        // Immediate visual feedback would be handled by SwiftUI state update
        // We just track the press state here
    }

    override func mouseUp(with event: NSEvent) {
        guard isPressed else { return }
        isPressed = false

        // Check click count - if it's 2, let the gesture recognizer handle it
        if event.clickCount == 2 {
            return  // Double-click handled by NSClickGestureRecognizer
        }

        // Single click - fire immediately with modifier keys
        delegate?.handleSingleClick(modifiers: event.modifierFlags)
    }

    override func mouseDragged(with event: NSEvent) {
        // If user drags out of bounds, cancel the click
        let location = convert(event.locationInWindow, from: nil)
        if !bounds.contains(location) {
            isPressed = false
        }
    }

    @objc private func handleDoubleTap(_ recognizer: NSClickGestureRecognizer) {
        if recognizer.state == .ended {
            delegate?.handleDoubleClick()
        }
    }

    // MARK: - Right-Click Passthrough for Context Menu

    override func rightMouseDown(with event: NSEvent) {
        // Forward right-click to next responder for SwiftUI contextMenu
        // Don't call super - we want to completely bypass this view
        nextResponder?.rightMouseDown(with: event)
    }

    override func rightMouseUp(with event: NSEvent) {
        // Forward right-click to next responder for SwiftUI contextMenu
        nextResponder?.rightMouseUp(with: event)
    }

    /// Return nil to indicate this view has no context menu
    /// This tells AppKit to look at parent views for context menu
    override func menu(for event: NSEvent) -> NSMenu? {
        return nil
    }

    // MARK: - Hit Testing

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Check current event type - if it's a right-click related event, don't intercept
        if let currentEvent = NSApp.currentEvent {
            switch currentEvent.type {
            case .rightMouseDown, .rightMouseUp, .rightMouseDragged:
                return nil  // Pass through to SwiftUI for context menu
            default:
                break
            }
        }

        // Also check if right mouse button is currently pressed
        if NSEvent.pressedMouseButtons & 0x2 != 0 {
            return nil  // Right button pressed - pass through to SwiftUI
        }

        // Left-click: ensure this view receives click events
        let localPoint = convert(point, from: superview)
        if bounds.contains(localPoint) {
            return self
        }
        return nil
    }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        // Accept clicks even when window is inactive
        true
    }
}

// MARK: - SwiftUI Bridge

/// SwiftUI wrapper for AppKit thumbnail click handling
struct AppKitThumbnailClickHandler: NSViewRepresentable {
    typealias NSViewType = ThumbnailNSView

    /// Callback for single click with modifier keys
    let onTap: (EventModifiers) -> Void

    /// Callback for double click
    let onDoubleTap: () -> Void

    func makeNSView(context: Context) -> ThumbnailNSView {
        let view = ThumbnailNSView(frame: .zero)
        view.delegate = context.coordinator
        return view
    }

    func updateNSView(_ nsView: ThumbnailNSView, context: Context) {
        // Update coordinator callbacks if they change
        context.coordinator.onTap = onTap
        context.coordinator.onDoubleTap = onDoubleTap
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap, onDoubleTap: onDoubleTap)
    }

    /// Coordinator to bridge AppKit delegate to SwiftUI closures
    final class Coordinator: NSObject, ThumbnailInteractionDelegate {
        var onTap: (EventModifiers) -> Void
        var onDoubleTap: () -> Void

        init(onTap: @escaping (EventModifiers) -> Void, onDoubleTap: @escaping () -> Void) {
            self.onTap = onTap
            self.onDoubleTap = onDoubleTap
        }

        func handleSingleClick(modifiers: NSEvent.ModifierFlags) {
            // Convert NSEvent.ModifierFlags to SwiftUI EventModifiers
            var eventModifiers: EventModifiers = []
            if modifiers.contains(.command) { eventModifiers.insert(.command) }
            if modifiers.contains(.shift) { eventModifiers.insert(.shift) }
            if modifiers.contains(.option) { eventModifiers.insert(.option) }
            if modifiers.contains(.control) { eventModifiers.insert(.control) }

            onTap(eventModifiers)
        }

        func handleDoubleClick() {
            onDoubleTap()
        }
    }
}

// MARK: - View Extension

extension View {
    /// Replace SwiftUI gesture stack with AppKit click handling for instant response
    /// - Parameters:
    ///   - onTap: Called on single click with modifier keys
    ///   - onDoubleTap: Called on double click
    /// - Returns: View with AppKit click handling overlay
    func appKitClickHandler(
        onTap: @escaping (EventModifiers) -> Void,
        onDoubleTap: @escaping () -> Void
    ) -> some View {
        self.overlay {
            AppKitThumbnailClickHandler(onTap: onTap, onDoubleTap: onDoubleTap)
        }
    }
}
