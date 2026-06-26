import StoreKit
import SwiftUI

struct MembershipView: View {
    @Bindable private var entitlements = EntitlementStore.shared
    @Bindable private var iapManager = IAPManager.shared

    @State private var showPaywall = false
    @State private var showManageSubscriptions = false

    var body: some View {
        List {
            Section {
                membershipStatusCard
            }

            Section("Benefits") {
                benefitItem(
                    icon: "square.and.pencil",
                    title: "Monthly Post Limit",
                    subtitle: postBenefitText
                )
                benefitItem(
                    icon: "camera.viewfinder",
                    title: "AI Actions",
                    subtitle: identificationBenefitText
                )
                benefitItem(
                    icon: "tree.fill",
                    title: "Plus Member Badge",
                    subtitle: entitlements.subscriptionTier == .advanced
                        ? "Visible on your profile"
                        : "Included with LeafChat Plus (Advanced)"
                )
            }

            Section {
                if entitlements.hasActiveSubscription {
                    Button {
                        showManageSubscriptions = true
                    } label: {
                        Label("Manage Subscription", systemImage: "creditcard")
                    }
                } else {
                    Button {
                        showPaywall = true
                    } label: {
                        Label("View Plans", systemImage: "sparkles")
                    }
                }

                Button {
                    Task { await iapManager.restorePurchases() }
                } label: {
                    HStack {
                        Label("Restore Purchases", systemImage: "arrow.clockwise")
                        Spacer()
                        if iapManager.isRestoring {
                            ProgressView()
                                .tint(Color.primaryBlue)
                        }
                    }
                }
                .disabled(iapManager.isRestoring)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.phBackground)
        .navigationTitle("Membership")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView(source: .membership)
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
    }

    private var membershipStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: entitlements.hasActiveSubscription ? "checkmark.seal.fill" : "tree")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.primaryBlue)

                Text(entitlements.subscriptionTier.displayName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
            }

            if entitlements.hasActiveSubscription, let expiresAt = entitlements.premiumExpiresAt {
                Text("Renews \(expiresAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            } else if !entitlements.hasActiveSubscription {
                Text("Choose Basic for higher monthly post and AI action limits, or Plus for unlimited usage.")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }

            if entitlements.subscriptionTier != .advanced {
                HStack(spacing: 16) {
                    statPill(
                        value: "\(entitlements.subscriptionTier == .basic ? entitlements.remainingBasicIdentifications : entitlements.remainingFreeIdentifications)",
                        label: entitlements.subscriptionTier == .basic ? "Member AI left" : "Free AI left"
                    )
                    statPill(
                        value: "\(entitlements.remainingPostsThisMonth ?? 0)",
                        label: "Posts left"
                    )
                    statPill(
                        value: "\(entitlements.identificationCredits)",
                        label: "AI Credits"
                    )
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }

    private var identificationBenefitText: String {
        if entitlements.subscriptionTier == .advanced {
            return "Unlimited AI actions"
        }
        if entitlements.subscriptionTier == .basic {
            return "\(EntitlementStore.basicIdentificationsPerMonth) member AI actions each month + AI Credits"
        }

        var parts: [String] = []
        parts.append("\(entitlements.remainingFreeIdentifications) free AI actions this month")
        if entitlements.identificationCredits > 0 {
            parts.append("\(entitlements.identificationCredits) AI credits")
        }
        return parts.joined(separator: " · ")
    }

    private var postBenefitText: String {
        if entitlements.subscriptionTier == .advanced {
            return "Unlimited posts"
        }
        let limit = entitlements.monthlyPostLimit ?? EntitlementStore.freePostsPerMonth
        let remaining = entitlements.remainingPostsThisMonth ?? 0
        if entitlements.subscriptionTier == .basic {
            return "\(remaining) of \(limit) posts left this month"
        }
        return "Free users can publish up to \(limit) posts per month"
    }

    private func benefitItem(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.primaryBlue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.primaryBlue)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.tagBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
