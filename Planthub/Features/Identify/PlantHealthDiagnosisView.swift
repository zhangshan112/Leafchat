import SwiftUI
import PhotosUI
import Vision
import FoundationModels

// MARK: - Health Diagnosis Models (iOS 26+)

@available(iOS 26, *)
@Generable
struct PlantHealthResult {
    @Guide(description: "The overall health status: 'Healthy', 'Minor Issues', 'Needs Attention', or 'Critical'")
    var overallStatus: String

    @Guide(description: "Detected issue: e.g. 'Root rot', 'Spider mites', 'Nitrogen deficiency', 'Overwatering', or 'None detected'. Be specific.")
    var detectedIssue: String

    @Guide(description: "Brief explanation of what the issue is and its likely cause, in 1–2 sentences.")
    var issueExplanation: String

    @Guide(description: "The most important immediate action the user should take right now. One clear instruction.")
    var immediateAction: String

    @Guide(description: "Two follow-up care steps the user should take over the next week. Separate with a pipe character |")
    var followUpSteps: String

    @Guide(description: "Estimated recovery time if the user follows the advice, e.g. '2–3 weeks' or 'Permanent damage'")
    var recoveryEstimate: String
}

// MARK: - PlantHealthDiagnosisService

@available(iOS 26, *)
@Observable
final class PlantHealthDiagnosisService {

    enum State {
        case idle
        case analyzing
        case result(PlantHealthResult)
        case error(String)
    }

    var state: State = .idle

    private let languageModel = SystemLanguageModel.default

    func diagnose(image: UIImage) async {
        state = .analyzing

        do {
            guard let ciImage = CIImage(image: image) else {
                state = .error("Unable to process the image. Please try again.")
                return
            }

            let request = ClassifyImageRequest()
            let observations = try await request.perform(on: ciImage)
            let labels = observations
                .filter { $0.hasMinimumPrecision(0.05, forRecall: 0.9) }
                .prefix(12)
                .map { "\($0.identifier) (\(Int($0.confidence * 100))%)" }
                .joined(separator: ", ")

            if languageModel.isAvailable {
                let session = LanguageModelSession()
                let result = try await session.respond(
                    generating: PlantHealthResult.self
                ) {
                    """
                    You are an expert plant pathologist and horticulturalist.

                    A user photographed their plant and the Vision framework classified these image labels:
                    \(labels)

                    Your task: Diagnose the plant's health condition based on these visual cues.
                    - Look for signs of yellowing, spots, wilting, dryness, pests, mold, root issues, or discoloration
                    - If labels suggest a healthy, green, thriving plant with no stress signals, return 'Healthy' status
                    - Be practical and actionable — this user wants to save their plant
                    - Do not invent issues that aren't suggested by the labels
                    """
                }
                state = .result(result.content)
            } else {
                state = .result(visionFallbackDiagnosis(labels: labels))
            }
        } catch {
            state = .error("Diagnosis failed. Please try a clearer photo in good lighting.")
        }
    }

    func reset() { state = .idle }

    private func visionFallbackDiagnosis(labels: String) -> PlantHealthResult {
        let lower = labels.lowercased()
        let hasYellow = lower.contains("yellow") || lower.contains("pale")
        let hasDry = lower.contains("dry") || lower.contains("brown") || lower.contains("crisp")
        let hasMold = lower.contains("mold") || lower.contains("fungus") || lower.contains("white")
        let hasPest = lower.contains("insect") || lower.contains("pest") || lower.contains("mite")

        if hasPest {
            return PlantHealthResult(
                overallStatus: "Needs Attention",
                detectedIssue: "Possible pest infestation",
                issueExplanation: "Visual analysis detected patterns consistent with pest activity on the foliage.",
                immediateAction: "Isolate the plant immediately and inspect the undersides of leaves with a magnifying glass.",
                followUpSteps: "Apply neem oil or insecticidal soap | Remove heavily affected leaves",
                recoveryEstimate: "2–4 weeks with treatment"
            )
        } else if hasMold {
            return PlantHealthResult(
                overallStatus: "Needs Attention",
                detectedIssue: "Fungal or mold growth",
                issueExplanation: "White or gray patches may indicate powdery mildew or overwatering-related fungal growth.",
                immediateAction: "Improve air circulation and reduce watering frequency immediately.",
                followUpSteps: "Remove affected leaves | Apply diluted neem oil spray weekly",
                recoveryEstimate: "1–3 weeks"
            )
        } else if hasYellow {
            return PlantHealthResult(
                overallStatus: "Minor Issues",
                detectedIssue: "Yellowing foliage",
                issueExplanation: "Yellowing can indicate overwatering, poor drainage, or nutrient deficiency.",
                immediateAction: "Check the soil moisture — let it dry out completely before next watering.",
                followUpSteps: "Inspect roots for rot | Consider a balanced liquid fertilizer",
                recoveryEstimate: "2–3 weeks"
            )
        } else if hasDry {
            return PlantHealthResult(
                overallStatus: "Minor Issues",
                detectedIssue: "Underwatering or low humidity",
                issueExplanation: "Dry, crispy leaf edges suggest the plant is not getting enough moisture.",
                immediateAction: "Water the plant thoroughly and allow excess water to drain.",
                followUpSteps: "Mist the leaves or use a humidity tray | Move away from heating vents",
                recoveryEstimate: "1–2 weeks"
            )
        } else {
            return PlantHealthResult(
                overallStatus: "Healthy",
                detectedIssue: "None detected",
                issueExplanation: "No obvious health issues were detected in the visual analysis.",
                immediateAction: "Maintain your current care routine — the plant looks good!",
                followUpSteps: "Monitor for new growth | Fertilize monthly during growing season",
                recoveryEstimate: "N/A — plant appears healthy"
            )
        }
    }
}

// MARK: - PlantHealthDiagnosisView

@available(iOS 26, *)
struct PlantHealthDiagnosisView: View {

    @State private var service = PlantHealthDiagnosisService()
    @Bindable private var entitlements = EntitlementStore.shared
    @State private var selectedImage: UIImage? = nil
    @State private var photoPickerItem: PhotosPickerItem? = nil
    @State private var cameraImage: UIImage? = nil
    @State private var showCamera = false
    @State private var showAIChat = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient.ignoresSafeArea()
                contentForState
            }
            .navigationTitle("Health Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.primaryBlue)
                }
            }
        }
        .onChange(of: photoPickerItem) { _, item in
            Task {
                guard let item,
                      let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                await runDiagnosis(with: image)
            }
        }
        .onChange(of: cameraImage) { _, image in
            guard let image else { return }
            Task { await runDiagnosis(with: image) }
        }
        .sheet(isPresented: $showCamera) {
            CameraPickerView(image: $cameraImage).ignoresSafeArea()
        }
        .sheet(isPresented: $showAIChat) {
            PlantAIChatView(plantName: nil)
        }
    }

    @ViewBuilder
    private var contentForState: some View {
        switch service.state {
        case .idle:       idleView
        case .analyzing:  analyzingView
        case .result(let r): resultView(r)
        case .error(let m):  errorView(m)
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        ScrollView {
            VStack(spacing: 24) {
                featureBanner
                aiCreditBanner
                photoUploadCard
                symptomsGuide
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
    }

    private var featureBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "heart.text.square.fill")
                .foregroundStyle(Color.hotCoral)
                .font(.system(size: 16))
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Plant Health Diagnosis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text("Detect diseases, pests & deficiencies instantly")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.hotCoral.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.hotCoral.opacity(0.2), lineWidth: 1)
        )
    }

    private var aiCreditBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: aiCreditIcon)
                .foregroundStyle(aiCreditTint)
                .font(.system(size: 15, weight: .semibold))

            VStack(alignment: .leading, spacing: 2) {
                Text(aiCreditTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(aiCreditSubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            if entitlements.aiActionAccess() == .denied {
                Button("Get Credits") {
                    PaywallPresenter.shared.present(source: .identification, tab: .consumables)
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.hotCoral, in: Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(aiCreditTint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var photoUploadCard: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.hotCoral.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(
                                Color.hotCoral.opacity(0.25),
                                style: StrokeStyle(lineWidth: 1.5, dash: [7, 5])
                            )
                    )
                    .frame(height: 190)

                VStack(spacing: 12) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 52))
                        .foregroundStyle(Color.hotCoral.opacity(0.6))
                    Text("Upload a photo of your plant")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            HStack(spacing: 12) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button { openCamera() } label: {
                        Label("Take Photo", systemImage: "camera.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.hotCoral)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    Label("Choose Photo", systemImage: "photo.on.rectangle.angled")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.hotCoral)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.hotCoral.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.hotCoral.opacity(0.25), lineWidth: 1)
                        )
                }
            }
        }
    }

    private var symptomsGuide: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What I can detect")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.textPrimary)

            VStack(alignment: .leading, spacing: 10) {
                symptomRow(icon: "drop.degreesign.fill", color: Color.neonCyan, text: "Overwatering & underwatering signs")
                symptomRow(icon: "ant.fill", color: Color.savedAmber, text: "Pests — spider mites, aphids, scale")
                symptomRow(icon: "circle.dashed", color: Color.hotCoral, text: "Fungal disease & mold growth")
                symptomRow(icon: "minus.circle.fill", color: Color.neonOrange, text: "Nutrient deficiencies (N, P, K, Fe)")
                symptomRow(icon: "sun.haze.fill", color: Color.primaryBlue, text: "Light stress — bleaching or burn")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.phSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func symptomRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - Analyzing

    private var analyzingView: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.hotCoral.opacity(0.08))
                    .frame(width: 104, height: 104)
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.hotCoral)
            }
            .phaseAnimator([0.95, 1.0]) { view, scale in
                view.scaleEffect(scale)
            } animation: { _ in .easeInOut(duration: 0.9).repeatForever(autoreverses: true) }

            VStack(spacing: 8) {
                Text("Analyzing plant health…")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text("Checking for diseases, pests & deficiencies")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }

            ProgressView().tint(Color.hotCoral).scaleEffect(1.2)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - Result

    private func resultView(_ result: PlantHealthResult) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                if let img = selectedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

                statusCard(result)
                issueDetailCard(result)
                actionPlanCard(result)
                resultActionButtons
                retryButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
    }

    private func statusCard(_ result: PlantHealthResult) -> some View {
        let (color, icon): (Color, String) = switch result.overallStatus {
        case "Healthy":       (Color.primaryBlue, "checkmark.circle.fill")
        case "Minor Issues":  (Color.savedAmber, "exclamationmark.circle.fill")
        case "Needs Attention": (Color.neonOrange, "exclamationmark.triangle.fill")
        default:              (Color.hotCoral, "xmark.circle.fill")
        }

        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Diagnosis Result")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text(result.overallStatus)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(color)
            }
            Spacer()
        }
        .padding(16)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
    }

    private func issueDetailCard(_ result: PlantHealthResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if result.detectedIssue != "None detected" {
                issueRow(label: "Issue Detected", value: result.detectedIssue, icon: "exclamationmark.bubble.fill", color: Color.hotCoral)
                Divider()
            }
            issueRow(label: "Explanation", value: result.issueExplanation, icon: "info.circle.fill", color: Color.primaryBlue)
            Divider()
            issueRow(label: "Recovery", value: result.recoveryEstimate, icon: "clock.fill", color: Color.savedAmber)
        }
        .padding(18)
        .background(Color.phSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func issueRow(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 20, height: 20)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                Text(value)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func actionPlanCard(_ result: PlantHealthResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 7) {
                Image(systemName: "list.bullet.clipboard.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.primaryBlue)
                Text("Action Plan")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
            }

            actionStep(number: "1", text: result.immediateAction, color: Color.hotCoral)

            let steps = result.followUpSteps.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespaces) }
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                actionStep(number: "\(index + 2)", text: step, color: Color.primaryBlue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.tagBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func actionStep(number: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 26, height: 26)
                Text(number)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)
            }
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var resultActionButtons: some View {
        Button {
            showAIChat = true
        } label: {
            Label("Ask AI for More Help", systemImage: "bubble.left.and.text.bubble.right.fill")
                .primaryButtonStyle()
        }
        .buttonStyle(.plain)
    }

    private var retryButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                service.reset()
                selectedImage = nil
                photoPickerItem = nil
                cameraImage = nil
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14))
                Text("Check Another Plant")
                    .font(.system(size: 15))
            }
            .foregroundStyle(Color.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.savedAmber)
            VStack(spacing: 8) {
                Text("Diagnosis Failed")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            PrimaryButton(title: "Try Again") {
                service.reset()
                selectedImage = nil
            }
            .frame(maxWidth: 280)
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }

    private var aiCreditIcon: String {
        switch entitlements.aiActionAccess() {
        case .unlimited: return "infinity"
        case .basicQuota: return "bolt.fill"
        case .consumableCredit: return "sparkles"
        case .freeQuota: return "gift.fill"
        case .denied: return "lock.fill"
        }
    }

    private var aiCreditTitle: String {
        switch entitlements.aiActionAccess() {
        case .unlimited: return "Unlimited AI actions"
        case .basicQuota: return "Member AI actions"
        case .consumableCredit: return "AI Credits available"
        case .freeQuota: return "Free AI actions"
        case .denied: return "No AI actions remaining"
        }
    }

    private var aiCreditSubtitle: String {
        switch entitlements.aiActionAccess() {
        case .unlimited:
            return "Health scans are included with LeafChat Plus."
        case .basicQuota:
            return "\(entitlements.remainingBasicIdentifications) member action\(entitlements.remainingBasicIdentifications == 1 ? "" : "s") left this month."
        case .consumableCredit:
            return "\(entitlements.identificationCredits) AI credit\(entitlements.identificationCredits == 1 ? "" : "s") remaining."
        case .freeQuota:
            return "\(entitlements.remainingFreeIdentifications) free action\(entitlements.remainingFreeIdentifications == 1 ? "" : "s") left this month."
        case .denied:
            return "Upgrade or buy AI Credits to run another health scan."
        }
    }

    private var aiCreditTint: Color {
        switch entitlements.aiActionAccess() {
        case .unlimited, .basicQuota: return Color.primaryBlue
        case .consumableCredit: return Color.neonCyan
        case .freeQuota: return Color.savedAmber
        case .denied: return Color.hotCoral
        }
    }

    private func openCamera() {
        guard entitlements.aiActionAccess() != .denied else {
            PaywallPresenter.shared.present(source: .identification, tab: .consumables)
            return
        }
        showCamera = true
    }

    private func runDiagnosis(with image: UIImage) async {
        guard entitlements.aiActionAccess() != .denied else {
            PaywallPresenter.shared.present(source: .identification, tab: .consumables)
            return
        }

        selectedImage = image
        await service.diagnose(image: image)

        if case .result = service.state {
            entitlements.consumeAIActionCreditIfNeeded()
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack(alignment: .top) {
            Color.phBackground
            LinearGradient(
                colors: [Color.hotCoral.opacity(0.06), Color.clear],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.30)
            )
        }
    }
}
