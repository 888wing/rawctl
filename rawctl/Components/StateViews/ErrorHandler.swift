//
//  ErrorHandler.swift
//  rawctl
//
//  Unified error handling service for consistent error presentation
//

import SwiftUI

// MARK: - Error Severity

enum ErrorSeverity {
    case fatal       // Blocking alert dialog (e.g., unauthorized)
    case recoverable // ActionableToast with retry (e.g., network error)
    case warning     // Standard toast (e.g., validation error)
    case info        // Brief toast (e.g., hints)
}

// MARK: - Error Models

struct BannerError: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let retryAction: (() -> Void)?

    static func == (lhs: BannerError, rhs: BannerError) -> Bool {
        lhs.id == rhs.id
    }
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let type: ToastType
    let action: ToastAction?

    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.id == rhs.id
    }
}

struct ToastAction {
    let label: String
    let action: () -> Void
}

struct AlertError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let primaryAction: AlertAction?
    let secondaryAction: AlertAction?
}

struct AlertAction {
    let label: String
    let role: ButtonRole?
    let action: () -> Void

    init(label: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.label = label
        self.role = role
        self.action = action
    }
}

// MARK: - Error Handler Service

@MainActor
final class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()

    @Published var currentBanner: BannerError?
    @Published var currentToast: ToastMessage?
    @Published var fatalAlert: AlertError?

    private init() {}

    // MARK: - Main Entry Point

    func handle(_ error: Error, context: String = "", retryAction: (() -> Void)? = nil) {
        let severity = determineSeverity(for: error)
        let message = formatMessage(for: error, context: context)

        switch severity {
        case .fatal:
            presentFatalAlert(error: error, message: message)
        case .recoverable:
            presentBanner(message: message, retryAction: retryAction)
        case .warning:
            presentToast(message: message, type: .warning)
        case .info:
            presentToast(message: message, type: .info)
        }
    }

    // MARK: - Convenience Methods

    func showSuccess(_ message: String) {
        presentToast(message: message, type: .success)
    }

    func showWarning(_ message: String) {
        presentToast(message: message, type: .warning)
    }

    func showError(_ message: String, retryAction: (() -> Void)? = nil) {
        if let retry = retryAction {
            presentToast(message: message, type: .error, action: ToastAction(label: "Retry", action: retry))
        } else {
            presentToast(message: message, type: .error)
        }
    }

    func showAIMessage(_ message: String, action: ToastAction? = nil) {
        presentToast(message: message, type: .ai, action: action)
    }

    func dismissBanner() {
        withAnimation(.easeOut(duration: 0.2)) {
            currentBanner = nil
        }
    }

    func dismissToast() {
        withAnimation(.easeOut(duration: 0.2)) {
            currentToast = nil
        }
    }

    func dismissAlert() {
        fatalAlert = nil
    }

    // MARK: - Private Methods

    private func determineSeverity(for error: Error) -> ErrorSeverity {
        // Account errors
        if let accountError = error as? AccountError {
            switch accountError {
            case .unauthorized, .tokenReplayDetected:
                return .fatal
            case .networkError, .rateLimited:
                return .recoverable
            case .invalidResponse, .insufficientCredits, .securityBlock:
                return .warning
            }
        }

        // Nano Banana errors
        if let nbError = error as? NanoBananaError {
            switch nbError {
            case .unauthorized:
                return .fatal
            case .networkError, .fileReadError, .downloadFailed, .timeout:
                return .recoverable
            case .cancelled:
                return .info
            case .insufficientCredits, .invalidResponse, .serverError, .processingFailed:
                return .warning
            }
        }

        // Default: treat as warning
        return .warning
    }

    private func formatMessage(for error: Error, context: String) -> String {
        let baseMessage = error.localizedDescription
        if context.isEmpty {
            return baseMessage
        }
        return "\(context): \(baseMessage)"
    }

    private func presentFatalAlert(error: Error, message: String) {
        var primaryAction: AlertAction? = nil

        // Add sign-in action for auth errors
        if let accountError = error as? AccountError {
            switch accountError {
            case .unauthorized, .tokenReplayDetected:
                primaryAction = AlertAction(label: "Sign In") {
                    // Will be handled by the view that presents this
                    NotificationCenter.default.post(name: .showSignIn, object: nil)
                }
            default:
                break
            }
        }

        fatalAlert = AlertError(
            title: "Error",
            message: message,
            primaryAction: primaryAction,
            secondaryAction: AlertAction(label: "OK", role: .cancel, action: {})
        )
    }

    private func presentBanner(message: String, retryAction: (() -> Void)?) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            currentBanner = BannerError(message: message, retryAction: retryAction)
        }

        // Auto-dismiss after 10 seconds
        Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            if currentBanner?.message == message {
                dismissBanner()
            }
        }
    }

    private func presentToast(message: String, type: ToastType, action: ToastAction? = nil) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            currentToast = ToastMessage(message: message, type: type, action: action)
        }

        // Auto-dismiss after 3 seconds (or 5 if has action)
        let duration: UInt64 = action != nil ? 5_000_000_000 : 3_000_000_000
        Task {
            try? await Task.sleep(nanoseconds: duration)
            if currentToast?.message == message {
                dismissToast()
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let showSignIn = Notification.Name("showSignIn")
}

// MARK: - View Modifier for Error Handling

struct ErrorHandlerModifier: ViewModifier {
    @ObservedObject var errorHandler = ErrorHandler.shared

    func body(content: Content) -> some View {
        content
            .alert(
                errorHandler.fatalAlert?.title ?? "Error",
                isPresented: Binding(
                    get: { errorHandler.fatalAlert != nil },
                    set: { if !$0 { errorHandler.dismissAlert() } }
                )
            ) {
                if let alert = errorHandler.fatalAlert {
                    if let primary = alert.primaryAction {
                        Button(primary.label, role: primary.role) {
                            primary.action()
                        }
                    }
                    if let secondary = alert.secondaryAction {
                        Button(secondary.label, role: secondary.role) {
                            secondary.action()
                        }
                    }
                }
            } message: {
                if let alert = errorHandler.fatalAlert {
                    Text(alert.message)
                }
            }
    }
}

extension View {
    func withErrorHandling() -> some View {
        modifier(ErrorHandlerModifier())
    }
}
