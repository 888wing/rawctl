//
//  KeyboardShortcutsView.swift
//  rawctl
//
//  Keyboard shortcuts help overlay
//

import SwiftUI

/// Keyboard shortcuts help overlay
struct KeyboardShortcutsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.title2.bold())
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search shortcuts...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(Color(white: 0.15))
            .cornerRadius(8)
            .padding(.horizontal)
            
            Divider()
                .padding(.top)
            
            // Shortcuts list
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(filteredCategories, id: \.name) { category in
                        ShortcutCategoryView(category: category)
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
        .background(.ultraThinMaterial)
    }
    
    private var filteredCategories: [ShortcutCategory] {
        if searchText.isEmpty {
            return ShortcutCategory.all
        }
        
        return ShortcutCategory.all.compactMap { category in
            let filteredShortcuts = category.shortcuts.filter { shortcut in
                shortcut.action.localizedCaseInsensitiveContains(searchText) ||
                shortcut.keys.localizedCaseInsensitiveContains(searchText)
            }
            if filteredShortcuts.isEmpty { return nil }
            return ShortcutCategory(name: category.name, icon: category.icon, shortcuts: filteredShortcuts)
        }
    }
}

/// Shortcut category section
struct ShortcutCategoryView: View {
    let category: ShortcutCategory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category header
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .frame(width: 20)
                
                Text(category.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .padding(.bottom, 4)
            
            // Shortcuts
            ForEach(category.shortcuts, id: \.action) { shortcut in
                ShortcutRowView(shortcut: shortcut)
            }
        }
    }
}

/// Single shortcut row
struct ShortcutRowView: View {
    let shortcut: Shortcut
    
    var body: some View {
        HStack {
            Text(shortcut.action)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Spacer()
            
            KeyboardShortcutBadge(keys: shortcut.keys)
        }
        .padding(.vertical, 2)
    }
}

/// Visual keyboard shortcut badge
struct KeyboardShortcutBadge: View {
    let keys: String
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(parseKeys(keys), id: \.self) { key in
                Text(key)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(white: 0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                            )
                    )
            }
        }
    }
    
    private func parseKeys(_ keys: String) -> [String] {
        // Split by + for modifier combinations
        keys.components(separatedBy: "+").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

// MARK: - Data Models

struct Shortcut {
    let action: String
    let keys: String
}

struct ShortcutCategory {
    let name: String
    let icon: String
    let shortcuts: [Shortcut]
    
    static let all: [ShortcutCategory] = [
        ShortcutCategory(
            name: "Navigation",
            icon: "arrow.left.arrow.right",
            shortcuts: [
                Shortcut(action: "Next photo", keys: "]"),
                Shortcut(action: "Previous photo", keys: "["),
                Shortcut(action: "Grid view", keys: "G"),
                Shortcut(action: "Single/Develop view", keys: "D"),
                Shortcut(action: "Toggle Grid/Single", keys: "Space"),
                Shortcut(action: "Zoom 100%", keys: "Z"),
                Shortcut(action: "Fit to screen", keys: "⌘ + 0"),
                Shortcut(action: "Before/After comparison", keys: "\\"),
                Shortcut(action: "Culling mode", keys: "C"),
            ]
        ),
        ShortcutCategory(
            name: "Rating & Flags",
            icon: "star.fill",
            shortcuts: [
                Shortcut(action: "Rate 1 star", keys: "1"),
                Shortcut(action: "Rate 2 stars", keys: "2"),
                Shortcut(action: "Rate 3 stars", keys: "3"),
                Shortcut(action: "Rate 4 stars", keys: "4"),
                Shortcut(action: "Rate 5 stars", keys: "5"),
                Shortcut(action: "Clear rating", keys: "0"),
                Shortcut(action: "Flag as Pick", keys: "P"),
                Shortcut(action: "Flag as Reject", keys: "X"),
                Shortcut(action: "Unflag", keys: "U"),
            ]
        ),
        ShortcutCategory(
            name: "Color Labels",
            icon: "circle.fill",
            shortcuts: [
                Shortcut(action: "Red label", keys: "6"),
                Shortcut(action: "Yellow label", keys: "7"),
                Shortcut(action: "Green label", keys: "8"),
                Shortcut(action: "Blue label", keys: "9"),
            ]
        ),
        ShortcutCategory(
            name: "Selection",
            icon: "checkmark.circle",
            shortcuts: [
                Shortcut(action: "Select all", keys: "⌘ + A"),
                Shortcut(action: "Deselect all", keys: "⌘ + D"),
                Shortcut(action: "Add to selection", keys: "⌘ + Click"),
                Shortcut(action: "Range select", keys: "⇧ + Click"),
                Shortcut(action: "Toggle selection mode", keys: "S"),
            ]
        ),
        ShortcutCategory(
            name: "Editing",
            icon: "slider.horizontal.3",
            shortcuts: [
                Shortcut(action: "Undo", keys: "⌘ + Z"),
                Shortcut(action: "Redo", keys: "⌘ + ⇧ + Z"),
                Shortcut(action: "Copy settings", keys: "⌘ + C"),
                Shortcut(action: "Paste settings", keys: "⌘ + V"),
                Shortcut(action: "Reset all adjustments", keys: "⌘ + ⇧ + R"),
                Shortcut(action: "Crop tool", keys: "R"),
            ]
        ),
        ShortcutCategory(
            name: "Export & File",
            icon: "square.and.arrow.up",
            shortcuts: [
                Shortcut(action: "Export", keys: "⌘ + E"),
                Shortcut(action: "Quick Export", keys: "⌘ + ⇧ + E"),
                Shortcut(action: "Open folder", keys: "⌘ + O"),
                Shortcut(action: "Show in Finder", keys: "⌘ + ⇧ + R"),
            ]
        ),
        ShortcutCategory(
            name: "View",
            icon: "eye",
            shortcuts: [
                Shortcut(action: "Toggle sidebar", keys: "⌘ + ⌥ + S"),
                Shortcut(action: "Toggle inspector", keys: "⌘ + ⌥ + I"),
                Shortcut(action: "Fullscreen", keys: "⌃ + ⌘ + F"),
                Shortcut(action: "Show keyboard shortcuts", keys: "?"),
            ]
        ),
    ]
}

#Preview {
    KeyboardShortcutsView()
        .preferredColorScheme(.dark)
}
