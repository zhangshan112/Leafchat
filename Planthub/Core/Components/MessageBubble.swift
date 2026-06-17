import SwiftUI
import UIKit

// MARK: - Message content type

enum MessageContent: Equatable {
    case text(String)
    case localImage(URL)
    /// Locally stored .m4a audio file with its recorded duration in seconds.
    case voice(URL, duration: TimeInterval)
}

// MARK: - View model

struct MessageBubbleData: Identifiable {
    let id: String
    let content: MessageContent
    /// True when the message belongs to the current user (right-aligned, blue).
    let isSelf: Bool
    let createdAt: Date
}

// MARK: - MessageBubble

/// Single chat message bubble.
/// Self  → right-aligned, primaryBlue background, white text, radius 18.
/// Other → left-aligned,  phSurface background, textPrimary text, radius 18.
/// Supports `.text`, `.localImage`, and `.voice` content.
struct MessageBubble: View {

    let message: MessageBubbleData

    @State private var voicePlayer = VoicePlayerService.shared

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.isSelf { Spacer(minLength: 60) }

            VStack(alignment: message.isSelf ? .trailing : .leading, spacing: 4) {
                bubbleBody
                timestampLabel
            }

            if !message.isSelf { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 16)
    }

    // MARK: Private — bubble body

    @ViewBuilder
    private var bubbleBody: some View {
        switch message.content {
        case .text(let text):
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(message.isSelf ? .white : Color.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(message.isSelf ? Color.primaryBlue : Color.phSurface)
                .clipShape(RoundedRectangle(cornerRadius: 18))

        case .localImage(let url):
            localImageView(url: url)

        case .voice(let url, let duration):
            voiceBubble(url: url, totalDuration: duration)
        }
    }

    // MARK: Private — voice bubble

    private func voiceBubble(url: URL, totalDuration: TimeInterval) -> some View {
        let isActive = voicePlayer.activeID == message.id
        let isPlayingThis = isActive && voicePlayer.isPlaying
        let progress = isActive ? voicePlayer.progress : 0
        let displayTime = isActive ? voicePlayer.elapsed : totalDuration

        return HStack(spacing: 10) {
            Button {
                voicePlayer.toggle(id: message.id, url: url)
            } label: {
                Image(systemName: isPlayingThis ? "pause.fill" : "play.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(message.isSelf ? .white : Color.primaryBlue)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(message.isSelf
                                  ? Color.white.opacity(0.25)
                                  : Color.primaryBlue.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)

            waveformBars(progress: progress, isPlaying: isPlayingThis)

            Text(formatDuration(displayTime))
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(message.isSelf ? .white.opacity(0.85) : Color.textSecondary)
                .frame(width: 34, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(message.isSelf ? Color.primaryBlue : Color.phSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func waveformBars(progress: Double, isPlaying: Bool) -> some View {
        // Static waveform heights — gives an organic, natural-looking shape.
        let heights: [CGFloat] = [5, 9, 13, 10, 16, 12, 8, 14, 10, 6, 11, 15, 9, 13, 7, 11, 14, 8, 10, 6]
        let total = heights.count

        return HStack(spacing: 2.5) {
            ForEach(0..<total, id: \.self) { index in
                let threshold = Double(index) / Double(total)
                let isPassed = progress > threshold
                let foreground = message.isSelf ? Color.white : Color.primaryBlue

                RoundedRectangle(cornerRadius: 1.5)
                    .frame(width: 2.5, height: heights[index])
                    .foregroundStyle(foreground.opacity(isPassed ? 1.0 : 0.3))
                    .animation(.easeInOut(duration: 0.05), value: isPassed)
            }
        }
        .frame(width: 76)
    }

    // MARK: Private — image bubble

    @ViewBuilder
    private func localImageView(url: URL) -> some View {
        if let uiImage = UIImage(contentsOfFile: url.path) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 18))
        } else {
            missingImagePlaceholder
        }
    }

    private var missingImagePlaceholder: some View {
        Color.phSurface
            .frame(width: 200, height: 200)
            .overlay(
                Image(systemName: "photo")
                    .foregroundStyle(Color.textSecondary)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: Private — helpers

    private var timestampLabel: some View {
        Text(message.createdAt.phRelative)
            .font(.system(size: 11))
            .foregroundStyle(Color.textSecondary)
            .padding(.horizontal, 4)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let total = max(0, Int(duration))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Date helper

private extension Date {
    var phRelative: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
