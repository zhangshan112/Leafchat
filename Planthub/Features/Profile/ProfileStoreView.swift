import StoreKit
import SwiftUI

private enum StoreTab: String, CaseIterable, Identifiable {
    case subscriptions = "Subscriptions"
    case credits = "ID Credits"

    var id: String { rawValue }
}

struct ProfileStoreView: View {
    @Bindable private var iapManager = IAPManager.shared
    @Bindable private var entitlements = EntitlementStore.shared

    @State private var selectedTab: StoreTab = .subscriptions
    @State private var showManageSubscriptions = false
    @State private var purchaseErrorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                membershipStatusCard
                tabPicker
                tabContent
                if selectedTab == .subscriptions {
                    restoreSection
                    legalSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color.phBackground)
        .task {
            await iapManager.loadProducts()
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
        .alert(
            "Purchase Error",
            isPresented: Binding(
                get: { purchaseErrorMessage != nil },
                set: { if !$0 { purchaseErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchaseErrorMessage ?? "")
        }
    }

    private var membershipStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(entitlements.hasActiveSubscription ? Color.primaryBlue.opacity(0.12) : Color.textSecondary.opacity(0.08))
                        .frame(width: 44, height: 44)

                    Image(systemName: entitlements.hasActiveSubscription ? "crown.fill" : "leaf")
                        .font(.system(size: 18))
                        .foregroundStyle(entitlements.hasActiveSubscription ? Color.primaryBlue : Color.textSecondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(entitlements.subscriptionTier.displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)

                    if entitlements.hasActiveSubscription, let expiresAt = entitlements.premiumExpiresAt {
                        Text("Renews \(expiresAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    } else {
                        Text("Unlock more monthly IDs and posting limits")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                }

                Spacer()

                if entitlements.hasActiveSubscription {
                    Button {
                        showManageSubscriptions = true
                    } label: {
                        Text("Manage")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.primaryBlue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.primaryBlue.opacity(0.08))
                            .clipShape(Capsule())
                    }
                }
            }

            if entitlements.subscriptionTier != .advanced {
                Divider()

                HStack(spacing: 20) {
                    statPill(
                        value: "\(entitlements.subscriptionTier == .basic ? entitlements.remainingBasicIdentifications : entitlements.remainingFreeIdentifications)",
                        label: entitlements.subscriptionTier == .basic ? "Member IDs" : "Free IDs",
                        icon: "camera.viewfinder"
                    )
                    statPill(
                        value: "\(entitlements.remainingPostsThisMonth ?? 0)",
                        label: "Posts Left",
                        icon: "square.and.pencil"
                    )
                    statPill(
                        value: "\(entitlements.identificationCredits)",
                        label: "Credits",
                        icon: "sparkles"
                    )
                }
            }

            if entitlements.hasActiveSubscription && entitlements.subscriptionTier == .advanced {
                Divider()

                HStack(spacing: 8) {
                    Image(systemName: "infinity")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.primaryBlue)
                    Text("Unlimited posts and AI identification")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.primaryBlue)
                }
            }
        }
        .padding(16)
        .background(Color.phSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primaryBlue.opacity(0.10), lineWidth: 1)
        )
    }

    private var tabPicker: some View {
        Picker("Store", selection: $selectedTab) {
            ForEach(StoreTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .subscriptions:
            subscriptionSection
        case .credits:
            creditsSection
        }
    }

    private var subscriptionSection: some View {
        VStack(spacing: 20) {
            benefitsSummaryCard

            if iapManager.isLoadingProducts && iapManager.storeProducts.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(Color.primaryBlue)
                    Text("Loading plans…")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            }

            tierBanner(
                title: "Basic",
                subtitle: "Higher monthly limits for active creators",
                features: [
                    "Up to \(EntitlementStore.basicPostsPerMonth) posts per month",
                    "\(EntitlementStore.basicIdentificationsPerMonth) member AI identifications each month",
                    "Buy additional ID credits when needed",
                ],
                accent: Color.neonCyan,
                listings: IAPProductCatalog.basicSubscriptionListings
            )

            tierBanner(
                title: "Plus",
                subtitle: "Unlimited posting and AI identification",
                features: [
                    "All Basic features included",
                    "Unlimited posts",
                    "Unlimited AI plant identification",
                    "Plus member badge on your profile",
                ],
                accent: Color.primaryBlue,
                listings: IAPProductCatalog.advancedSubscriptionListings
            )

            Text("Payment will be charged to your Apple ID account. Subscription automatically renews unless cancelled at least 24 hours before the current period ends. Manage or cancel anytime in Settings > Apple ID > Subscriptions.")
                .font(.system(size: 11))
                .foregroundStyle(Color.textSecondary)
                .padding(.top, 4)
        }
    }

    private var benefitsSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Membership Benefits")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.textPrimary)

            Text("Basic increases monthly posting and identification limits. Plus unlocks unlimited posts and unlimited AI identification.")
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.surfaceViolet)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primaryBlue.opacity(0.12), lineWidth: 1)
        )
    }

    private func tierBanner(
        title: String,
        subtitle: String,
        features: [String],
        accent: Color,
        listings: [IAPProductCatalog.SubscriptionListing]
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(features, id: \.self) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(accent)
                        Text(feature)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textPrimary)
                    }
                }
            }

            if entitlements.subscriptionTier.displayName.contains(title) && entitlements.hasActiveSubscription {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(accent)
                    Text("Current plan")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(accent.opacity(0.08))
                .clipShape(Capsule())
            } else {
                ForEach(listings) { listing in
                    subscriptionCard(listing, accent: accent)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.phSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(accent.opacity(0.15), lineWidth: 1)
        )
    }

    private func subscriptionCard(
        _ listing: IAPProductCatalog.SubscriptionListing,
        accent: Color
    ) -> some View {
        Button {
            purchase(displayProductID: listing.id)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(listing.periodLabel)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text(listing.subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                if iapManager.isPurchasing {
                    ProgressView()
                        .tint(accent)
                } else {
                    Text(priceLabel(for: listing))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(accent)
                    Text("/\(listing.periodLabel.lowercased())")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(accent.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(accent.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(iapManager.isPurchasing)
    }

    private var creditsSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Identification Credits")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Text("Use credits for AI identification after monthly free/member allowances are used. Credits never expire and each credit equals one identification.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if entitlements.identificationCredits > 0 {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.neonCyan)
                    Text("Available: **\(formattedCredits(entitlements.identificationCredits))** credits")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                }
                .padding(14)
                .background(Color.surfaceCyan)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if iapManager.isLoadingProducts && iapManager.storeProducts.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(Color.primaryBlue)
                    Text("Loading packs…")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(IAPProductCatalog.consumableListings) { listing in
                    consumableCard(listing)
                }
            }
        }
    }

    private func consumableCard(_ listing: IAPProductCatalog.ConsumableListing) -> some View {
        Button {
            purchase(displayProductID: listing.id)
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.neonCyan.opacity(0.08))
                        .frame(width: 40, height: 40)

                    Image(systemName: "sparkles")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.neonCyan)
                }

                Text("\(formattedCredits(listing.credits))")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Text("Credits")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textSecondary)

                if iapManager.isPurchasing {
                    ProgressView()
                        .tint(Color.neonCyan)
                        .padding(.top, 4)
                } else {
                    Text(priceLabel(for: listing))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.neonCyan)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 12)
            .background(Color.phSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.neonCyan.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(iapManager.isPurchasing)
    }

    private var restoreSection: some View {
        Button {
            Task { await iapManager.restorePurchases() }
        } label: {
            HStack(spacing: 8) {
                if iapManager.isRestoring {
                    ProgressView()
                        .tint(Color.primaryBlue)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                    Text("Restore Purchases")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .foregroundStyle(Color.primaryBlue)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(Color.primaryBlue.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(iapManager.isRestoring)
    }

    private var legalSection: some View {
        HStack(spacing: 24) {
            NavigationLink("Terms of Service") {
                LegalPlaceholderView(title: "Terms of Service", url: LegalLinks.termsOfService)
            }
            NavigationLink("Privacy Policy") {
                LegalPlaceholderView(title: "Privacy Policy", url: LegalLinks.privacyPolicy)
            }
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(Color.primaryBlue)
        .frame(maxWidth: .infinity)
        .padding(.bottom, 16)
    }

    private func statPill(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(Color.primaryBlue)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.primaryBlue)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    private func priceLabel(for listing: IAPProductCatalog.SubscriptionListing) -> String {
        if IAPConfig.useTestProductCatalog {
            return listing.referencePrice
        }
        if let storeID = IAPProductCatalog.storeProductID(for: listing.id),
           let product = iapManager.storeProduct(id: storeID) {
            return product.displayPrice
        }
        return listing.referencePrice
    }

    private func priceLabel(for listing: IAPProductCatalog.ConsumableListing) -> String {
        if IAPConfig.useTestProductCatalog {
            return listing.referencePrice
        }
        if let storeID = IAPProductCatalog.storeProductID(for: listing.id),
           let product = iapManager.storeProduct(id: storeID) {
            return product.displayPrice
        }
        return listing.referencePrice
    }

    private func formattedCredits(_ count: Int) -> String {
        Self.creditsFormatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }

    private static let creditsFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    private func purchase(displayProductID: String) {
        Task {
            do {
                try await iapManager.purchase(displayProductID: displayProductID)
            } catch IAPError.purchaseCancelled {
                return
            } catch {
                purchaseErrorMessage = error.localizedDescription
            }
        }
    }
}
