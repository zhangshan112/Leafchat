import SwiftUI

// MARK: - Tag Mode

enum TagMode {
    case display    // read-only pill shown in posts / detail pages
    case selectable // interactive selection in the Post / create-discussion flow
}

// MARK: - Tag

/// Plant tag pill displaying a `#PlantName` label.
/// In `.display` mode, tapping navigates to PlantDetail.
/// In `.selectable` mode, tapping toggles the selected state.
struct Tag: View {

    let name: String
    var mode: TagMode = .display
    var isSelected: Bool = false
    var isDisabled: Bool = false

    /// Called when the tag is tapped in `.display` mode (pass plantId or navigation logic here).
    var onTap: (() -> Void)? = nil
    /// Called when the selection state changes in `.selectable` mode.
    var onToggle: ((Bool) -> Void)? = nil

    var body: some View {
        Button(action: handleTap) {
            Text("#\(name)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(labelColor)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(pillBackground)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(pillBorderColor, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: Private

    private var labelColor: Color {
        switch mode {
        case .display:
            return Color.primaryBlue
        case .selectable:
            return isSelected ? .white : Color.primaryBlue
        }
    }

    private var pillBackground: Color {
        switch mode {
        case .display:
            return Color.tagBackground
        case .selectable:
            return isSelected ? Color.primaryBlue : Color.tagBackground
        }
    }

    private var pillBorderColor: Color {
        switch mode {
        case .display:
            return Color.primaryBlue.opacity(0.2)
        case .selectable:
            return isSelected ? Color.clear : Color.primaryBlue.opacity(0.2)
        }
    }

    private func handleTap() {
        guard !isDisabled else { return }
        switch mode {
        case .display:
            onTap?()
        case .selectable:
            onToggle?(!isSelected)
        }
    }
}

// MARK: - PlantTagLink

/// Navigates to the plant encyclopedia when the tag maps to a wiki entry;
/// otherwise renders a read-only topic tag pill.
struct PlantTagLink: View {
    let name: String

    var body: some View {
        if PlantWikiModel.isPlantTag(name) {
            NavigationLink {
                PlantDetailView(plantName: name)
            } label: {
                Tag(name: name)
            }
            .buttonStyle(.plain)
        } else {
            Tag(name: name)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: 20) {

        // Display tags
        HStack {
            Tag(name: "Monstera")
            Tag(name: "Pothos")
            Tag(name: "Alocasia")
        }

        // Selectable — unselected
        HStack {
            Tag(name: "Fern", mode: .selectable, isSelected: false)
            Tag(name: "Cactus", mode: .selectable, isSelected: true)
        }

        // Disabled
        Tag(name: "Orchid", isDisabled: true)
    }
    .padding(16)
}
