//
//  DeleteAccountView.swift
//  rawctl
//
//  In-app account deletion with explicit re-auth confirmation.
//

import SwiftUI

struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var accountService = AccountService.shared

    @State private var verificationCode = ""
    @State private var typedEmail = ""
    @State private var confirmationWord = ""
    @State private var isLoading = false
    @State private var didSendCode = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?

    private var accountEmail: String {
        accountService.currentUser?.email ?? ""
    }

    private var canDelete: Bool {
        verificationCode.count == 6 &&
        typedEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == accountEmail.lowercased() &&
        confirmationWord.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "DELETE"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Delete Account")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Image(systemName: "xmark")
                    .opacity(0)
            }
            .padding()
            .background(Color(white: 0.1))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Label("This action is permanent.", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.orange)

                    Text("For security, re-authenticate with a one-time code sent to your email, then confirm deletion.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text("Email on file: \(accountEmail)")
                        .font(.system(size: 11, weight: .medium))

                    Button {
                        Task { await sendCode() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(didSendCode ? "Resend Verification Code" : "Send Verification Code")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading || accountEmail.isEmpty)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Verification Code")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        TextField("000000", text: $verificationCode)
                            .textFieldStyle(AccountTextFieldStyle())
                            .onChange(of: verificationCode) { _, newValue in
                                verificationCode = String(newValue.prefix(6).filter { $0.isNumber })
                            }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Type your email to confirm")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        TextField(accountEmail, text: $typedEmail)
                            .textFieldStyle(AccountTextFieldStyle())
                            .autocorrectionDisabled()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Type DELETE to continue")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        TextField("DELETE", text: $confirmationWord)
                            .textFieldStyle(AccountTextFieldStyle())
                            .autocorrectionDisabled()
                    }

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Button(role: .destructive) {
                        Task { await deleteAccount() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text("Delete Account Permanently")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || !canDelete)

                    Text("Deletion requests are processed immediately and backend records are purged under the published SLA.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(18)
            }
        }
        .frame(width: 430, height: 560)
        .background(.ultraThinMaterial)
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func sendCode() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await accountService.sendAccountDeletionCode()
            didSendCode = true
            statusMessage = "Verification code sent."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteAccount() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await accountService.deleteAccount(
                verificationCode: verificationCode,
                typedEmail: typedEmail
            )
            statusMessage = "Account deleted."
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    DeleteAccountView()
        .preferredColorScheme(.dark)
}
