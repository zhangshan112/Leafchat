import SwiftUI
import PhotosUI
import FoundationModels
import AVFoundation

// MARK: - Plant Identification View (iOS 26+)

@available(iOS 26, *)
struct PlantIdentificationView: View {

    @Bindable private var entitlements = EntitlementStore.shared
    @ObservedObject private var collectionStore = PlantCollectionStore.shared
    @ObservedObject private var session = UserSessionStore.shared
    @State private var service = PlantIdentificationService()
    @State private var selectedImage: UIImage? = nil
    @State private var photoPickerItem: PhotosPickerItem? = nil
    @State private var showCamera = false
    @State private var navigateToPlant: PlantWikiPlant? = nil
    @State private var addedToGarden = false
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
        .sheet(isPresented: $showCamera) {
            LivePlantScannerView { image in
                Task { await runIdentification(with: image) }
            }
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
                text: "Unlimited AI actions with LeafChat Plus",
                tint: Color.primaryBlue,
                background: Color.tagBackground
            )
        } else {
            let access = entitlements.aiActionAccess()
            switch access {
            case .unlimited:
                EmptyView()
            case .basicQuota:
                quotaBanner(
                    icon: "bolt.fill",
                    text: "\(entitlements.remainingBasicIdentifications) member AI action\(entitlements.remainingBasicIdentifications == 1 ? "" : "s") left this month",
                    tint: Color.primaryBlue,
                    background: Color.tagBackground
                )
            case .consumableCredit:
                quotaBanner(
                    icon: "ticket.fill",
                    text: "\(entitlements.identificationCredits) AI credit\(entitlements.identificationCredits == 1 ? "" : "s") remaining",
                    tint: Color.neonCyan,
                    background: Color.surfaceCyan
                )
            case .freeQuota:
                quotaBanner(
                    icon: "gift.fill",
                    text: "\(entitlements.remainingFreeIdentifications) free AI action\(entitlements.remainingFreeIdentifications == 1 ? "" : "s") left this month",
                    tint: Color.savedAmber,
                    background: Color.surfaceAmber
                )
            case .denied:
                VStack(alignment: .leading, spacing: 12) {
                    quotaBanner(
                        icon: "lock.fill",
                        text: "No AI actions remaining. Upgrade or buy AI Credits to continue.",
                        tint: Color.hotCoral,
                        background: Color.surfaceCoral
                    )
                    PrimaryButton(title: "Get More AI Credits") {
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
        guard entitlements.aiActionAccess() != .denied else {
            PaywallPresenter.shared.present(source: .identification, tab: .consumables)
            return
        }

        selectedImage = image
        await service.identify(image: image)

        if case .matched = service.state {
            entitlements.consumeAIActionCreditIfNeeded()
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
                    Image(systemName: "tree.fill")
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
                        Label("Scan with Camera", systemImage: "camera.viewfinder")
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
                Image(systemName: "tree.fill")
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
                    Image(systemName: "tree.fill")
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

            // Add to My Garden
            Button {
                addToGarden(plant: plant)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: addedToGarden ? "checkmark.circle.fill" : "tree.fill")
                        .font(.system(size: 15))
                    Text(addedToGarden ? "Added to My Garden" : "Add to My Garden")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(addedToGarden ? Color.primaryBlue : Color.primaryBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(addedToGarden ? Color.primaryBlue.opacity(0.12) : Color.tagBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primaryBlue.opacity(addedToGarden ? 0.3 : 0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(addedToGarden)

            // Go to encyclopedia
            Button {
                navigateToPlant = plant
            } label: {
                Label("View Full Care Guide", systemImage: "book.fill")
                    .secondaryButtonStyle()
            }
            .buttonStyle(.plain)

            // Retry
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    service.reset()
                    selectedImage = nil
                    photoPickerItem = nil
                    addedToGarden = false
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

    private func addToGarden(plant: PlantWikiPlant) {
        guard let userId = session.collectionUserId else { return }
        let added = collectionStore.add(plant, userId: userId)
        withAnimation(.spring(response: 0.3)) {
            addedToGarden = added || collectionStore.isCollected(plant)
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

// MARK: - Live Plant Scanner

struct LivePlantScannerView: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> LivePlantScannerViewController {
        LivePlantScannerViewController(
            onImage: { image in
                onImage(image)
                dismiss()
            },
            onCancel: { dismiss() }
        )
    }

    func updateUIViewController(_ uiViewController: LivePlantScannerViewController, context: Context) {}
}

final class LivePlantScannerViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let videoQueue = DispatchQueue(label: "com.planthub.live-plant-scanner")
    private let ciContext = CIContext()
    private let onImage: (UIImage) -> Void
    private let onCancel: () -> Void

    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var capturedImageView: UIImageView?
    private var titleLabel: UILabel?
    private var subtitleLabel: UILabel?
    private var actionStack: UIStackView?
    private var scanLine: UIView?
    private var scanLineTopConstraint: NSLayoutConstraint?
    private var didCaptureFrame = false
    private var canCaptureFrame = false
    private var capturedImage: UIImage?

    private let autoCaptureDelay: TimeInterval = 2.6

    init(onImage: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
        self.onImage = onImage
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureOverlay()
        prepareCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }

    private func prepareCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    granted ? self?.configureSession() : self?.onCancel()
                }
            }
        default:
            onCancel()
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard
            let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: camera),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            onCancel()
            return
        }

        session.addInput(input)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        guard session.canAddOutput(videoOutput) else {
            session.commitConfiguration()
            onCancel()
            return
        }

        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        session.addOutput(videoOutput)
        videoOutput.connection(with: .video)?.videoOrientation = .portrait

        session.commitConfiguration()

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.insertSublayer(previewLayer, at: 0)
        self.previewLayer = previewLayer

        videoQueue.async { [weak self] in
            guard let self else { return }
            self.session.startRunning()
            DispatchQueue.main.async { [weak self] in
                self?.startScanLineAnimation()
            }
            self.videoQueue.asyncAfter(deadline: .now() + self.autoCaptureDelay) { [weak self] in
                self?.canCaptureFrame = true
            }
        }
    }

    private func stopSession() {
        videoQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    private func configureOverlay() {
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        closeButton.layer.cornerRadius = 18
        closeButton.addTarget(self, action: #selector(cancelScan), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "Scanning plant..."
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Hold steady. LeafChat will capture automatically."
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.72)
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let overlayStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        overlayStack.axis = .vertical
        overlayStack.spacing = 6
        overlayStack.translatesAutoresizingMaskIntoConstraints = false

        let scanFrame = UIView()
        scanFrame.layer.borderWidth = 1.5
        scanFrame.layer.borderColor = UIColor.white.withAlphaComponent(0.72).cgColor
        scanFrame.layer.cornerRadius = 28
        scanFrame.backgroundColor = UIColor.clear
        scanFrame.clipsToBounds = true
        scanFrame.translatesAutoresizingMaskIntoConstraints = false

        let scanLine = UIView()
        scanLine.backgroundColor = UIColor(Color.neonCyan)
        scanLine.layer.shadowColor = UIColor(Color.neonCyan).cgColor
        scanLine.layer.shadowOpacity = 0.85
        scanLine.layer.shadowRadius = 10
        scanLine.layer.shadowOffset = .zero
        scanLine.translatesAutoresizingMaskIntoConstraints = false

        let capturedImageView = UIImageView()
        capturedImageView.contentMode = .scaleAspectFill
        capturedImageView.clipsToBounds = true
        capturedImageView.isHidden = true
        capturedImageView.translatesAutoresizingMaskIntoConstraints = false

        let startButton = UIButton(type: .system)
        startButton.setTitle("Start Identification", for: .normal)
        startButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        startButton.setTitleColor(.white, for: .normal)
        startButton.backgroundColor = UIColor(Color.primaryBlue)
        startButton.layer.cornerRadius = 14
        startButton.addTarget(self, action: #selector(startIdentification), for: .touchUpInside)
        startButton.translatesAutoresizingMaskIntoConstraints = false

        let rescanButton = UIButton(type: .system)
        rescanButton.setTitle("Scan Again", for: .normal)
        rescanButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        rescanButton.setTitleColor(UIColor(Color.primaryBlue), for: .normal)
        rescanButton.backgroundColor = UIColor.white.withAlphaComponent(0.92)
        rescanButton.layer.cornerRadius = 14
        rescanButton.addTarget(self, action: #selector(scanAgain), for: .touchUpInside)
        rescanButton.translatesAutoresizingMaskIntoConstraints = false

        let actionStack = UIStackView(arrangedSubviews: [startButton, rescanButton])
        actionStack.axis = .vertical
        actionStack.spacing = 12
        actionStack.isHidden = true
        actionStack.translatesAutoresizingMaskIntoConstraints = false

        self.titleLabel = titleLabel
        self.subtitleLabel = subtitleLabel
        self.capturedImageView = capturedImageView
        self.actionStack = actionStack
        self.scanLine = scanLine

        view.addSubview(capturedImageView)
        view.addSubview(scanFrame)
        scanFrame.addSubview(scanLine)
        view.addSubview(closeButton)
        view.addSubview(overlayStack)
        view.addSubview(actionStack)

        let scanLineTopConstraint = scanLine.topAnchor.constraint(equalTo: scanFrame.topAnchor, constant: 16)
        self.scanLineTopConstraint = scanLineTopConstraint

        NSLayoutConstraint.activate([
            capturedImageView.topAnchor.constraint(equalTo: view.topAnchor),
            capturedImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            capturedImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            capturedImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            closeButton.widthAnchor.constraint(equalToConstant: 36),
            closeButton.heightAnchor.constraint(equalToConstant: 36),

            scanFrame.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanFrame.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -24),
            scanFrame.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.76),
            scanFrame.heightAnchor.constraint(equalTo: scanFrame.widthAnchor),

            scanLineTopConstraint,
            scanLine.leadingAnchor.constraint(equalTo: scanFrame.leadingAnchor, constant: 22),
            scanLine.trailingAnchor.constraint(equalTo: scanFrame.trailingAnchor, constant: -22),
            scanLine.heightAnchor.constraint(equalToConstant: 2),

            overlayStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            overlayStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            overlayStack.bottomAnchor.constraint(equalTo: actionStack.topAnchor, constant: -22),

            startButton.heightAnchor.constraint(equalToConstant: 52),
            rescanButton.heightAnchor.constraint(equalToConstant: 52),
            actionStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            actionStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            actionStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -28)
        ])
    }

    @objc private func cancelScan() {
        onCancel()
    }

    @objc private func startIdentification() {
        guard let capturedImage else { return }
        onImage(capturedImage)
    }

    @objc private func scanAgain() {
        capturedImage = nil
        capturedImageView?.image = nil
        capturedImageView?.isHidden = true
        actionStack?.isHidden = true
        scanLine?.isHidden = false
        titleLabel?.text = "Scanning plant..."
        subtitleLabel?.text = "Hold steady. LeafChat will capture automatically."
        canCaptureFrame = false
        didCaptureFrame = false

        videoQueue.async { [weak self] in
            guard let self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
            }
            DispatchQueue.main.async { [weak self] in
                self?.startScanLineAnimation()
            }
            self.videoQueue.asyncAfter(deadline: .now() + self.autoCaptureDelay) { [weak self] in
                self?.canCaptureFrame = true
            }
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard canCaptureFrame, !didCaptureFrame else { return }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        didCaptureFrame = true
        session.stopRunning()

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
        let image = UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .right)

        DispatchQueue.main.async { [weak self] in
            self?.showCapturedPreview(image)
        }
    }

    private func showCapturedPreview(_ image: UIImage) {
        capturedImage = image
        capturedImageView?.image = image
        capturedImageView?.isHidden = false
        actionStack?.isHidden = false
        stopScanLineAnimation()
        scanLine?.isHidden = true
        titleLabel?.text = "Ready to identify?"
        subtitleLabel?.text = "Use this scan or try again for a clearer plant view."
    }

    private func startScanLineAnimation() {
        guard let scanLineTopConstraint, let scanLine, let superview = scanLine.superview else { return }
        superview.layoutIfNeeded()
        scanLine.layer.removeAllAnimations()
        scanLineTopConstraint.constant = 16
        superview.layoutIfNeeded()

        UIView.animate(
            withDuration: 1.35,
            delay: 0,
            options: [.repeat, .autoreverse, .curveEaseInOut],
            animations: {
                scanLineTopConstraint.constant = max(16, superview.bounds.height - 18)
                superview.layoutIfNeeded()
            }
        )
    }

    private func stopScanLineAnimation() {
        scanLine?.layer.removeAllAnimations()
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
