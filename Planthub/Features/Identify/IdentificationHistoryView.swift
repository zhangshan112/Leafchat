import SwiftUI

// MARK: - IdentificationHistoryView

struct IdentificationHistoryView: View {

    var initialRecord: IdentificationRecord?

    @ObservedObject private var historyStore = IdentificationHistoryStore.shared
    @State private var selectedRecord: IdentificationRecord?
    @State private var showDeleteConfirmation = false
    @State private var recordToDelete: IdentificationRecord?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if historyStore.records.isEmpty {
                    emptyState
                } else {
                    recordsList
                }
            }
            .background(Color.phBackground.ignoresSafeArea())
            .navigationTitle("Scan History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.primaryBlue)
                }
                if !historyStore.records.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            Text("Clear All")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.hotCoral)
                        }
                    }
                }
            }
            .confirmationDialog(
                "Clear all scan history?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    historyStore.clearAll()
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(item: $selectedRecord) { record in
                RecordDetailSheet(record: record)
            }
            .onAppear {
                if let initial = initialRecord {
                    selectedRecord = initial
                }
            }
        }
    }

    // MARK: - Records List

    private var recordsList: some View {
        List {
            Section {
                statsHeader
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section {
                ForEach(historyStore.records) { record in
                    historyRow(record)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .onTapGesture { selectedRecord = record }
                }
                .onDelete { offsets in
                    offsets.forEach { index in
                        historyStore.remove(id: historyStore.records[index].id)
                    }
                }
            }
        }
        .listStyle(.plain)
        .background(Color.phBackground)
        .scrollContentBackground(.hidden)
    }

    private var statsHeader: some View {
        HStack(spacing: 0) {
            statCell(
                value: "\(historyStore.records.count)",
                label: "Total Scans",
                icon: "viewfinder",
                color: Color.primaryBlue
            )
            Rectangle().fill(Color.phBorder).frame(width: 1, height: 36)
            statCell(
                value: "\(uniquePlantCount)",
                label: "Unique Plants",
                icon: "tree.fill",
                color: Color.neonCyan
            )
            Rectangle().fill(Color.phBorder).frame(width: 1, height: 36)
            statCell(
                value: "\(highConfidenceCount)",
                label: "High Confidence",
                icon: "checkmark.circle.fill",
                color: Color.savedAmber
            )
        }
        .padding(.vertical, 16)
        .background(Color.phSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.phBorder, lineWidth: 0.5)
        )
    }

    private func statCell(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
            }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var uniquePlantCount: Int {
        Set(historyStore.records.map { $0.commonName.lowercased() }).count
    }

    private var highConfidenceCount: Int {
        historyStore.records.filter { $0.confidenceLevel == "high" }.count
    }

    // MARK: - History Row

    private func historyRow(_ record: IdentificationRecord) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.surfaceViolet)
                    .frame(width: 64, height: 64)

                if let thumb = record.thumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Image(systemName: "tree.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.primaryBlue.opacity(0.6))
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(record.commonName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    confidencePill(record.confidenceLevel)
                }

                if !record.scientificName.isEmpty {
                    Text(record.scientificName)
                        .font(.system(size: 12))
                        .italic()
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }

                Text(record.date, style: .date)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(14)
        .background(Color.phSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.phBorder.opacity(0.6), lineWidth: 0.5)
        )
    }

    private func confidencePill(_ level: String) -> some View {
        let (label, color): (String, Color) = switch level {
        case "high":   ("High", Color.primaryBlue)
        case "medium": ("Medium", Color.savedAmber)
        default:       ("Low", Color.textSecondary)
        }

        return Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: - Empty State

    private var emptyState: some View {
        EmptyStateView(
            systemImage: "viewfinder",
            title: "No scans yet.",
            description: "Identify your first plant to build your scan history.",
            actionTitle: "Identify a Plant",
            action: { dismiss() }
        )
    }
}

// MARK: - RecordDetailSheet

private struct RecordDetailSheet: View {

    let record: IdentificationRecord
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var session = UserSessionStore.shared
    @State private var showAIChat = false
    @State private var showPlantDetail = false
    @State private var addedToGarden = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    thumbnailSection
                    infoCard
                    careTipCard
                    actionButtons
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color.phBackground.ignoresSafeArea())
            .navigationTitle(record.commonName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.primaryBlue)
                }
            }
            .sheet(isPresented: $showAIChat) {
                if #available(iOS 26, *) {
                    PlantAIChatView(plantName: record.commonName)
                }
            }
            .navigationDestination(isPresented: $showPlantDetail) {
                PlantDetailView(plantName: record.commonName)
            }
        }
    }

    private var thumbnailSection: some View {
        Group {
            if let thumb = record.thumbnail {
                Image(uiImage: thumb)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.surfaceViolet)
                    .frame(height: 160)
                    .overlay {
                        Image(systemName: "tree.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(Color.primaryBlue.opacity(0.5))
                    }
            }
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                confidenceBadge(record.confidenceLevel)
                Spacer()
                Text(record.date, style: .date)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(record.commonName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                if !record.scientificName.isEmpty {
                    Text(record.scientificName)
                        .font(.system(size: 14))
                        .italic()
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.phSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var careTipCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "tree.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primaryBlue)
                Text("Care Tip")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.primaryBlue)
            }
            Text(record.careTip)
                .font(.system(size: 14))
                .foregroundStyle(Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.tagBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Primary: View full care guide
            Button {
                showPlantDetail = true
            } label: {
                Label("View Care Guide", systemImage: "book.fill")
                    .primaryButtonStyle()
            }
            .buttonStyle(.plain)

            HStack(spacing: 12) {
                // Add to My Garden
                Button {
                    guard !addedToGarden else { return }
                    guard let userId = session.collectionUserId else { return }
                    let wikiPlant = PlantWikiModel.plant(named: record.commonName)
                        ?? PlantWikiModel.plant(forTag: record.commonName)
                        ?? PlantWikiModel.fallbackPlant(named: record.commonName)
                    PlantCollectionStore.shared.add(wikiPlant, userId: userId)
                    withAnimation(.spring(response: 0.3)) { addedToGarden = true }
                } label: {
                    Label(
                        addedToGarden ? "In My Garden" : "Add to Garden",
                        systemImage: addedToGarden ? "checkmark.circle.fill" : "plus.circle"
                    )
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(addedToGarden ? Color.primaryBlue : Color.primaryBlue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.tagBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(addedToGarden)

                // Ask AI (iOS 26+)
                if #available(iOS 26, *) {
                    Button {
                        showAIChat = true
                    } label: {
                        Label("Ask AI", systemImage: "bubble.left.and.text.bubble.right.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.primaryBlue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.tagBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func confidenceBadge(_ level: String) -> some View {
        let (label, color): (String, Color) = switch level {
        case "high":   ("High Confidence", Color.primaryBlue)
        case "medium": ("Medium Confidence", Color.savedAmber)
        default:       ("Low Confidence", Color.textSecondary)
        }
        return HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}
