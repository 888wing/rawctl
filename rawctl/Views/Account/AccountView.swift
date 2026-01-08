//
//  AccountView.swift
//  rawctl
//
//  Main account management view
//

import SwiftUI

/// Account panel showing user info or sign in prompt
struct AccountView: View {
    @ObservedObject var accountService = AccountService.shared
    @State private var showSignIn = false
    @State private var showPlans = false
    @State private var showCredits = false
    
    var body: some View {
        VStack(spacing: 0) {
            if accountService.isAuthenticated {
                authenticatedView
            } else {
                signInPromptView
            }
        }
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .sheet(isPresented: $showSignIn) {
            SignInView()
        }
        .sheet(isPresented: $showPlans) {
            PlansView()
        }
        .sheet(isPresented: $showCredits) {
            CreditsDetailView()
        }
    }
    
    // MARK: - Authenticated View
    
    private var authenticatedView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // User Info Header
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(accountService.currentUser?.email.prefix(1).uppercased() ?? "?")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.accentColor)
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(accountService.currentUser?.email ?? "")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(planDisplayName)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
            
            // Credits Balance
            creditsBalanceSection
            
            Divider()
            
            // Actions
            VStack(spacing: 8) {
                // Upgrade / Buy Credits
                if accountService.creditsBalance?.subscription.plan == "free" {
                    Button {
                        showPlans = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                            Text("Upgrade Plan")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(AccountActionButtonStyle())
                }
                
                Button {
                    showPlans = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Buy Credits")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .font(.system(size: 12))
                }
                .buttonStyle(AccountActionButtonStyle())
                
                // Manage Subscription
                if accountService.creditsBalance?.subscription.plan != "free" {
                    Button {
                        Task {
                            try? await accountService.openBillingPortal()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "creditcard")
                            Text("Manage Subscription")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .font(.system(size: 12))
                    }
                    .buttonStyle(AccountActionButtonStyle())
                }
                
                // Sign Out
                Button(role: .destructive) {
                    accountService.signOut()
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign Out")
                        Spacer()
                    }
                    .font(.system(size: 12))
                }
                .buttonStyle(AccountActionButtonStyle(isDestructive: true))
            }
        }
        .padding()
    }
    
    // MARK: - Credits Balance Section
    
    private var creditsBalanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Credits")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button {
                    showCredits = true
                } label: {
                    Text("Details")
                        .font(.system(size: 10))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            
            // Total credits display
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(accountService.creditsBalance?.totalRemaining ?? 0)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("available")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            // Breakdown bars
            if let balance = accountService.creditsBalance {
                VStack(spacing: 8) {
                    // Subscription credits bar
                    CreditBar(
                        label: "Monthly",
                        used: balance.subscription.used,
                        total: balance.subscription.total,
                        color: .accentColor
                    )
                    
                    // Purchased credits
                    if balance.purchased.total > 0 {
                        CreditBar(
                            label: "Purchased",
                            used: balance.purchased.total - balance.purchased.remaining,
                            total: balance.purchased.total,
                            color: .green
                        )
                    }
                }
                
                // Reset date
                if let resetsAt = balance.subscription.resetsAt {
                    Text("Resets \(formatResetDate(resetsAt))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Sign In Prompt View
    
    private var signInPromptView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            VStack(spacing: 4) {
                Text("Sign in to rawctl")
                    .font(.system(size: 14, weight: .semibold))
                
                Text("Get 10 free AI credits every month")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Button {
                showSignIn = true
            } label: {
                Text("Sign In")
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding(24)
    }
    
    // MARK: - Helpers
    
    private var planDisplayName: String {
        guard let plan = accountService.creditsBalance?.subscription.plan else {
            return "Free"
        }
        return plan.capitalized + " Plan"
    }
    
    private func formatResetDate(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Credit Bar

struct CreditBar: View {
    let label: String
    let used: Int
    let total: Int
    let color: Color
    
    private var remaining: Int { total - used }
    private var progress: Double { total > 0 ? Double(remaining) / Double(total) : 0 }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(remaining)/\(total)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(white: 0.2))
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Account Action Button Style

struct AccountActionButtonStyle: ButtonStyle {
    var isDestructive: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isDestructive ? .red : .primary)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(white: configuration.isPressed ? 0.15 : 0.1))
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

// MARK: - Preview

#Preview {
    AccountView()
        .frame(width: 280)
        .preferredColorScheme(.dark)
}
