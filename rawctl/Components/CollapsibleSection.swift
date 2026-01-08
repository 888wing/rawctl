//
//  CollapsibleSection.swift
//  rawctl
//
//  Unified collapsible section component for Inspector panels
//

import SwiftUI

/// Unified collapsible section with icon, title, and reset button
struct CollapsibleSection<Content: View>: View {
    let title: String
    let icon: String
    @Binding var isExpanded: Bool
    let hasEdits: Bool
    let onReset: (() -> Void)?
    @ViewBuilder let content: () -> Content
    
    @State private var isHovered = false
    
    init(
        _ title: String,
        icon: String,
        isExpanded: Binding<Bool>,
        hasEdits: Bool = false,
        onReset: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self._isExpanded = isExpanded
        self.hasEdits = hasEdits
        self.onReset = onReset
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    // Expand/collapse chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    
                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundColor(hasEdits ? .accentColor : .secondary)
                        .frame(width: 16)
                    
                    // Title
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                    
                    // Edit indicator dot
                    if hasEdits {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 6, height: 6)
                    }
                    
                    Spacer()
                    
                    // Reset button (shown on hover when has edits)
                    if hasEdits && isHovered && onReset != nil {
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                onReset?()
                            }
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        .help("Reset \(title)")
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
            
            // Content
            if isExpanded {
                content()
                    .padding(.top, 8)
                    .padding(.leading, 4)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
    }
}

/// Compact variant without icon
struct CollapsibleSectionCompact<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        DisclosureGroup(title, isExpanded: $isExpanded) {
            content()
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        CollapsibleSection(
            "Light",
            icon: "sun.max",
            isExpanded: .constant(true),
            hasEdits: true,
            onReset: { print("Reset Light") }
        ) {
            VStack(spacing: 8) {
                Text("Exposure slider here")
                Text("Contrast slider here")
            }
            .foregroundColor(.secondary)
        }
        
        CollapsibleSection(
            "Color",
            icon: "paintpalette",
            isExpanded: .constant(false),
            hasEdits: false
        ) {
            Text("Color controls")
        }
        
        CollapsibleSection(
            "Effects",
            icon: "sparkles",
            isExpanded: .constant(true),
            hasEdits: true
        ) {
            Text("Vignette, Grain, etc.")
                .foregroundColor(.secondary)
        }
    }
    .padding()
    .frame(width: 280)
    .preferredColorScheme(.dark)
}
