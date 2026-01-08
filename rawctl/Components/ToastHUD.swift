//
//  ToastHUD.swift
//  rawctl
//
//  Enhanced toast notification HUD with animations
//

import SwiftUI

/// Toast notification type
enum ToastType {
    case info
    case success
    case warning
    case error
    
    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .info: return .accentColor
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}

/// Enhanced toast HUD view
struct ToastHUD: View {
    let message: String
    let type: ToastType
    let isPresented: Bool
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    var body: some View {
        if isPresented {
            HStack(spacing: 10) {
                Image(systemName: type.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(type.color)
                
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
            )
            .overlay(
                Capsule()
                    .stroke(type.color.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .opacity
            ))
        }
    }
}

/// Toast HUD container for global notifications
struct ToastContainer: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack {
            Spacer()
            
            if let message = appState.hudMessage {
                ToastHUD(
                    message: message,
                    type: hudType(for: message),
                    isPresented: true
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.bottom, 20)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: appState.hudMessage)
    }
    
    private func hudType(for message: String) -> ToastType {
        let lower = message.lowercased()
        if lower.contains("error") || lower.contains("failed") {
            return .error
        } else if lower.contains("applied") || lower.contains("saved") || lower.contains("exported") {
            return .success
        } else if lower.contains("warning") {
            return .warning
        }
        return .info
    }
}

/// View modifier for easy toast integration
struct ToastModifier: ViewModifier {
    @ObservedObject var appState: AppState
    
    func body(content: Content) -> some View {
        ZStack {
            content
            ToastContainer(appState: appState)
        }
    }
}

extension View {
    func toastHUD(appState: AppState) -> some View {
        modifier(ToastModifier(appState: appState))
    }
}

#Preview {
    VStack(spacing: 20) {
        ToastHUD(message: "Rating: 5 Stars", type: .info, isPresented: true)
        ToastHUD(message: "Settings Applied", type: .success, isPresented: true)
        ToastHUD(message: "No photos selected", type: .warning, isPresented: true)
        ToastHUD(message: "Export failed", type: .error, isPresented: true)
    }
    .padding()
    .preferredColorScheme(.dark)
}
