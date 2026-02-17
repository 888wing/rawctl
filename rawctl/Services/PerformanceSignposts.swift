//
//  PerformanceSignposts.swift
//  rawctl
//
//  Centralized performance instrumentation (Instruments / XCTest signpost metrics).
//

import Foundation
import os

enum PerformanceSignposts {
    // Enable signposts only when explicitly requested (keeps day-to-day logs clean).
    static let isEnabled: Bool = {
        ProcessInfo.processInfo.environment["RAWCTL_SIGNPOSTS"] == "1"
    }()

    static let logger = Logger(subsystem: "Shacoworkshop.rawctl", category: "performance")
    static let signposter = OSSignposter(logger: logger)

    @inline(__always)
    static func begin(
        _ name: StaticString,
        id: OSSignpostID
    ) -> OSSignpostIntervalState? {
        guard isEnabled else { return nil }
        return signposter.beginInterval(name, id: id)
    }

    @inline(__always)
    static func end(
        _ name: StaticString,
        _ state: OSSignpostIntervalState?
    ) {
        guard isEnabled, let state else { return }
        signposter.endInterval(name, state)
    }

    @inline(__always)
    static func event(
        _ name: StaticString,
        id: OSSignpostID
    ) {
        guard isEnabled else { return }
        signposter.emitEvent(name, id: id)
    }
}
