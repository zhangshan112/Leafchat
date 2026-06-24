import SwiftUI

struct OnboardingView: View {

    /// Called when the user taps "Log In" or skips - routes to the login screen.
    var onComplete: () -> Void = {}

    /// Called when the user taps "Sign Up" on the final step - routes to the register screen.
    var onSignUp: () -> Void = {}

    @State private var step = 1
    @State private var selectedPlantIds: Set<String> = []

    private let totalSteps = 5

    var body: some View {
        VStack(spacing: 0) {
            topNavBar
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 20)

            ZStack {
                if step == 1 { welcomeStep.transition(stepTransition) }
                if step == 2 { aiIdentityStep.transition(stepTransition) }
                if step == 3 { gardenToolkitStep.transition(stepTransition) }
                if step == 4 { discoverCommunityStep.transition(stepTransition) }
                if step == 5 { plantSelectionStep.transition(stepTransition) }
            }
            .animation(.spring(response: 0.4), value: step)
        }
        .background(Color.phBackground.ignoresSafeArea())
    }

    // MARK: - Top Nav (Back · Progress · Skip)

    private var topNavBar: some View {
        HStack(spacing: 12) {
            Button { back() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .opacity(step > 1 ? 1 : 0)
            .disabled(step <= 1)
            .animation(.easeInOut(duration: 0.2), value: step)

            progressSegments

            Button { skip() } label: {
                Text("Skip")
                    .font(.captionText)
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .opacity(step < totalSteps ? 1 : 0)
            .disabled(step >= totalSteps)
            .animation(.easeInOut(duration: 0.2), value: step)
        }
    }

    private var progressSegments: some View {
        HStack(spacing: 6) {
            ForEach(1 ... totalSteps, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i <= step ? Color.primaryBlue : Color.phBorder)
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.3), value: step)
            }
        }
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal:   .move(edge: .leading).combined(with: .opacity)
        )
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .fill(Color.tagBackground)
                        .frame(width: 140, height: 140)
                    Circle()
                        .stroke(Color.primaryBlue.opacity(0.18), lineWidth: 1)
                        .frame(width: 108, height: 108)
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(Color.primaryBlue)
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color.neonPink)
                        .offset(x: 44, y: -40)
                }

                VStack(spacing: 12) {
                    Text("Meet \(AppBranding.name)")
                        .font(.largeTitle)
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Your AI plant companion for instant identification, health checks, personal collections, and a buzzing plant community.")
                        .font(.bodyText)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                }
            }

            Spacer()

            PrimaryButton(title: "Get Started") { advance() }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
        }
    }

    // MARK: - Step 2: AI Plant Intelligence

    private var aiIdentityStep: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    onboardingImage("onboarding-plants-world")

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Scan First, Guess Less")
                            .font(.pageTitle)
                            .foregroundStyle(Color.textPrimary)

                        Text("Open Identify, point your camera at a plant, and let on-device AI turn a photo into a name, care context, and the next best action.")
                            .font(.captionText)
                            .foregroundStyle(Color.textSecondary)
                            .lineSpacing(5)
                    }
                    .padding(.horizontal, 24)

                    HStack(spacing: 10) {
                        statBubble(value: "AI ID", label: "Instant answers")
                        statBubble(value: "Health", label: "Stress checks")
                        statBubble(value: "Private", label: "On-device AI")
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 16)
            }

            PrimaryButton(title: "Continue") { advance() }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 40)
        }
    }

    // MARK: - Step 3: Garden Toolkit

    private var gardenToolkitStep: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    onboardingImage("onboarding-plant-care")

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Build Your Living Collection")
                            .font(.pageTitle)
                            .foregroundStyle(Color.textPrimary)

                        Text("Save identified plants to My Garden, track your scan history, ask AI for care help, and keep trusted guides close by.")
                            .font(.captionText)
                            .foregroundStyle(Color.textSecondary)
                            .lineSpacing(5)
                    }
                    .padding(.horizontal, 24)

                    VStack(spacing: 12) {
                        infoRow(
                            icon: "plus.circle.fill",
                            tint: Color.primaryBlue,
                            title: "Add to My Garden",
                            description: "Collect plants from identification results and see your garden grow"
                        )
                        infoRow(
                            icon: "bubble.left.and.text.bubble.right.fill",
                            tint: Color.neonCyan,
                            title: "Ask AI",
                            description: "Get plant-specific care guidance from the Identify tab or plant pages"
                        )
                        infoRow(
                            icon: "book.closed.fill",
                            tint: Color.savedAmber,
                            title: "Plant Encyclopedia",
                            description: "Browse care guides and jump deeper into the plants you love"
                        )
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 16)
            }

            PrimaryButton(title: "Continue") { advance() }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 40)
        }
    }

    // MARK: - Step 4: Discover Community

    private var discoverCommunityStep: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    onboardingImage("onboarding-community")

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Discover What Others Grow")
                            .font(.pageTitle)
                            .foregroundStyle(Color.textPrimary)

                        Text("Explore real plant stories, trending specimens, garden plots, and care conversations from people growing alongside you.")
                            .font(.captionText)
                            .foregroundStyle(Color.textSecondary)
                            .lineSpacing(5)
                    }
                    .padding(.horizontal, 24)

                    VStack(spacing: 12) {
                        infoRow(
                            icon: "camera.fill",
                            tint: Color.neonPink,
                            title: "Share Discoveries",
                            description: "Turn your plant moments and AI results into posts"
                        )
                        infoRow(
                            icon: "safari.fill",
                            tint: Color.primaryBlue,
                            title: "Discover",
                            description: "Browse community pulse, trending plants, and themed garden plots"
                        )
                        infoRow(
                            icon: "message.fill",
                            tint: Color.neonCyan,
                            title: "Chat",
                            description: "Keep conversations flowing with fellow plant people"
                        )
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 16)
            }

            PrimaryButton(title: "Continue") { advance() }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 40)
        }
    }

    // MARK: - Step 5: Plant Interest Selection

    private var plantSelectionStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose Your Plant World")
                    .font(.pageTitle)
                    .foregroundStyle(Color.textPrimary)
                Text("Pick the plants you want to see more often. We'll use them to personalize your Discover feed after sign up.")
                    .font(.captionText)
                    .foregroundStyle(Color.textSecondary)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 24)

            plantTagGrid

            Spacer()

            VStack(spacing: 10) {
                PrimaryButton(title: "Sign Up for Free") {
                    onSignUp()
                }
                .padding(.horizontal, 24)

                Button { onComplete() } label: {
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .foregroundStyle(Color.textSecondary)
                        Text("Log In")
                            .foregroundStyle(Color.primaryBlue)
                            .fontWeight(.semibold)
                    }
                    .font(.captionText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                }
            }
            .padding(.bottom, 32)
        }
    }

    private var plantTagGrid: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 12
            ) {
                ForEach(OnboardingPlant.defaults) { plant in
                    Tag(
                        name: plant.name,
                        mode: .selectable,
                        isSelected: selectedPlantIds.contains(plant.id),
                        onToggle: { isSelected in
                            withAnimation(.spring(response: 0.25)) {
                                if isSelected {
                                    selectedPlantIds.insert(plant.id)
                                } else {
                                    selectedPlantIds.remove(plant.id)
                                }
                            }
                        }
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 24)
        }
        .frame(maxHeight: 320)
    }

    // MARK: - Shared Sub-components

    private func onboardingImage(_ name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 230)
            .clipped()
            .cornerRadius(20)
            .padding(.horizontal, 16)
    }

    private func statBubble(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.primaryBlue)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.smallText)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .background(Color.tagBackground)
        .cornerRadius(12)
    }

    private func infoRow(icon: String, tint: Color, title: String, description: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(tint.opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(description)
                    .font(.captionText)
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.phSurface)
        .cornerRadius(14)
    }

    // MARK: - Navigation

    private func advance() {
        guard step < totalSteps else { return }
        withAnimation(.spring(response: 0.4)) {
            step += 1
        }
    }

    private func back() {
        guard step > 1 else { return }
        withAnimation(.spring(response: 0.4)) {
            step -= 1
        }
    }

    private func skip() {
        onComplete()
    }
}

// MARK: - Mock data

private struct OnboardingPlant: Identifiable {
    let id: String
    let name: String

    static let defaults: [OnboardingPlant] = [
        .init(id: "p1",  name: "Monstera"),
        .init(id: "p2",  name: "Pothos"),
        .init(id: "p3",  name: "Philodendron"),
        .init(id: "p4",  name: "Alocasia"),
        .init(id: "p5",  name: "Snake Plant"),
        .init(id: "p6",  name: "ZZ Plant"),
        .init(id: "p7",  name: "Anthurium"),
        .init(id: "p8",  name: "Calathea"),
        .init(id: "p9",  name: "Fern"),
        .init(id: "p10", name: "Succulent"),
        .init(id: "p11", name: "Peace Lily"),
        .init(id: "p12", name: "Rubber Plant"),
    ]
}
