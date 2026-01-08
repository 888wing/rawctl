//
//  CreditsDetailView.swift
//  rawctl
//
//  Detailed view of credits usage and history
//

import SwiftUI

struct CreditsDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var accountService = AccountService.shared
    
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
                
                Text("Credits")
                    .font(.system(size: 13, weight: .semibold))
                
                Spacer()
                
                Button {
                    Task {
                        await accountService.loadCreditsBalance()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(white: 0.1))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Total credits
                    totalCreditsCard
                    
                    // Subscription credits
                    if let balance = accountService.creditsBalance {
                        subscriptionCreditsCard(balance.subscription)
                        
                        if balance.purchased.total > 0 {
                            purchasedCreditsCard(balance.purchased)
                        }
                    }
                    
                    // Credits cost info
                    creditsCostInfo
                }
                .padding()
            }
        }
        .frame(width: 360, height: 480)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Total Credits Card
    
    private var totalCreditsCard: some View {
        VStack(spacing: 8) {
            Text("Total Available")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            
            Text("\(accountService.creditsBalance?.totalRemaining ?? 0)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("credits")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.2), Color.accentColor.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
    
    // MARK: - Subscription Credits Card
    
    private func subscriptionCreditsCard(_ subscription: SubscriptionCredits) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                
                Text("Monthly Credits")
                    .font(.system(size: 12, weight: .semibold))
                
                Spacer()
                
                Text(subscription.plan.capitalized)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(white: 0.2))
                    .cornerRadius(4)
            }
            
            // Progress bar
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(white: 0.15))
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.accentColor)
                            .frame(width: geometry.size.width * progress(subscription))
                    }
                }
                .frame(height: 8)
                
                HStack {
                    Text("\(subscription.remaining) remaining")
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(subscription.used) used of \(subscription.total)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            // Reset date
            if let resetsAt = subscription.resetsAt {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10))
                    Text("Resets \(formatDate(resetsAt))")
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.1))
        )
    }
    
    // MARK: - Purchased Credits Card
    
    private func purchasedCreditsCard(_ purchased: PurchasedCredits) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bag")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
                
                Text("Purchased Credits")
                    .font(.system(size: 12, weight: .semibold))
                
                Spacer()
                
                Text("Never expire")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
            }
            
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(purchased.remaining)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                
                Text("of \(purchased.total) remaining")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.1))
        )
    }
    
    // MARK: - Credits Cost Info
    
    private var creditsCostInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Credit Costs")
                .font(.system(size: 12, weight: .semibold))
            
            VStack(spacing: 8) {
                CostRow(operation: "Nano Banana (1K)", credits: 1)
                CostRow(operation: "Nano Banana Pro (2K)", credits: 3)
                CostRow(operation: "Nano Banana Pro (4K)", credits: 6)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.08))
        )
    }
    
    // MARK: - Helpers
    
    private func progress(_ subscription: SubscriptionCredits) -> Double {
        guard subscription.total > 0 else { return 0 }
        return Double(subscription.remaining) / Double(subscription.total)
    }
    
    private func formatDate(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Cost Row

struct CostRow: View {
    let operation: String
    let credits: Int
    
    var body: some View {
        HStack {
            Text(operation)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: 4) {
                Text("\(credits)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                Image(systemName: "sparkle")
                    .font(.system(size: 9))
            }
            .foregroundColor(.primary)
        }
    }
}

// MARK: - Preview

#Preview {
    CreditsDetailView()
        .preferredColorScheme(.dark)
}
