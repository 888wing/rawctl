//
//  KeyboardShortcutsManager.swift
//  rawctl
//
//  Centralized keyboard shortcuts management
//

import SwiftUI

/// Centralized keyboard shortcut definitions
enum KeyboardShortcuts {
    // Navigation
    static let nextPhoto = KeyEquivalent.rightArrow
    static let previousPhoto = KeyEquivalent.leftArrow
    static let firstPhoto = KeyEquivalent.home
    static let lastPhoto = KeyEquivalent.end

    // Rating
    static let rate0 = KeyEquivalent("0")
    static let rate1 = KeyEquivalent("1")
    static let rate2 = KeyEquivalent("2")
    static let rate3 = KeyEquivalent("3")
    static let rate4 = KeyEquivalent("4")
    static let rate5 = KeyEquivalent("5")

    // Flagging
    static let pick = KeyEquivalent("p")
    static let reject = KeyEquivalent("x")
    static let unflag = KeyEquivalent("u")
    static let togglePick = KeyEquivalent.space

    // Color Labels
    static let colorRed = KeyEquivalent("6")
    static let colorYellow = KeyEquivalent("7")
    static let colorGreen = KeyEquivalent("8")
    static let colorBlue = KeyEquivalent("9")

    // Views
    static let surveyMode = KeyEquivalent("n")  // with Cmd
    static let compareMode = KeyEquivalent("c")  // with Cmd
    static let gridView = KeyEquivalent("g")
    static let filmstrip = KeyEquivalent("f")

    // Zoom
    static let zoomIn = KeyEquivalent("+")
    static let zoomOut = KeyEquivalent("-")
    static let fitToScreen = KeyEquivalent("0")  // with Cmd
    static let actualSize = KeyEquivalent("1")   // with Cmd+Opt

    // Editing
    static let copySettings = KeyEquivalent("c")  // with Cmd+Shift
    static let pasteSettings = KeyEquivalent("v")  // with Cmd+Shift
    static let resetEdits = KeyEquivalent("r")     // with Cmd+Shift
}

/// View modifier for common photo operations
struct PhotoKeyboardShortcuts: ViewModifier {
    @ObservedObject var appState: AppState
    var onNavigateNext: (() -> Void)?
    var onNavigatePrevious: (() -> Void)?

    func body(content: Content) -> some View {
        content
            // Rating shortcuts
            .onKeyPress("0") { setRating(0); return .handled }
            .onKeyPress("1") { setRating(1); return .handled }
            .onKeyPress("2") { setRating(2); return .handled }
            .onKeyPress("3") { setRating(3); return .handled }
            .onKeyPress("4") { setRating(4); return .handled }
            .onKeyPress("5") { setRating(5); return .handled }

            // Flag shortcuts
            .onKeyPress("p") { setFlag(.pick); return .handled }
            .onKeyPress("x") { setFlag(.reject); return .handled }
            .onKeyPress("u") { setFlag(.none); return .handled }
            .onKeyPress(.space) { togglePick(); return .handled }

            // Color label shortcuts
            .onKeyPress("6") { setColor(.red); return .handled }
            .onKeyPress("7") { setColor(.yellow); return .handled }
            .onKeyPress("8") { setColor(.green); return .handled }
            .onKeyPress("9") { setColor(.blue); return .handled }

            // Navigation
            .onKeyPress(.rightArrow) {
                onNavigateNext?()
                return .handled
            }
            .onKeyPress(.leftArrow) {
                onNavigatePrevious?()
                return .handled
            }
    }

    private func setRating(_ rating: Int) {
        guard let id = appState.selectedAssetId else { return }
        var recipe = appState.recipes[id] ?? EditRecipe()
        recipe.rating = rating
        appState.recipes[id] = recipe
        appState.saveCurrentRecipe()
    }

    private func setFlag(_ flag: Flag) {
        guard let id = appState.selectedAssetId else { return }
        var recipe = appState.recipes[id] ?? EditRecipe()
        recipe.flag = flag
        appState.recipes[id] = recipe
        appState.saveCurrentRecipe()
    }

    private func togglePick() {
        guard let id = appState.selectedAssetId else { return }
        let currentFlag = appState.recipes[id]?.flag ?? .none
        setFlag(currentFlag == .pick ? .none : .pick)
    }

    private func setColor(_ color: ColorLabel) {
        guard let id = appState.selectedAssetId else { return }
        var recipe = appState.recipes[id] ?? EditRecipe()
        recipe.colorLabel = color
        appState.recipes[id] = recipe
        appState.saveCurrentRecipe()
    }
}

extension View {
    func photoKeyboardShortcuts(
        appState: AppState,
        onNext: (() -> Void)? = nil,
        onPrevious: (() -> Void)? = nil
    ) -> some View {
        modifier(PhotoKeyboardShortcuts(
            appState: appState,
            onNavigateNext: onNext,
            onNavigatePrevious: onPrevious
        ))
    }
}
