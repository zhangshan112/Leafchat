import SwiftUI
import PhotosUI
import FoundationModels

// MARK: - Plant Identification View (iOS 26+)

@available(iOS 26, *)
struct PlantIdentificationView: View {

    @Bindable private var entitlements = EntitlementStore.shared
    @State private var service = PlantIdentificationService()
    @State private var selectedImage: UIImage? = nil
    @State private var photoPickerItem: PhotosPickerItem? = nil
    @State private var cameraImage: UIImage? = nil
    @State private var showCamera = false
    @State private var navigateToPlant: PlantWikiPlant? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient.ignoresSafeArea()
                contentForState
            }
            .navigationTitle("Identify Plant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.primaryBlue)
                }
            }
            .navigationDestination(item: $navigateToPlant) { plant in
                PlantDetailView(plant: plant)
            }
        }
        .onChange(of: photoPickerItem) { _, item in
            Task {
                guard let item,
                      let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                await runIdentification(with: image)
            }
        }
        .onChange(of: cameraImage) { _, image in
            guard let image else { return }
            Task { await runIdentification(with: image) }
        }
        .sheet(isPresented: $showCamera) {
            CameraPickerView(image: $cameraImage)
                .ignoresSafeArea()
        }
    }

    // MARK: - State router

    @ViewBuilder
    private var contentForState: some View {
        switch service.state {
        case .idle:
            idleView
        case .analyzing:
            analyzingView
        case .matched(let plant, let result):
            resultView(plant: plant, result: result)
        case .error(let message):
            errorView(message: message)
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        ScrollView {
            VStack(spacing: 24) {
                modelBanner
                identificationQuotaBanner
                photoSelectionCard
                tipsCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
    }

    @ViewBuilder
    private var identificationQuotaBanner: some View {
        if entitlements.isPremium {
            quotaBanner(
                icon: "infinity",
                text: "Unlimited identifications with LeafChat Plus",
                tint: Color.primaryBlue,
                background: Color.tagBackground
            )
        } else {
            let access = entitlements.identificationAccess()
            switch access {
            case .unlimited:
                EmptyView()
            case .basicQuota:
                quotaBanner(
                    icon: "bolt.fill",
                    text: "\(entitlements.remainingBasicIdentifications) member identification\(entitlements.remainingBasicIdentifications == 1 ? "" : "s") left this month",
                    tint: Color.primaryBlue,
                    background: Color.tagBackground
                )
            case .consumableCredit:
                quotaBanner(
                    icon: "ticket.fill",
                    text: "\(entitlements.identificationCredits) credit\(entitlements.identificationCredits == 1 ? "" : "s") remaining",
                    tint: Color.neonCyan,
                    background: Color.surfaceCyan
                )
            case .freeQuota:
                quotaBanner(
                    icon: "gift.fill",
                    text: "\(entitlements.remainingFreeIdentifications) free identification\(entitlements.remainingFreeIdentifications == 1 ? "" : "s") left this month",
                    tint: Color.savedAmber,
                    background: Color.surfaceAmber
                )
            case .denied:
                VStack(alignment: .leading, spacing: 12) {
                    quotaBanner(
                        icon: "lock.fill",
                        text: "No identifications remaining. Upgrade or buy credits to continue.",
                        tint: Color.hotCoral,
                        background: Color.surfaceCoral
                    )
                    PrimaryButton(title: "Get More Identifications") {
                        PaywallPresenter.shared.present(source: .identification, tab: .consumables)
                    }
                }
            }
        }
    }

    private func quotaBanner(icon: String, text: String, tint: Color, background: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func runIdentification(with image: UIImage) async {
        guard entitlements.identificationAccess() != .denied else {
            PaywallPresenter.shared.present(source: .identification, tab: .consumables)
            return
        }

        selectedImage = image
        await service.identify(image: image)

        if case .matched = service.state {
            entitlements.consumeIdentificationCreditIfNeeded()
        }
    }

    private var modelBanner: some View {
        HStack(spacing: 8) {
            switch service.modelAvailability {
            case .available:
                Image(systemName: "cpu.fill")
                    .foregroundStyle(Color.primaryBlue)
                Text("Powered by Apple Intelligence · On-device")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.primaryBlue)
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.primaryBlue.opacity(0.6))
            case .unavailable(.appleIntelligenceNotEnabled):
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(Color.savedAmber)
                Text("Enable Apple Intelligence in Settings for best results")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
                Spacer()
            default:
                Image(systemName: "wand.and.sparkles")
                    .foregroundStyle(Color.textSecondary)
                Text("Vision-based identification active")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
                Spacer()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(bannerBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var bannerBackground: Color {
        switch service.modelAvailability {
        case .available: return Color.tagBackground
        case .unavailable(.appleIntelligenceNotEnabled): return Color.surfaceAmber
        default: return Color.phSurface
        }
    }

    private var photoSelectionCard: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.surfaceViolet)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(
                                Color.primaryBlue.opacity(0.25),
                                style: StrokeStyle(lineWidth: 1.5, dash: [7, 5])
                            )
                    )
                    .frame(height: 200)

                VStack(spacing: 12) {
                    Image(systemName: "leaf.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.primaryBlue.opacity(0.65))

                    Text("Select a photo to identify your plant")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            HStack(spacing: 12) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button { showCamera = true } label: {
                        Label("Take Photo", systemImage: "camera.fill")
                            .primaryButtonStyle()
                    }
                    .buttonStyle(.plain)
                }

                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    Label("Library", systemImage: "photo.on.rectangle.angled")
                        .secondaryButtonStyle()
                }
            }
        }
    }

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tips for best results")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.textPrimary)

            VStack(alignment: .leading, spacing: 10) {
                tipRow(icon: "sun.max", text: "Natural light works best — avoid flash glare")
                tipRow(icon: "camera.macro", text: "Focus on a single leaf or the whole plant")
                tipRow(icon: "arrow.up.left.and.arrow.down.right", text: "Fill the frame — minimize background clutter")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.phSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.phBorder, lineWidth: 0.5)
        )
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Color.primaryBlue)
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
                    .fill(Color.surfaceViolet)
                    .frame(width: 104, height: 104)
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.primaryBlue)
            }
            .phaseAnimator([0.95, 1.0]) { view, scale in
                view.scaleEffect(scale)
            } animation: { _ in .easeInOut(duration: 0.9).repeatForever(autoreverses: true) }

            VStack(spacing: 8) {
                Text("Analyzing plant…")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                Text("Vision + Apple Intelligence at work")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
            }

            ProgressView()
                .tint(Color.primaryBlue)
                .scaleEffect(1.2)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Result

    @ViewBuilder
    private func resultView(plant: PlantWikiPlant, result: PlantIdentificationResult) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                if let image = selectedImage {
                    identifiedImageView(image)
                }

                resultInfoCard(plant: plant, result: result)
                actionButtons(plant: plant, result: result)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
    }

    private func identifiedImageView(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .mediaContainer(aspectRatio: 1.0)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.primaryBlue.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color.primaryBlue.opacity(0.10), radius: 12, x: 0, y: 5)
    }

    private func resultInfoCard(plant: PlantWikiPlant, result: PlantIdentificationResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                confidenceBadge(result.confidence)
                Spacer()
                if case .available = service.modelAvailability {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu.fill")
                            .font(.system(size: 10))
                        Text("Apple Intelligence")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(Color.primaryBlue.opacity(0.75))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.tagBackground)
                    .clipShape(Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(result.commonName)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                if !result.scientificName.isEmpty {
                    Text(result.scientificName)
                        .font(.system(size: 14))
                        .italic()
                        .foregroundStyle(Color.textSecondary)
                }
            }

            if !result.careTip.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.primaryBlue)
                        .padding(.top, 2)
                    Text(result.careTip)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color.surfaceViolet)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.phSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.primaryBlue.opacity(0.08), radius: 14, x: 0, y: 5)
    }

    private func actionButtons(plant: PlantWikiPlant, result: PlantIdentificationResult) -> some View {
        VStack(spacing: 12) {
            // Primary: share to feed
            Button {
                PostDraftStore.shared.set(
                    plantName: result.commonName,
                    scientificName: result.scientificName,
                    images: selectedImage.map { [$0] } ?? []
                )
                dismiss()
            } label: {
                Label("Post This Plant", systemImage: "paperplane.fill")
                    .primaryButtonStyle()
            }
            .buttonStyle(.plain)

            // Secondary: go to encyclopedia
            Button {
                navigateToPlant = plant
            } label: {
                Label("View Full Care Guide", systemImage: "book.fill")
                    .secondaryButtonStyle()
            }
            .buttonStyle(.plain)

            // Tertiary: retry
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
                    Text("Try Another Photo")
                        .font(.system(size: 15))
                }
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Error

    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.savedAmber)

            VStack(spacing: 8) {
                Text("Identification Failed")
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
                photoPickerItem = nil
                cameraImage = nil
            }
            .frame(maxWidth: 280)

            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func confidenceBadge(_ confidence: IdentificationConfidence) -> some View {
        let (label, color): (String, Color) = switch confidence {
        case .high:   ("High Confidence", Color.primaryBlue)
        case .medium: ("Medium Confidence", Color.savedAmber)
        case .low:    ("Low Confidence", Color.textSecondary)
        }

        return HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    private var backgroundGradient: some View {
        ZStack(alignment: .top) {
            Color.phBackground
            LinearGradient(
                colors: [Color.primaryBlue.opacity(0.07), Color.clear],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.30)
            )
        }
    }
}

// MARK: - Camera Picker (UIKit wrapper)

struct CameraPickerView: UIViewControllerRepresentable {

    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView

        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
