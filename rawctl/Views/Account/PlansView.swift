//
//  PlansView.swift
//  rawctl
//
//  View for selecting subscription plans and purchasing credits
//

import SwiftUI

struct PlansView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var accountService = AccountService.shared
    
    @State private var selectedTab = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
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
                
                Text("Plans & Credits")
                    .font(.system(size: 13, weight: .semibold))
                
                Spacer()
                
                Image(systemName: "xmark")
                    .opacity(0)
            }
            .padding()
            .background(Color(white: 0.1))
            
            Divider()
            
            // Tab picker
            Picker("", selection: $selectedTab) {
                Text("Plans").tag(0)
                Text("AI Credits").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content
            ScrollView {
                if selectedTab == 0 {
                    plansListView
                } else {
                    creditsPacksView
                }
            }
        }
        .frame(width: 400, height: 520)
        .background(.ultraThinMaterial)
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            await accountService.loadPlans()
        }
    }
    
    // MARK: - Plans List
    
    private var plansListView: some View {
        VStack(spacing: 12) {
            Text(
                AppDistributionChannel.current.usesStoreKitBilling
                ? "All upgrades in this build are processed with Apple In-App Purchase."
                : "Manage plans and billing through your secure browser checkout."
            )
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)

            ForEach(accountService.plans) { plan in
                PlanCard(
                    plan: plan,
                    isCurrentPlan: plan.name == accountService.creditsBalance?.subscription.plan,
                    isLoading: isLoading
                ) {
                    await selectPlan(plan)
                }
            }

            if AppDistributionChannel.current.usesStoreKitBilling {
                Button {
                    Task { await handleRestorePurchases() }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise.circle")
                        Text("Restore Purchases")
                        Spacer()
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
            }

            legalLinksFooter
        }
        .padding()
    }
    
    // MARK: - Credits Packs
    
    private var creditsPacksView: some View {
        VStack(spacing: 12) {
            Text("Optional top-up for Nano Banana generation")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
            
            ForEach(accountService.creditsPacks) { pack in
                CreditPackCard(
                    pack: pack,
                    isLoading: isLoading
                ) {
                    await purchaseCreditsPack(pack)
                }
            }

            legalLinksFooter
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func selectPlan(_ plan: PlanInfo) async {
        guard plan.name.lowercased() != "free" else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await accountService.purchasePlan(named: plan.name)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func purchaseCreditsPack(_ pack: CreditPackInfo) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await accountService.purchaseCreditsPack(named: pack.name)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleRestorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await accountService.restorePurchases()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var legalLinksFooter: some View {
        VStack(spacing: 6) {
            if let notice = accountService.billingNotice, !notice.isEmpty {
                Text(notice)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 14) {
                Link("Privacy", destination: AppLegalLinks.privacyPolicy)
                Link("Terms", destination: AppLegalLinks.termsOfService)
                Link("Support", destination: AppLegalLinks.support)
            }
            .font(.system(size: 10, weight: .medium))
        }
        .padding(.top, 4)
    }
}

// MARK: - Plan Card

struct PlanCard: View {
    let plan: PlanInfo
    let isCurrentPlan: Bool
    let isLoading: Bool
    let onSelect: () async -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(planDisplayName)
                            .font(.system(size: 14, weight: .semibold))
                        
                        if isCurrentPlan {
                            Text("Current")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.2))
                                .cornerRadius(4)
                        }
                        
                        if isPopularPlan {
                            Text("Popular")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    if plan.price > 0 {
                        Text(priceText)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text(priceUnit)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Free")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                }
            }
            
            // Features
            VStack(alignment: .leading, spacing: 6) {
                ForEach(features, id: \.self) { feature in
                    PlanFeature(text: feature)
                }
            }
            
            // Button
            if !isCurrentPlan && normalizedPlanName != "free" {
                Button {
                    Task {
                        await onSelect()
                    }
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(buttonTitle)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(isLoading || isCurrentPlan)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isCurrentPlan ? Color.accentColor.opacity(0.5) : Color.clear,
                    lineWidth: 1
                )
        )
    }

    private var normalizedPlanName: String {
        plan.name.lowercased()
    }

    private var isYearlyPlan: Bool {
        normalizedPlanName.contains("year") || normalizedPlanName.contains("annual")
    }

    private var isProPlan: Bool {
        normalizedPlanName.contains("pro") || normalizedPlanName.contains("premium") || normalizedPlanName.contains("year")
    }

    private var isPopularPlan: Bool {
        normalizedPlanName == "pro" || normalizedPlanName == "pro_monthly"
    }

    private var planDisplayName: String {
        if normalizedPlanName == "free" { return "Free" }
        if isProPlan {
            return isYearlyPlan ? "Pro Yearly" : "Pro Monthly"
        }
        return plan.name.capitalized
    }

    private var priceText: String {
        if normalizedPlanName == "pro_monthly" {
            return "$15"
        }
        if normalizedPlanName == "pro_yearly" || normalizedPlanName == "yearly" || normalizedPlanName == "annual" {
            return "$120"
        }
        return plan.priceFormatted
    }

    private var priceUnit: String {
        isYearlyPlan ? "/year" : "/month"
    }

    private var features: [String] {
        if normalizedPlanName == "free" {
            return [
                "Unlimited manual editing",
                "Source-available non-commercial use (BSL 1.1)"
            ]
        }
        if isProPlan {
            return [
                "AI Culling",
                "Smart Sync",
                "AI Masking",
                "Batch processing"
            ]
        }
        return [
            "AI features",
            "Account support"
        ]
    }

    private var buttonTitle: String {
        if isYearlyPlan { return "Choose Yearly" }
        if isProPlan { return "Upgrade to Pro" }
        return "Subscribe"
    }
}

struct PlanFeature: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.green)
            
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Credit Pack Card

struct CreditPackCard: View {
    let pack: CreditPackInfo
    let isLoading: Bool
    let onPurchase: () async -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Credits amount
            VStack(alignment: .leading, spacing: 2) {
                Text("\(pack.credits)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("credits")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .frame(width: 70, alignment: .leading)
            
            // Price per credit
            VStack(alignment: .leading, spacing: 2) {
                let perCredit = pack.price / Double(pack.credits)
                Text(String(format: "$%.2f", perCredit))
                    .font(.system(size: 12, weight: .medium))
                Text("per credit")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Buy button
            Button {
                Task {
                    await onPurchase()
                }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text(pack.priceFormatted)
                }
                .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(isLoading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.1))
        )
    }
}

// MARK: - Preview

#Preview {
    PlansView()
        .preferredColorScheme(.dark)
}
