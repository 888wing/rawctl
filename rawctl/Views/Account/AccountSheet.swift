//
//  AccountSheet.swift
//  rawctl
//
//  Sheet wrapper for AccountView with navigation
//

import SwiftUI

struct AccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var accountService = AccountService.shared
    
    @State private var showSignIn = false
    @State private var showPlans = false
    @State private var showCredits = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Account")
                    .font(.system(size: 13, weight: .semibold))
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(white: 0.1))
            
            Divider()
            
            // Content
            ScrollView {
                VStack(spacing: 0) {
                    if accountService.isAuthenticated {
                        authenticatedContent
                    } else {
                        signInPrompt
                    }
                }
            }
        }
        .frame(width: 320, height: 440)
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
    
    // MARK: - Authenticated Content
    
    private var authenticatedContent: some View {
        VStack(spacing: 0) {
            // User header
            VStack(spacing: 12) {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 56, height: 56)
                    .overlay {
                        Text(accountService.currentUser?.email.prefix(1).uppercased() ?? "?")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.accentColor)
                    }
                
                VStack(spacing: 4) {
                    Text(accountService.currentUser?.email ?? "")
                        .font(.system(size: 13, weight: .medium))
                    
                    Text(planBadge)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Color(white: 0.15))
                        .cornerRadius(10)
                }
            }
            .padding(.vertical, 20)
            
            Divider()
            
            // Credits section
            Button {
                showCredits = true
            } label: {
                VStack(spacing: 12) {
                    HStack {
                        Text("Credits")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("Details")
                            .font(.system(size: 10))
                            .foregroundColor(.accentColor)
                    }
                    
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(accountService.creditsBalance?.totalRemaining ?? 0)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        
                        Text("available")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    
                    // Progress bar
                    if let balance = accountService.creditsBalance {
                        CreditBar(
                            label: "Monthly",
                            used: balance.subscription.used,
                            total: balance.subscription.total,
                            color: .accentColor
                        )
                    }
                }
                .padding()
            }
            .buttonStyle(.plain)
            
            Divider()
            
            // Actions
            VStack(spacing: 0) {
                if accountService.creditsBalance?.subscription.plan == "free" {
                    AccountSheetButton(
                        icon: "arrow.up.circle.fill",
                        title: "Upgrade Plan",
                        subtitle: "Get more credits",
                        iconColor: .orange
                    ) {
                        showPlans = true
                    }
                    
                    Divider().padding(.leading, 44)
                }
                
                AccountSheetButton(
                    icon: "plus.circle.fill",
                    title: "Buy Credits",
                    subtitle: "Credits never expire",
                    iconColor: .green
                ) {
                    showPlans = true
                }
                
                Divider().padding(.leading, 44)
                
                if accountService.creditsBalance?.subscription.plan != "free" {
                    AccountSheetButton(
                        icon: "creditcard.fill",
                        title: "Manage Subscription",
                        subtitle: "Billing & invoices",
                        iconColor: .accentColor
                    ) {
                        Task {
                            try? await accountService.openBillingPortal()
                        }
                    }
                    
                    Divider().padding(.leading, 44)
                }
                
                AccountSheetButton(
                    icon: "rectangle.portrait.and.arrow.right",
                    title: "Sign Out",
                    subtitle: nil,
                    iconColor: .secondary
                ) {
                    accountService.signOut()
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Sign In Prompt
    
    private var signInPrompt: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("Sign in to rawctl")
                    .font(.system(size: 16, weight: .semibold))
                
                Text("Get 10 free AI credits every month to power your photo editing with Nano Banana.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 24)
            
            VStack(spacing: 12) {
                Button {
                    showSignIn = true
                } label: {
                    Text("Sign In")
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button {
                    showPlans = true
                } label: {
                    Text("View Plans")
                        .font(.system(size: 12))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Helpers
    
    private var planBadge: String {
        guard let plan = accountService.creditsBalance?.subscription.plan else {
            return "Free Plan"
        }
        return plan.capitalized + " Plan"
    }
}

// MARK: - Account Sheet Button

struct AccountSheetButton: View {
    let icon: String
    let title: String
    let subtitle: String?
    let iconColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    AccountSheet()
        .preferredColorScheme(.dark)
}
