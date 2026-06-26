import SwiftUI
import FoundationModels

// MARK: - IdentifyView
//
// "Aurora Scanner Lab" - an immersive identity surface built around a single,
// breathing scanner orb as the hero CTA. Floating aurora light, glass bento
// tools, and a sleek access banner replace the old card-stack layout while
// keeping every original action intact.

@available(iOS 26, *)
struct IdentifyView: View {

    @Bindable private var entitlements = EntitlementStore.shared

    @State private var showIdentification = false
    @State private var showHealthDiagnosis = false
    @State private var showAIChat = false
    @State private var showHistory = false
    @State private var navigationPath = NavigationPath()

    // Animation drivers
    @State private var orbPulse = false
    @State private var ringRotate = false
    @State private var scanSweep = false
    @State private var auroraShift = false
    @State private var appeared = false
    @State private var heroImageIndex = 0

    private let heroPlantImages = [
        "plant-monstera",
        "plant-golden-pothos",
        "plant-anthurium",
        "plant-alocasia-polly",
        "plant-boston-fern",
        "plant-peace-lily"
    ]

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                auroraBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 26) {
                        topBar
                        heroScanner
                        accessBanner
                        bentoTools
                        Spacer(minLength: 16)
                    }
                    .padding(.bottom, 36)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: IdentificationRecord.self) { record in
                IdentificationHistoryView(initialRecord: record)
            }
            .sheet(isPresented: $showIdentification) {
                PlantIdentificationView()
            }
            .sheet(isPresented: $showHealthDiagnosis) {
                PlantHealthDiagnosisView()
            }
            .sheet(isPresented: $showAIChat) {
                PlantAIChatView(plantName: nil)
            }
            .sheet(isPresented: $showHistory) {
                IdentificationHistoryView(initialRecord: nil)
            }
            .onAppear(perform: startAnimations)
            .task { await rotateHeroPlantImages() }
        }
    }

    // MARK: - Animated Aurora Background

    private var auroraBackground: some View {
        ZStack {
            Color.phBackground

            // Floating colour blobs that drift slowly to feel alive.
            auroraBlob(Color.primaryBlue, size: 360)
                .offset(x: auroraShift ? -120 : -150, y: auroraShift ? -260 : -300)
            auroraBlob(Color.neonPink, size: 300)
                .offset(x: auroraShift ? 150 : 120, y: auroraShift ? -150 : -120)
            auroraBlob(Color.neonCyan, size: 280)
                .offset(x: auroraShift ? 120 : 160, y: auroraShift ? 120 : 80)
        }
    }

    private func auroraBlob(_ color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(color.opacity(0.30))
            .frame(width: size, height: size)
            .blur(radius: 90)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                    Text("AI PLANT LAB")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.4)
                }
                .foregroundStyle(Color.primaryBlue)

                Text("Identify")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
            }

            Spacer()

            HStack(spacing: 10) {
                modelStatusBadge
                Button {
                    showHistory = true
                } label: {
                    Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.primaryBlue)
                        .frame(width: 42, height: 42)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().strokeBorder(Color.primaryBlue.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    @ViewBuilder
    private var modelStatusBadge: some View {
        if SystemLanguageModel.default.isAvailable {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.neonCyan)
                    .frame(width: 6, height: 6)
                    .shadow(color: Color.neonCyan.opacity(0.8), radius: 4)
                Text("On-device")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.neonCyan)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.neonCyan.opacity(0.35), lineWidth: 1))
        }
    }

    // MARK: - Hero Scanner (the centrepiece)

    private var heroScanner: some View {
        Button(action: checkAccessAndIdentify) {
            ZStack {
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentBlack,
                                Color.primaryBlue.opacity(0.68),
                                Color.neonPink.opacity(0.45)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentBlack.opacity(0.64),
                                Color.primaryBlue.opacity(0.30),
                                Color.accentBlack.opacity(0.82)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottom
                        )
                    )

                // Keep ambient light on the edges so the central scanner remains clean.
                Circle()
                    .fill(Color.neonCyan.opacity(0.20))
                    .frame(width: 250, height: 250)
                    .blur(radius: 74)
                    .offset(x: -142, y: -180)
                Circle()
                    .fill(Color.neonPink.opacity(0.22))
                    .frame(width: 230, height: 230)
                    .blur(radius: 72)
                    .offset(x: 150, y: 190)

                VStack(spacing: 18) {
                    scannerHeaderRow
                    scannerOrb
                    scannerFooter
                }
                .padding(22)
            }
            .frame(height: 468)
            .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.40),
                                Color.neonCyan.opacity(0.20),
                                Color.neonPink.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.primaryBlue.opacity(0.34), radius: 34, x: 0, y: 18)
            .shadow(color: Color.neonPink.opacity(0.18), radius: 18, x: 0, y: 8)
        }
        .buttonStyle(ScalePressStyle())
        .padding(.horizontal, 20)
        .scaleEffect(appeared ? 1 : 0.92)
        .opacity(appeared ? 1 : 0)
    }

    private var scannerPanelPlantBackground: some View {
        RoundedRectangle(cornerRadius: 34, style: .continuous)
            .fill(Color.accentBlack)
            .overlay {
                Image(heroPlantImages[heroImageIndex])
                    .resizable()
                    .scaledToFill()
                    .frame(width: 246, height: 246)
                    .clipped()
                    .id(heroImageIndex)
                    .transition(.opacity)
            }
            .overlay {
                LinearGradient(
                    colors: [
                        Color.accentBlack.opacity(0.28),
                        Color.accentBlack.opacity(0.64)
                    ],
                    startPoint: .top,
                    endPoint: .bottomTrailing
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
    }

    private var scannerHeaderRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Scanner")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.58))
                    .textCase(.uppercase)
                    .tracking(1.1)
                Text("Live plant analysis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Spacer()

            HStack(spacing: 8) {
                heroChip("Fast", icon: "bolt.fill")
                heroChip("Private", icon: "lock.fill")
            }
        }
    }

    private var scannerFooter: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Identify in seconds")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text("Scan a leaf, flower, or stem to get the name and care context.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.66))
                    .lineSpacing(2)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            heroCTA
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.accentBlack.opacity(0.24), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    private var scannerOrb: some View {
        ZStack {
            scannerPanelPlantBackground
                .frame(width: 246, height: 246)
                .shadow(color: Color.accentBlack.opacity(0.34), radius: 24, x: 0, y: 14)
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .strokeBorder(
                            AngularGradient(
                                colors: [
                                    Color.neonCyan,
                                    Color.primaryBlue,
                                    Color.neonPink,
                                    Color.neonCyan
                                ],
                                center: .center
                            ),
                            lineWidth: 3
                        )
                )

            Image(systemName: "viewfinder")
                .font(.system(size: 74, weight: .light))
                .foregroundStyle(.white.opacity(0.86))
                .shadow(color: Color.neonCyan.opacity(0.35), radius: 8)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.82), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 226, height: 1.5)
                .offset(y: scanSweep ? 68 : -68)
                .shadow(color: Color.neonCyan.opacity(0.45), radius: 8)

        }
        .frame(maxWidth: .infinity)
        .frame(height: 246)
    }

    private var scanLine: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, Color.neonCyan.opacity(0.9), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: 60)
            .shadow(color: Color.neonCyan.opacity(0.8), radius: 10)
            .offset(y: scanSweep ? 60 : -60)
    }

    private var heroCTA: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 54, height: 54)
                .shadow(color: Color.neonCyan.opacity(0.45), radius: 16)
            Image(systemName: "arrow.up.right")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.primaryBlue)
        }
        .overlay(
            Circle()
                .strokeBorder(Color.neonCyan.opacity(0.30), lineWidth: 1)
                .scaleEffect(orbPulse ? 1.24 : 1)
                .opacity(orbPulse ? 0 : 0.8)
        )
    }

    private func heroChip(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(title)
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
    }

    // MARK: - Access Banner

    private var accessBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accessTint.opacity(0.16))
                    .frame(width: 46, height: 46)
                Image(systemName: accessIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accessTint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(accessTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Text(accessSubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            if entitlements.aiActionAccess() == .denied {
                Text("Get credits")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(accessTint, in: Capsule())
            } else {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(accessTint)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(accessTint.opacity(0.22), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .onTapGesture {
            if entitlements.aiActionAccess() == .denied {
                PaywallPresenter.shared.present(source: .identification, tab: .consumables)
            }
        }
    }

    // MARK: - Bento Tools

    private var bentoTools: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("Care Toolkit")
                    .font(.sectionTitle)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text("\(PlantWikiModel.plants.count)+ guides")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, 20)

            HStack(spacing: 12) {
                // Tall featured health card
                bentoCard(
                    icon: "heart.text.square.fill",
                    title: "Health Scan",
                    subtitle: "Spot pests, yellowing & watering stress",
                    tint: Color.hotCoral,
                    tall: true
                ) { showHealthDiagnosis = true }

                VStack(spacing: 12) {
                    bentoCard(
                        icon: "bubble.left.and.text.bubble.right.fill",
                        title: "Ask AI",
                        subtitle: "Care advice",
                        tint: Color.neonCyan,
                        tall: false
                    ) { showAIChat = true }

                    bentoCard(
                        icon: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                        title: "History",
                        subtitle: "Past scans",
                        tint: Color.savedAmber,
                        tall: false
                    ) { showHistory = true }
                }
            }
            .padding(.horizontal, 20)

            // Wide encyclopedia card
            Button {
                AppTabRouter.shared.openPlantEncyclopedia()
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.primaryBlue.opacity(0.14))
                            .frame(width: 48, height: 48)
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.primaryBlue)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Plant Encyclopedia")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Text("Browse care guides & build your knowledge base")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.primaryBlue.opacity(0.18), lineWidth: 1)
                )
            }
            .buttonStyle(ScalePressStyle())
            .padding(.horizontal, 20)
        }
    }

    private func bentoCard(
        icon: String,
        title: String,
        subtitle: String,
        tint: Color,
        tall: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: tall ? 14 : 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(tint.opacity(0.16))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(tint)
                }

                if tall { Spacer(minLength: 0) }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: tall ? 18 : 15, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(tall ? 3 : 1)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: tall ? 188 : 88)
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(tint.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(ScalePressStyle())
    }

    // MARK: - Access state

    private var accessIcon: String {
        switch entitlements.aiActionAccess() {
        case .unlimited: return "infinity"
        case .basicQuota: return "bolt.fill"
        case .consumableCredit: return "ticket.fill"
        case .freeQuota: return "gift.fill"
        case .denied: return "lock.fill"
        }
    }

    private var accessTitle: String {
        switch entitlements.aiActionAccess() {
        case .unlimited: return "Unlimited"
        case .basicQuota: return "Member AI Actions"
        case .consumableCredit: return "AI Credits"
        case .freeQuota: return "Free AI Actions"
        case .denied: return "Locked"
        }
    }

    private var accessSubtitle: String {
        switch entitlements.aiActionAccess() {
        case .unlimited:
            return "Ready anytime"
        case .basicQuota:
            return "\(entitlements.remainingBasicIdentifications) left"
        case .consumableCredit:
            return "\(entitlements.identificationCredits) AI credits"
        case .freeQuota:
            return "\(entitlements.remainingFreeIdentifications) left"
        case .denied:
            return "Get more AI Credits"
        }
    }

    private var accessTint: Color {
        switch entitlements.aiActionAccess() {
        case .unlimited, .basicQuota: return Color.primaryBlue
        case .consumableCredit: return Color.neonCyan
        case .freeQuota: return Color.savedAmber
        case .denied: return Color.hotCoral
        }
    }

    // MARK: - Actions

    private func checkAccessAndIdentify() {
        let access = entitlements.aiActionAccess()
        if access == .denied {
            PaywallPresenter.shared.present(source: .identification, tab: .consumables)
        } else {
            showIdentification = true
        }
    }

    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.6)) {
            appeared = true
        }
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            orbPulse = true
        }
        withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) {
            ringRotate = true
        }
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            scanSweep = true
        }
        withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
            auroraShift = true
        }
    }

    private func rotateHeroPlantImages() async {
        guard heroPlantImages.count > 1 else { return }

        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.9)) {
                heroImageIndex = (heroImageIndex + 1) % heroPlantImages.count
            }
        }
    }
}

// MARK: - Press feedback style

private struct ScalePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - IdentificationRecord: Hashable for NavigationStack

extension IdentificationRecord: Hashable {
    static func == (lhs: IdentificationRecord, rhs: IdentificationRecord) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
