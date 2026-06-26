import SwiftUI
import FoundationModels

// MARK: - Chat Message Model

struct AIChatMessage: Identifiable, Sendable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp: Date = Date()

    enum Role {
        case user, assistant, system
    }
}

// MARK: - PlantAIChatService

@available(iOS 26, *)
@Observable
final class PlantAIChatService {
    var messages: [AIChatMessage] = []
    var isThinking = false
    var errorMessage: String? = nil

    private let languageModel = SystemLanguageModel.default
    private var session: LanguageModelSession?

    var isAvailable: Bool { languageModel.isAvailable }

    init(plantName: String?) {
        setupSession(plantName: plantName)
        if let name = plantName, !name.isEmpty {
            let welcome = AIChatMessage(
                role: .assistant,
                content: "Hi! I'm your AI plant care assistant. I'm here to help you with everything about \(name). Ask me anything — watering schedules, light requirements, common problems, or propagation tips!"
            )
            messages.append(welcome)
        } else {
            let welcome = AIChatMessage(
                role: .assistant,
                content: "Hi! I'm your AI plant care assistant. Ask me anything about plant care, identification tips, disease treatment, or how to help your plants thrive."
            )
            messages.append(welcome)
        }
    }

    func send(userMessage: String, plantName: String?) async -> Bool {
        guard !userMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }

        let userMsg = AIChatMessage(role: .user, content: userMessage)
        messages.append(userMsg)
        isThinking = true
        errorMessage = nil

        do {
            if let session = session, languageModel.isAvailable {
                let response = try await session.respond(to: userMessage)
                let reply = AIChatMessage(role: .assistant, content: response.content)
                messages.append(reply)
                isThinking = false
                return true
            } else {
                // Fallback when Foundation Models is unavailable
                let reply = AIChatMessage(
                    role: .assistant,
                    content: fallbackResponse(for: userMessage, plantName: plantName)
                )
                messages.append(reply)
                isThinking = false
                return true
            }
        } catch {
            errorMessage = "I couldn't respond right now. Please try again."
        }

        isThinking = false
        return false
    }

    func clearChat(plantName: String?) {
        messages = []
        setupSession(plantName: plantName)
        let welcome = AIChatMessage(
            role: .assistant,
            content: plantName != nil
                ? "Chat cleared. Ask me anything about **\(plantName!)**."
                : "Chat cleared. How can I help you with your plants?"
        )
        messages.append(welcome)
    }

    private func setupSession(plantName: String?) {
        guard languageModel.isAvailable else { return }
        let systemPrompt: String
        if let name = plantName, !name.isEmpty {
            systemPrompt = """
            You are an expert botanist and plant care specialist focused on helping users care for their \(name).
            Be friendly, practical, and concise. Give specific, actionable advice.
            Always relate answers back to \(name) when possible.
            If unsure about something specific to this plant, say so and give general guidance.
            Keep replies under 150 words unless a detailed answer is genuinely needed.
            """
        } else {
            systemPrompt = """
            You are an expert botanist and plant care specialist for a plant identification app.
            Be friendly, practical, and concise. Give specific, actionable advice about plant care, identification, and troubleshooting.
            Keep replies under 150 words unless a detailed answer is genuinely needed.
            """
        }
        session = LanguageModelSession {
            systemPrompt
        }
    }

    private func fallbackResponse(for message: String, plantName: String?) -> String {
        let lower = message.lowercased()
        let plant = plantName ?? "your plant"

        if lower.contains("water") {
            return "For \(plant), check the top inch of soil — water when it feels dry. Most houseplants prefer deep, infrequent watering over frequent shallow watering. Ensure good drainage to prevent root rot."
        } else if lower.contains("light") || lower.contains("sun") {
            return "\(plant) generally does well in bright indirect light. Avoid harsh midday sun which can bleach leaves, and keep away from dark corners where growth slows significantly."
        } else if lower.contains("yellow") || lower.contains("brown") {
            return "Yellow leaves often indicate overwatering or poor drainage. Brown tips can mean low humidity or fluoride in tap water. Check your soil moisture and try using filtered water."
        } else if lower.contains("propagat") {
            return "Most houseplants can be propagated via stem cuttings in water or moist soil. Take a cutting just below a node, remove lower leaves, and keep in bright indirect light."
        } else if lower.contains("fertiliz") || lower.contains("feed") {
            return "Feed \(plant) with a balanced liquid fertilizer (e.g. 10-10-10) every 4 weeks during spring and summer. Reduce to monthly or stop entirely in fall and winter."
        } else {
            return "I'm here to help with all your \(plant) care questions! For best results, enable Apple Intelligence in your device Settings for more detailed, personalized advice."
        }
    }
}

// MARK: - PlantAIChatView

@available(iOS 26, *)
struct PlantAIChatView: View {

    var plantName: String?

    @State private var service: PlantAIChatService
    @Bindable private var entitlements = EntitlementStore.shared
    @State private var inputText = ""
    @State private var scrollProxy: ScrollViewProxy? = nil
    @Environment(\.dismiss) private var dismiss

    private let suggestedQuestions: [String] = [
        "How often should I water?",
        "What light does it need?",
        "Why are the leaves yellowing?",
        "How do I propagate it?",
        "Is it pet-friendly?"
    ]

    init(plantName: String?) {
        self.plantName = plantName
        _service = State(initialValue: PlantAIChatService(plantName: plantName))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !service.isAvailable {
                    appleIntelligenceBanner
                }

                aiCreditBanner
                messageList
                inputArea
            }
            .background(Color.phBackground.ignoresSafeArea())
            .navigationTitle(plantName.map { "Ask AI: \($0)" } ?? "Ask AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.primaryBlue)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        service.clearChat(plantName: plantName)
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Apple Intelligence Banner

    private var appleIntelligenceBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Color.savedAmber)
            Text("Enable Apple Intelligence in Settings for AI chat")
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.surfaceAmber)
    }

    private var aiCreditBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: aiCreditIcon)
                .foregroundStyle(aiCreditTint)
            Text(aiCreditText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.textSecondary)
            Spacer()

            if entitlements.aiActionAccess() == .denied {
                Button("Get Credits") {
                    PaywallPresenter.shared.present(source: .identification, tab: .consumables)
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.primaryBlue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(aiCreditTint.opacity(0.08))
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(service.messages) { message in
                        messageBubble(message)
                            .id(message.id)
                    }

                    if service.isThinking {
                        thinkingIndicator
                            .id("thinking")
                    }

                    if let error = service.errorMessage {
                        errorBubble(error)
                    }

                    // Suggested questions when only the welcome message is shown
                    if service.messages.count == 1 {
                        suggestedQuestionsSection
                    }

                    Color.clear.frame(height: 8).id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onAppear { scrollProxy = proxy }
            .onChange(of: service.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: service.isThinking) { _, _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    private func messageBubble(_ message: AIChatMessage) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .assistant {
                ZStack {
                    Circle()
                        .fill(Color.primaryBlue.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: "wand.and.sparkles")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.primaryBlue)
                }
                .alignmentGuide(.bottom) { d in d[.bottom] }
            } else {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 3) {
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundStyle(message.role == .user ? Color.white : Color.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        message.role == .user
                            ? LinearGradient(
                                colors: [Color(hex: "#8B5CF6"), Color(hex: "#7C3AED")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              )
                            : LinearGradient(
                                colors: [Color.phSurface, Color.phSurface],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              )
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 18,
                            style: .continuous
                        )
                    )
                    .overlay(
                        message.role == .assistant
                            ? RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.phBorder.opacity(0.5), lineWidth: 0.5)
                            : nil
                    )
                    .shadow(color: message.role == .user
                        ? Color.primaryBlue.opacity(0.18) : Color.black.opacity(0.04),
                        radius: 6, x: 0, y: 3)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.72, alignment: message.role == .user ? .trailing : .leading)

                Text(message.timestamp, style: .time)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, 4)
            }

            if message.role == .user {
                Spacer()
            } else {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private var thinkingIndicator: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.primaryBlue.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: "wand.and.sparkles")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primaryBlue)
            }

            HStack(spacing: 5) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.textSecondary.opacity(0.5))
                        .frame(width: 7, height: 7)
                        .phaseAnimator([0.4, 1.0]) { view, opacity in
                            view.opacity(opacity)
                        } animation: { _ in
                            .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2)
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.phSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Spacer()
        }
        .id("thinking")
    }

    private func errorBubble(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.hotCoral)
                .font(.system(size: 13))
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Color.hotCoral)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.hotCoral.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var suggestedQuestionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try asking:")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, 4)

            FlowLayout(spacing: 8) {
                ForEach(suggestedQuestions, id: \.self) { question in
                    Button {
                        inputText = question
                        sendMessage()
                    } label: {
                        Text(question)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.primaryBlue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.tagBackground)
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(Color.primaryBlue.opacity(0.2), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 10) {
                TextField("Ask about plant care…", text: $inputText, axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.phSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.phBorder, lineWidth: 1)
                    )
                    .onSubmit { sendMessage() }

                Button(action: sendMessage) {
                    ZStack {
                        Circle()
                            .fill(
                                inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || service.isThinking
                                    ? AnyShapeStyle(Color.phSurface)
                                    : AnyShapeStyle(LinearGradient(
                                        colors: [Color(hex: "#8B5CF6"), Color(hex: "#7C3AED")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                      ))
                            )
                            .frame(width: 44, height: 44)

                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(
                                inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || service.isThinking
                                    ? Color.textSecondary
                                    : .white
                            )
                    }
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || service.isThinking)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.phBackground)
        }
    }

    // MARK: - Actions

    private var aiCreditIcon: String {
        switch entitlements.aiActionAccess() {
        case .unlimited: return "infinity"
        case .basicQuota: return "bolt.fill"
        case .consumableCredit: return "sparkles"
        case .freeQuota: return "gift.fill"
        case .denied: return "lock.fill"
        }
    }

    private var aiCreditText: String {
        switch entitlements.aiActionAccess() {
        case .unlimited:
            return "Unlimited Ask AI questions with LeafChat Plus."
        case .basicQuota:
            return "\(entitlements.remainingBasicIdentifications) member AI action\(entitlements.remainingBasicIdentifications == 1 ? "" : "s") left this month."
        case .consumableCredit:
            return "\(entitlements.identificationCredits) AI credit\(entitlements.identificationCredits == 1 ? "" : "s") remaining."
        case .freeQuota:
            return "\(entitlements.remainingFreeIdentifications) free AI action\(entitlements.remainingFreeIdentifications == 1 ? "" : "s") left this month."
        case .denied:
            return "No AI actions remaining. Buy AI Credits to ask more questions."
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

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !service.isThinking else { return }
        guard entitlements.aiActionAccess() != .denied else {
            PaywallPresenter.shared.present(source: .identification, tab: .consumables)
            return
        }
        inputText = ""
        Task {
            let didReply = await service.send(userMessage: text, plantName: plantName)
            if didReply {
                entitlements.consumeAIActionCreditIfNeeded()
            }
        }
    }
}

// MARK: - FlowLayout (simple horizontal wrap)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? UIScreen.main.bounds.width
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
