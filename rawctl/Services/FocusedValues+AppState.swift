//
//  FocusedValues+AppState.swift
//  rawctl
//
//  Expose the active window's AppState to SwiftUI Commands.
//

import SwiftUI

private struct RawctlAppStateKey: FocusedValueKey {
    typealias Value = AppState
}

extension FocusedValues {
    var rawctlAppState: AppState? {
        get { self[RawctlAppStateKey.self] }
        set { self[RawctlAppStateKey.self] = newValue }
    }
}

