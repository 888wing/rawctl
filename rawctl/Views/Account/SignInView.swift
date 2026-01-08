//
//  SignInView.swift
//  rawctl
//
//  Sign in view with Email, Google, and Apple options
//

import SwiftUI
import GoogleSignIn
import GoogleSignInSwift

struct SignInView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var accountService = AccountService.shared

    @State private var email = ""
    @State private var verificationCode = ""
    @State private var step: SignInStep = .email
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var loadingMessage = ""
    @State private var googleSignInTask: Task<Void, Never>?

    enum SignInStep {
        case email
        case verifyCode
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    if step == .verifyCode {
                        step = .email
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: step == .verifyCode ? "chevron.left" : "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(step == .email ? "Sign In" : "Enter Code")
                    .font(.system(size: 13, weight: .semibold))
                
                Spacer()
                
                // Placeholder for alignment
                Image(systemName: "xmark")
                    .opacity(0)
            }
            .padding()
            .background(Color(white: 0.1))
            
            Divider()
            
            // Content
            ScrollView {
                VStack(spacing: 24) {
                    if step == .email {
                        emailStepView
                    } else {
                        verifyCodeStepView
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 400, height: 520)
        .background(.ultraThinMaterial)
        .overlay {
            // Loading overlay
            if isLoading {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))

                        Text(loadingMessage)
                            .font(.system(size: 13))
                            .foregroundColor(.white)

                        Button("Cancel") {
                            cancelGoogleSignIn()
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(white: 0.15))
                    )
                }
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onChange(of: accountService.isAuthenticated) { _, authenticated in
            if authenticated {
                dismiss()
            }
        }
        .onDisappear {
            // Clean up any pending tasks
            googleSignInTask?.cancel()
        }
    }

    private func cancelGoogleSignIn() {
        googleSignInTask?.cancel()
        isLoading = false
        loadingMessage = ""
    }
    
    // MARK: - Email Step
    
    private var emailStepView: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: "envelope.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 8) {
                Text("Sign in with Email")
                    .font(.system(size: 16, weight: .semibold))
                
                Text("We'll send you a verification code")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            // Email input
            VStack(alignment: .leading, spacing: 6) {
                Text("Email")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextField("you@example.com", text: $email)
                    .textFieldStyle(AccountTextFieldStyle())
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
            }
            
            // Send code button
            Button {
                Task {
                    await sendMagicLink()
                }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text("Send Code")
                }
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(email.isEmpty || !isValidEmail(email) || isLoading)

            // Divider
            HStack {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
                Text("or")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
            }

            // Google Sign-In button
            Button {
                handleGoogleSignIn()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "g.circle.fill")
                        .font(.system(size: 18))
                    Text("Continue with Google")
                }
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.bordered)
            .disabled(isLoading)
        }
    }

    // MARK: - Verify Code Step
    
    private var verifyCodeStepView: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: "number.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 8) {
                Text("Check your email")
                    .font(.system(size: 16, weight: .semibold))
                
                Text("We sent a code to \(email)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            // Code input
            VStack(alignment: .leading, spacing: 6) {
                Text("Verification Code")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextField("000000", text: $verificationCode)
                    .textFieldStyle(AccountTextFieldStyle())
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .onChange(of: verificationCode) { _, newValue in
                        // Limit to 6 digits
                        verificationCode = String(newValue.prefix(6).filter { $0.isNumber })
                        
                        // Auto-submit when 6 digits entered
                        if verificationCode.count == 6 {
                            Task {
                                await verifyCode()
                            }
                        }
                    }
            }
            
            // Verify button
            Button {
                Task {
                    await verifyCode()
                }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text("Verify")
                }
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(verificationCode.count != 6 || isLoading)
            
            // Resend code
            Button {
                Task {
                    await sendMagicLink()
                }
            } label: {
                Text("Resend code")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
    }
    
    // MARK: - Actions
    
    private func sendMagicLink() async {
        isLoading = true
        loadingMessage = "Sending verification code..."
        defer {
            isLoading = false
            loadingMessage = ""
        }

        do {
            try await accountService.sendMagicLink(email: email)
            withAnimation {
                step = .verifyCode
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func verifyCode() async {
        isLoading = true
        loadingMessage = "Verifying code..."
        defer {
            isLoading = false
            loadingMessage = ""
        }

        do {
            try await accountService.verifyMagicLink(email: email, code: verificationCode)
            // Dismiss handled by onChange
        } catch {
            errorMessage = error.localizedDescription
            verificationCode = ""
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    private func handleGoogleSignIn() {
        guard let window = NSApplication.shared.keyWindow else {
            errorMessage = "Unable to find application window"
            return
        }

        // Configure GIDSignIn with client ID from Info.plist
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else {
            errorMessage = "Google Client ID not configured"
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        isLoading = true
        loadingMessage = "Opening Google Sign-In..."

        GIDSignIn.sharedInstance.signIn(withPresenting: window) { result, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.isLoading = false
                    self.loadingMessage = ""
                    // Don't show error for user cancellation
                    let nsError = error as NSError
                    if nsError.code == GIDSignInError.canceled.rawValue {
                        return
                    }
                    // Provide user-friendly error messages
                    if nsError.domain == "com.google.GIDSignIn" {
                        switch nsError.code {
                        case GIDSignInError.hasNoAuthInKeychain.rawValue:
                            self.errorMessage = "No previous sign-in found. Please sign in again."
                        case GIDSignInError.EMM.rawValue:
                            self.errorMessage = "Enterprise mobility management error."
                        default:
                            self.errorMessage = "Google Sign-In failed: \(error.localizedDescription)"
                        }
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                    return
                }

                guard let user = result?.user,
                      let idToken = user.idToken?.tokenString else {
                    self.isLoading = false
                    self.loadingMessage = ""
                    self.errorMessage = "Failed to get Google credentials"
                    return
                }

                // Update loading message
                self.loadingMessage = "Signing in..."

                // Send to backend
                self.googleSignInTask = Task {
                    do {
                        try await self.accountService.signInWithGoogle(idToken: idToken)
                        await MainActor.run {
                            self.isLoading = false
                            self.loadingMessage = ""
                        }
                    } catch {
                        await MainActor.run {
                            self.isLoading = false
                            self.loadingMessage = ""
                            self.errorMessage = "Sign-in failed: \(error.localizedDescription)"
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Account Text Field Style

struct AccountTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(white: 0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Preview

#Preview {
    SignInView()
        .preferredColorScheme(.dark)
}
