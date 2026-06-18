import SwiftUI

// MARK: - Local models

/// A plant chosen as the primary specimen for the post. Backed by either a
/// catalog entry (auto-fills scientific name + sample image) or a custom name.
private struct SelectedPlant: Identifiable, Hashable {
    let id: String
    let name: String
    let scientificName: String?
    let sampleImageAssetName: String?

    init(entry: PlantCatalogEntry) {
        id = entry.id
        name = entry.name
        scientificName = entry.scientificName
        sampleImageAssetName = entry.sampleImageAssetName
    }

    init(customName: String) {
        id = "custom-\(customName.lowercased())"
        name = customName
        scientificName = nil
        sampleImageAssetName = nil
    }

    /// Used when a plant is pre-filled from the AI identifier.
    init(identifiedName: String, scientificName: String?) {
        id = "identified-\(identifiedName.lowercased().replacingOccurrences(of: " ", with: "-"))"
        name = identifiedName
        self.scientificName = scientificName
        sampleImageAssetName = PlantWikiModel.plant(named: identifiedName)
            .flatMap { $0.imageName.isEmpty ? nil : $0.imageName }
    }
}

private struct PublishedPostSummary: Identifiable, Hashable {
    let id = UUID()
    let postId: String
    let plantName: String
    let scientificName: String?
    let caption: String
    let statusLabel: String
    let plotTitle: String
    let tagNames: [String]
    let imageCount: Int
}

// MARK: - PostView

struct PostView: View {

    @ObservedObject private var store = GardenFeedStore.shared
    @Bindable private var entitlements = EntitlementStore.shared

    // Content
    @State private var images: [UIImage] = []
    @State private var caption = ""

    // Selectable, aligned with what the home card displays
    @State private var primaryPlant: SelectedPlant?
    @State private var status: PlantStatus?
    @State private var plot: GardenPlot?
    @State private var selectedTags: [String] = []

    // Plant picker sheet
    @State private var isShowingPlantSheet = false
    @State private var plantSearchText = ""

    // Custom tag entry
    @State private var customTagText = ""

    @State private var isPublishing = false
    @State private var publishedSummary: PublishedPostSummary?
    /// Bumped on reset so ImagePicker and other subviews remount with a clean slate.
    @State private var formSessionID = UUID()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    introHeader
                    postQuotaBanner
                    photoSection
                    plantSection
                    statusSection
                    plotSection
                    tagsSection
                    captionSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .id(formSessionID)
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .background(Color.phBackground)
            .navigationTitle("Share a Plant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        publish()
                    } label: {
                        if isPublishing {
                            ProgressView()
                                .tint(Color.primaryBlue)
                        } else {
                            Text("Share")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .foregroundStyle(canPublish && !isPublishing ? Color.primaryBlue : Color.primaryBlue.opacity(0.4))
                    .disabled(!canPublish || isPublishing)
                }
            }
            .sheet(isPresented: $isShowingPlantSheet) {
                plantSearchSheet
            }
            .navigationDestination(item: $publishedSummary) { summary in
                PublishedConfirmationView(
                    summary: summary,
                    onViewInGarden: {
                        publishedSummary = nil
                        resetForm()
                        AppTabRouter.shared.openHomePost(postId: summary.postId)
                    },
                    onShareAnother: {
                        publishedSummary = nil
                        resetForm()
                    }
                )
            }
            .onAppear {
                consumeDraftIfNeeded()
            }
            .onChange(of: publishedSummary) { oldValue, newValue in
                // System back from confirmation — ensure the compose form is cleared.
                if oldValue != nil, newValue == nil {
                    resetForm()
                }
            }
            .onChange(of: PostDraftStore.shared.pending) { _, draft in
                guard draft != nil else { return }
                consumeDraftIfNeeded()
            }
        }
    }

    // MARK: - Draft prefill

    private func consumeDraftIfNeeded() {
        guard let draft = PostDraftStore.shared.consume() else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            if let entry = PlantCatalog.entry(forName: draft.plantName) {
                primaryPlant = SelectedPlant(entry: entry)
            } else {
                primaryPlant = SelectedPlant(
                    identifiedName: draft.plantName,
                    scientificName: draft.scientificName
                )
            }
            if !draft.images.isEmpty {
                images = draft.images
            }
        }
    }

    // MARK: - Intro

    private var introHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("What's growing today?")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.textPrimary)
            Text("Choose a plant, status, and plot — add a photo or caption to share.")
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
        }
    }

    @ViewBuilder
    private var postQuotaBanner: some View {
        if entitlements.subscriptionTier == .advanced {
            quotaBanner(
                icon: "infinity",
                text: "Unlimited posts with LeafChat Plus",
                tint: Color.primaryBlue,
                background: Color.tagBackground
            )
        } else {
            let remaining = entitlements.remainingPostsThisMonth ?? 0
            let limit = entitlements.monthlyPostLimit ?? 0
            if remaining > 0 {
                quotaBanner(
                    icon: "square.and.pencil",
                    text: "\(remaining) of \(limit) posts left this month",
                    tint: entitlements.subscriptionTier == .basic ? Color.primaryBlue : Color.savedAmber,
                    background: entitlements.subscriptionTier == .basic ? Color.tagBackground : Color.surfaceAmber
                )
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    quotaBanner(
                        icon: "lock.fill",
                        text: "Monthly post limit reached. Upgrade to publish more.",
                        tint: Color.hotCoral,
                        background: Color.surfaceCoral
                    )
                    PrimaryButton(title: "Unlock More Posts") {
                        PaywallPresenter.shared.present(source: .membership, tab: .subscription)
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

    // MARK: - Photos

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Photos", subtitle: "Optional — add up to 9 images.")
            ImagePicker(images: $images, maxCount: 9)
                .padding(.horizontal, -16)
        }
    }

    // MARK: - Plant (required)

    private var plantSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Plant", subtitle: "Choose the star of your post.")

            Button {
                plantSearchText = ""
                isShowingPlantSheet = true
            } label: {
                HStack(spacing: 12) {
                    plantThumbnail

                    VStack(alignment: .leading, spacing: 3) {
                        Text(primaryPlant?.name ?? "Choose a plant")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(primaryPlant == nil ? Color.textSecondary : Color.textPrimary)
                        if let scientific = primaryPlant?.scientificName {
                            Text(scientific)
                                .font(.system(size: 13).italic())
                                .foregroundStyle(Color.textSecondary)
                                .lineLimit(1)
                        } else if primaryPlant != nil {
                            Text("Custom plant")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.textSecondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(14)
                .background(Color.phSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(primaryPlant == nil ? Color.phBorder : Color.primaryBlue.opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var plantThumbnail: some View {
        let size: CGFloat = 44
        if let assetName = primaryPlant?.sampleImageAssetName {
            Image(assetName)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            plantThumbnailPlaceholder
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var plantThumbnailPlaceholder: some View {
        ZStack {
            Color.tagBackground
            Image(systemName: "leaf.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.primaryBlue)
        }
    }

    // MARK: - Status (selectable)

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "How's it doing?", subtitle: "Pick a status for your plant.")

            FlowChips(spacing: 8) {
                ForEach(PlantStatus.allCases) { option in
                    chip(
                        title: option.label,
                        systemImage: option.symbol,
                        isSelected: status == option,
                        accent: statusAccent(option)
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) { status = option }
                    }
                }
            }
        }
    }

    private func statusAccent(_ status: PlantStatus) -> Color {
        switch status {
        case .thriving:   return Color.primaryBlue
        case .recovering: return Color.savedAmber
        case .sprouting:  return Color.hotCoral
        case .resting:    return Color.textSecondary
        }
    }

    // MARK: - Plot (selectable)

    private var plotSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Garden Plot", subtitle: "Which collection does it belong to?")

            FlowChips(spacing: 8) {
                ForEach(GardenPlot.allCases) { option in
                    chip(
                        title: option.title,
                        systemImage: option.icon,
                        isSelected: plot == option,
                        accent: Color.primaryBlue
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) { plot = option }
                    }
                }
            }
        }
    }

    // MARK: - Tags (selectable + custom)

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Tags", subtitle: "Optional — tap suggestions or add your own.")

            if !selectedTags.isEmpty {
                FlowChips(spacing: 8) {
                    ForEach(selectedTags, id: \.self) { tag in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedTags.removeAll { $0 == tag }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text("#\(tag)")
                                    .font(.system(size: 13, weight: .medium))
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.primaryBlue)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !suggestedTags.isEmpty {
                FlowChips(spacing: 8) {
                    ForEach(suggestedTags, id: \.self) { tag in
                        Button {
                            addTag(tag)
                        } label: {
                            Text("#\(tag)")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.primaryBlue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color.tagBackground)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Add a custom tag", text: $customTagText)
                    .font(.system(size: 14))
                    .frame(height: 44)
                    .padding(.horizontal, 14)
                    .background(Color.phSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.phBorder, lineWidth: 1)
                    )
                    .onSubmit { addCustomTag() }

                Button {
                    addCustomTag()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(canAddCustomTag ? Color.primaryBlue : Color.primaryBlue.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(!canAddCustomTag)
            }
        }
    }

    // MARK: - Caption

    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Caption", subtitle: "Optional — share the story behind it.")
            TextArea(
                placeholder: "What's the update? Light, watering, a new leaf…",
                text: $caption,
                maxLength: 1000
            )
        }
    }

    // MARK: - Reusable chip

    private func chip(
        title: String,
        systemImage: String,
        isSelected: Bool,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(isSelected ? .white : Color.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(isSelected ? accent : Color.phSurface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.phBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - Plant search sheet

    private var plantSearchSheet: some View {
        NavigationStack {
            VStack(spacing: 12) {
                SearchBar(text: $plantSearchText, placeholder: "Search plants")
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                List {
                    if canUseCustomPlant {
                        Button {
                            selectCustomPlant()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color.primaryBlue)
                                Text("Use \"\(trimmedPlantQuery)\" as a custom plant")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Color.textPrimary)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(filteredCatalog) { entry in
                        Button {
                            selectCatalogPlant(entry)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Color.textPrimary)
                                    Text(entry.scientificName)
                                        .font(.system(size: 13).italic())
                                        .foregroundStyle(Color.textSecondary)
                                }
                                Spacer()
                                if primaryPlant?.id == entry.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.primaryBlue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
                .scrollDismissesKeyboard(.interactively)
            }
            .background(Color.phBackground)
            .navigationTitle("Choose a Plant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isShowingPlantSheet = false }
                        .foregroundStyle(Color.primaryBlue)
                }
            }
        }
    }

    // MARK: - Derived values

    private var trimmedPlantQuery: String {
        plantSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredCatalog: [PlantCatalogEntry] {
        PlantCatalog.search(plantSearchText)
    }

    private var canUseCustomPlant: Bool {
        !trimmedPlantQuery.isEmpty &&
        !filteredCatalog.contains { $0.name.localizedCaseInsensitiveCompare(trimmedPlantQuery) == .orderedSame }
    }

    /// Suggested tags = trending tags from the feed, minus ones already chosen.
    private var suggestedTags: [String] {
        var pool = store.trendingTags
        if let plantName = primaryPlant?.name {
            let condensed = plantName.replacingOccurrences(of: " ", with: "")
            if !pool.contains(where: { $0.caseInsensitiveCompare(condensed) == .orderedSame }) {
                pool.insert(condensed, at: 0)
            }
        }
        return pool.filter { tag in
            !selectedTags.contains { $0.caseInsensitiveCompare(tag) == .orderedSame }
        }
    }

    private var canAddCustomTag: Bool {
        !customTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canPublish: Bool {
        let hasPlant = primaryPlant != nil
        let hasStatus = status != nil
        let hasPlot = plot != nil
        let hasBody = !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !images.isEmpty
        return hasPlant && hasStatus && hasPlot && hasBody && entitlements.canPublishPost()
    }

    // MARK: - Actions

    private func selectCatalogPlant(_ entry: PlantCatalogEntry) {
        withAnimation(.easeInOut(duration: 0.15)) {
            primaryPlant = SelectedPlant(entry: entry)
        }
        isShowingPlantSheet = false
    }

    private func selectCustomPlant() {
        withAnimation(.easeInOut(duration: 0.15)) {
            primaryPlant = SelectedPlant(customName: trimmedPlantQuery)
        }
        isShowingPlantSheet = false
    }

    private func addTag(_ tag: String) {
        let clean = sanitizeTag(tag)
        guard !clean.isEmpty else { return }
        guard !selectedTags.contains(where: { $0.caseInsensitiveCompare(clean) == .orderedSame }) else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedTags.append(clean)
        }
    }

    private func addCustomTag() {
        guard canAddCustomTag else { return }
        addTag(customTagText)
        customTagText = ""
    }

    private func sanitizeTag(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: " ", with: "")
    }

    private func publish() {
        guard canPublish,
              let plant = primaryPlant,
              let status,
              let plot else { return }
        guard entitlements.canPublishPost() else {
            PaywallPresenter.shared.present(source: .membership, tab: .subscription)
            return
        }
        isPublishing = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let createdPost = store.publish(
                plantName: plant.name,
                scientificName: plant.scientificName,
                caption: caption,
                status: status,
                plot: plot,
                plantTags: selectedTags,
                coverImage: images.first
            )

            if let createdPost {
                entitlements.consumePostQuotaIfNeeded()

                let summary = PublishedPostSummary(
                    postId: createdPost.id,
                    plantName: plant.name,
                    scientificName: plant.scientificName,
                    caption: caption.trimmingCharacters(in: .whitespacesAndNewlines),
                    statusLabel: status.label,
                    plotTitle: plot.title,
                    tagNames: selectedTags,
                    imageCount: images.count
                )

                resetForm()
                publishedSummary = summary
            }

            isPublishing = false
        }
    }

    private func resetForm() {
        images = []
        caption = ""
        primaryPlant = nil
        status = nil
        plot = nil
        selectedTags = []
        customTagText = ""
        plantSearchText = ""
        formSessionID = UUID()
    }
}

// MARK: - Flow layout for chips

/// A simple wrapping flow layout so chips wrap onto multiple lines.
private struct FlowChips: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth == .infinity ? rowWidth : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Published confirmation

private struct PublishedConfirmationView: View {
    let summary: PublishedPostSummary
    let onViewInGarden: () -> Void
    let onShareAnother: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.primaryBlue)
                    .padding(.top, 24)

                Text("Shared to your Garden")
                    .font(.pageTitle)
                    .foregroundStyle(Color.textPrimary)

                Text("It's now live at the top of the Home feed.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)

                VStack(alignment: .leading, spacing: 12) {
                    summaryRow(icon: "leaf.fill", label: summary.plantName, detail: summary.scientificName)
                    summaryRow(icon: "circle.hexagongrid.fill", label: summary.plotTitle, detail: "Garden plot")
                    summaryRow(icon: "heart.text.square.fill", label: summary.statusLabel, detail: "Status")
                    summaryRow(icon: "photo.fill", label: "\(summary.imageCount) photo\(summary.imageCount == 1 ? "" : "s")", detail: nil)

                    if !summary.caption.isEmpty {
                        Divider()
                        Text(summary.caption)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !summary.tagNames.isEmpty {
                        Divider()
                        HStack(spacing: 8) {
                            ForEach(summary.tagNames, id: \.self) { tag in
                                Tag(name: tag)
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color.phSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(spacing: 12) {
                    PrimaryButton(title: "View in Garden", action: onViewInGarden)

                    Button(action: onShareAnother) {
                        Text("Share Another")
                            .secondaryButtonStyle()
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)

                Spacer(minLength: 12)
            }
            .padding(.horizontal, 24)
        }
        .background(Color.phBackground)
        .navigationTitle("Shared")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    private func summaryRow(icon: String, label: String, detail: String?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.primaryBlue)
                .frame(width: 22)
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.textPrimary)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }
}
