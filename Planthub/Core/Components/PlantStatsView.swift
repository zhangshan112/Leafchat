import SwiftUI

// MARK: - PlantStatsView

/// Three-column stat bar used at the top of PlantDetail.
/// Each column: number (18pt semibold, primaryBlue) + label (12pt, textSecondary).
struct PlantStatsView: View {

    let collectorsCount: Int
    let postsCount: Int
    let discussionsCount: Int

    var body: some View {
        HStack(spacing: 0) {
            statColumn(value: collectorsCount, label: "Collectors")
            separator
            statColumn(value: postsCount, label: "Posts")
            separator
            statColumn(value: discussionsCount, label: "Discussions")
        }
    }

    // MARK: Private

    private func statColumn(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text(formatCount(value))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.primaryBlue)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.phBorder)
            .frame(width: 1, height: 36)
    }

    private func formatCount(_ count: Int) -> String {
        switch count {
        case 0 ..< 1_000:        return "\(count)"
        case 1_000 ..< 1_000_000: return String(format: "%.1fk", Double(count) / 1_000)
        default:                  return String(format: "%.1fm", Double(count) / 1_000_000)
        }
    }
}

// MARK: - Preview

#Preview {
    PlantStatsView(
        collectorsCount: 1204,
        postsCount: 387,
        discussionsCount: 53
    )
    .padding(.horizontal, 16)
    .padding(.vertical, 20)
}
