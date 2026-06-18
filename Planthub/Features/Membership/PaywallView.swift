import StoreKit
import SwiftUI

struct PaywallView: View {
    let source: PaywallSource
    let initialTab: PaywallTab

    @Environment(\.dismiss) private var dismiss
    @Bindable private var iapManager = IAPManager.shared
    @Bindable private var entitlements = EntitlementStore.shared

    @State private var selectedTab: PaywallTab
    @State private var purchaseErrorMessage: String?

    init(source: PaywallSource, initialTab: PaywallTab = .subscription) {
        self.source = source
        self.initialTab = initialTab
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heroSection
                    tabPicker
                    tabContent
                    restoreSection
                    legalSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color.phBackground)
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.primaryBlue)
                        .disabled(iapManager.isPurchasing)
                }
            }
            .task {
                await iapManager.loadProducts()
            }
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
            .authLoadingOverlay(
                isPresented: iapManager.isPurchasing,
                message: "Processing purchase..."
            )
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.primaryBlue)
                Text("LeafChat Plus")
                    .font(.pageTitle)
                    .foregroundStyle(Color.textPrimary)
            }

            Text(heroSubtitle)
                .font(.body)
                .foregroundStyle(Color.textSecondary)

            VStack(alignment: .leading, spacing: 8) {
                benefitRow("Basic — up to \(EntitlementStore.basicPostsPerMonth) posts + \(EntitlementStore.basicIdentificationsPerMonth) member IDs each month")
                benefitRow("Plus — unlimited posts, unlimited AI identification, and member badge")
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.phSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primaryBlue.opacity(0.12), lineWidth: 1)
        )
    }

    private var heroSubtitle: String {
        switch source {
        case .encyclopedia:
            "Get higher monthly posting and identification limits with Basic, or unlimited usage with Plus."
        case .identification:
            "Use Basic monthly IDs, upgrade to Plus for unlimited usage, or buy credit packs."
        case .settings, .membership:
            "Unlock more posting and identification power."
        }
    }

    private var tabPicker: some View {
        Picker("Plan", selection: $selectedTab) {
            ForEach(PaywallTab.allCases) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .subscription:
            subscriptionSection
        case .consumables:
            consumablesSection
        }
    }

    private var subscriptionSection: some View {
        VStack(spacing: 16) {
            if iapManager.isLoadingProducts && iapManager.storeProducts.isEmpty {
                ProgressView("Loading plans…")
                    .tint(Color.primaryBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }

            subscriptionTierSection(
                title: "Basic",
                subtitle: "Higher monthly post and identification limits",
                listings: IAPProductCatalog.basicSubscriptionListings,
                accent: Color.neonCyan
            )

            subscriptionTierSection(
                title: "Plus",
                subtitle: "Unlimited posts + unlimited AI identification + badge",
                listings: IAPProductCatalog.advancedSubscriptionListings,
                accent: Color.primaryBlue
            )

            if entitlements.hasActiveSubscription {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.primaryBlue)
                    Text("Active plan: \(entitlements.subscriptionTier.displayName)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.tagBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Text("Payment will be charged to your Apple ID account. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in Settings > Apple ID > Subscriptions.")
                .font(.system(size: 11))
                .foregroundStyle(Color.textSecondary)
        }
    }

    private func subscriptionTierSection(
        title: String,
        subtitle: String,
        listings: [IAPProductCatalog.SubscriptionListing],
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }

            ForEach(listings) { listing in
                subscriptionCard(listing, accent: accent)
            }
        }
    }

    private var consumablesSection: some View {
        VStack(spacing: 12) {
            Text("Buy credit packs for AI plant identification after monthly allowances are used. Credits never expire and each credit equals one identification.")
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if iapManager.isLoadingProducts && iapManager.storeProducts.isEmpty {
                ProgressView("Loading packs…")
                    .tint(Color.primaryBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }

            ForEach(IAPProductCatalog.consumableListings) { listing in
                consumableCard(listing)
            }

            HStack(spacing: 8) {
                Image(systemName: "camera.viewfinder")
                    .foregroundStyle(Color.neonCyan)
                Text("You have \(formattedCredits(entitlements.identificationCredits)) credit\(entitlements.identificationCredits == 1 ? "" : "s") remaining.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.surfaceCyan)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var restoreSection: some View {
        Button {
            Task { await iapManager.restorePurchases() }
        } label: {
            HStack {
                Spacer()
                if iapManager.isRestoring {
                    ProgressView()
                        .tint(Color.primaryBlue)
                } else {
                    Text("Restore Purchases")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.primaryBlue)
                }
                Spacer()
            }
            .frame(height: 48)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primaryBlue, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(iapManager.isRestoring)
    }

    private var legalSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                NavigationLink("Terms of Service") {
                    LegalPlaceholderView(title: "Terms of Service", url: LegalLinks.termsOfService)
                }
                NavigationLink("Privacy Policy") {
                    LegalPlaceholderView(title: "Privacy Policy", url: LegalLinks.privacyPolicy)
                }
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.primaryBlue)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }

    private func benefitRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.primaryBlue)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Color.textPrimary)
        }
    }

    private func subscriptionCard(
        _ listing: IAPProductCatalog.SubscriptionListing,
        accent: Color
    ) -> some View {
        let subscriptionsLocked = entitlements.hasActiveSubscription
        let isCurrentPlan = subscriptionsLocked && listing.tier == entitlements.subscriptionTier

        return Button {
            guard !subscriptionsLocked else { return }
            purchase(displayProductID: listing.id)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(listing.periodLabel) · \(listing.title)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(subscriptionsLocked ? Color.textSecondary : Color.textPrimary)
                    Text(listing.subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                if subscriptionsLocked {
                    Text(isCurrentPlan ? "Current plan" : "Subscribed")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isCurrentPlan ? accent : Color.textSecondary)
                } else {
                    Text(priceLabel(for: listing))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(accent)
                }
            }
            .padding(16)
            .background(Color.phSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(accent.opacity(subscriptionsLocked ? 0.10 : 0.20), lineWidth: 1)
            )
            .opacity(subscriptionsLocked && !isCurrentPlan ? 0.72 : 1)
        }
        .buttonStyle(.plain)
        .disabled(iapManager.isPurchasing || subscriptionsLocked)
    }

    private func consumableCard(_ listing: IAPProductCatalog.ConsumableListing) -> some View {
        Button {
            purchase(displayProductID: listing.id)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(listing.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text("\(formattedCredits(listing.credits)) credits")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
                Text(priceLabel(for: listing))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.neonCyan)
            }
            .padding(16)
            .background(Color.phSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.neonCyan.opacity(0.20), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(iapManager.isPurchasing)
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
