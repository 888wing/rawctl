//
//  QuickActionsBar.swift
//  rawctl
//
//  Quick actions bar for Inspector (Undo/Redo, Auto, Reset, Copy/Paste, Compare)
//

import SwiftUI

/// Quick actions bar below histogram
struct QuickActionsBar: View {
    @Binding var localRecipe: EditRecipe
    @Binding var copiedRecipe: EditRecipe?
    @ObservedObject var appState: AppState
    
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onAuto: () -> Void
    let onReset: () -> Void
    let onCopy: () -> Void
    let onPaste: () -> Void
    let onToggleComparison: () -> Void
    let onNanoBanana: (NanoBananaResolution) -> Void
    let onBuyCredits: () -> Void
    
    let canUndo: Bool
    let canRedo: Bool
    let hasCopied: Bool
    let isComparing: Bool
    
    @State private var showNanoBananaPopover = false
    @ObservedObject private var accountService = AccountService.shared
    
    var body: some View {
        VStack(spacing: 8) {
            // Row 1: Undo/Redo + Auto + Reset
            HStack(spacing: 6) {
                // Undo/Redo group
                HStack(spacing: 2) {
                    ActionButton(
                        icon: "arrow.uturn.backward",
                        action: onUndo,
                        isDisabled: !canUndo,
                        help: "Undo (⌘Z)"
                    )
                    
                    ActionButton(
                        icon: "arrow.uturn.forward",
                        action: onRedo,
                        isDisabled: !canRedo,
                        help: "Redo (⌘⇧Z)"
                    )
                }
                .padding(2)
                .background(Color(white: 0.15))
                .cornerRadius(6)
                
                Spacer()
                
                // Auto button
                Button {
                    onAuto()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 10))
                        Text("Auto")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Auto-adjust exposure and colors")
                
                // Reset button
                Button {
                    onReset()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10))
                        Text("Reset")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(localRecipe.hasEdits ? .orange : nil)
                .disabled(!localRecipe.hasEdits)
                .help("Reset all adjustments")
            }
            
            // Row 2: Copy/Paste + Compare
            HStack(spacing: 6) {
                // Copy button
                ActionButton(
                    icon: "doc.on.doc",
                    label: "Copy",
                    action: onCopy,
                    isDisabled: !localRecipe.hasEdits,
                    help: "Copy settings (⌘C)"
                )
                
                // Paste button
                ActionButton(
                    icon: "doc.on.clipboard",
                    label: "Paste",
                    action: onPaste,
                    isDisabled: !hasCopied,
                    help: "Paste settings (⌘V)"
                )
                
                Spacer()
                
                // Before/After toggle
                Button {
                    onToggleComparison()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isComparing ? "rectangle.split.2x1.fill" : "rectangle.split.2x1")
                            .font(.system(size: 10))
                        Text(isComparing ? "Comparing" : "Compare")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(isComparing ? .accentColor : nil)
                .help("Before/After comparison (\\)")
            }
            
            // Row 3: Nano Banana AI
            HStack(spacing: 6) {
                Button {
                    if accountService.isAuthenticated {
                        showNanoBananaPopover = true
                    } else {
                        onBuyCredits()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow)
                        Text("Nano Banana")
                            .font(.system(size: 11, weight: .medium))

                        Spacer()

                        if accountService.isAuthenticated {
                            HStack(spacing: 3) {
                                Image(systemName: "sparkle")
                                    .font(.system(size: 8))
                                Text("\(accountService.creditsBalance?.totalRemaining ?? 0)")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                            }
                            .foregroundColor(.secondary)
                        } else {
                            Text("Sign In")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.15), Color.yellow.opacity(0.1)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                )
                .popover(isPresented: $showNanoBananaPopover) {
                    NanoBananaResolutionPicker(
                        onSelect: { resolution in
                            showNanoBananaPopover = false
                            onNanoBanana(resolution)
                        },
                        onBuyCredits: {
                            showNanoBananaPopover = false
                            onBuyCredits()
                        }
                    )
                }
                .help("AI-powered photo enhancement")
            }
        }
    }
}

/// Single action button
private struct ActionButton: View {
    let icon: String
    var label: String? = nil
    let action: () -> Void
    var isDisabled: Bool = false
    var help: String = ""
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                if let label = label {
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .padding(.horizontal, label != nil ? 8 : 6)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .foregroundColor(isDisabled ? .secondary.opacity(0.5) : .primary)
        .background(Color(white: 0.18))
        .cornerRadius(4)
        .disabled(isDisabled)
        .help(help)
    }
}

#Preview {
    VStack(spacing: 20) {
        QuickActionsBar(
            localRecipe: .constant(EditRecipe()),
            copiedRecipe: .constant(nil),
            appState: AppState(),
            onUndo: {},
            onRedo: {},
            onAuto: {},
            onReset: {},
            onCopy: {},
            onPaste: {},
            onToggleComparison: {},
            onNanoBanana: { _ in },
            onBuyCredits: {},
            canUndo: true,
            canRedo: false,
            hasCopied: true,
            isComparing: false
        )
        
        QuickActionsBar(
            localRecipe: .constant(EditRecipe()),
            copiedRecipe: .constant(nil),
            appState: AppState(),
            onUndo: {},
            onRedo: {},
            onAuto: {},
            onReset: {},
            onCopy: {},
            onPaste: {},
            onToggleComparison: {},
            onNanoBanana: { _ in },
            onBuyCredits: {},
            canUndo: false,
            canRedo: false,
            hasCopied: false,
            isComparing: true
        )
    }
    .padding()
    .frame(width: 280)
    .preferredColorScheme(.dark)
}
