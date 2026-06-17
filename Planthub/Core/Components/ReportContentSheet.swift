import SwiftUI

// MARK: - ReportContentSheet

struct ReportContentSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let message: String
    var onSubmit: (CommunityReportSubmission) -> Void

    @State private var selectedReason: CommunityReportReason?
    @State private var customDetail = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(message)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Why are you reporting this?")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)

                        ForEach(CommunityReportReason.allCases) { reason in
                            reasonRow(reason)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(selectedReason == .other ? "Tell us more" : "Additional details (optional)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)

                        TextArea(
                            placeholder: selectedReason == .other
                                ? "Describe what happened."
                                : "Add context for our moderation review.",
                            text: $customDetail,
                            maxLength: 300
                        )
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.hotCoral)
                    }

                    PrimaryButton(
                        title: "Submit Report",
                        isDisabled: !canSubmit,
                        action: submitReport
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(Color.phBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func reasonRow(_ reason: CommunityReportReason) -> some View {
        let isSelected = selectedReason == reason

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedReason = reason
                errorMessage = nil
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? Color.primaryBlue : Color.textSecondary)

                Text(reason.title)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.phSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.primaryBlue : Color.phBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var canSubmit: Bool {
        guard let selectedReason else { return false }
        if selectedReason == .other {
            return !customDetail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    private func submitReport() {
        guard let selectedReason else {
            errorMessage = "Select a report reason to continue."
            return
        }

        let trimmedDetail = customDetail.trimmingCharacters(in: .whitespacesAndNewlines)
        if selectedReason == .other && trimmedDetail.isEmpty {
            errorMessage = "Please describe the issue when choosing Other."
            return
        }

        onSubmit(
            CommunityReportSubmission(
                reason: selectedReason,
                customDetail: trimmedDetail
            )
        )
        dismiss()
    }
}
