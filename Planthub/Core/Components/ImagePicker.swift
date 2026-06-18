import SwiftUI
import PhotosUI

// MARK: - Internal model

private struct PickedImage: Identifiable, Equatable{
    let id = UUID()
    var image: UIImage
}

// MARK: - ImagePicker

/// Photo selection component.
/// Shows a PhotosPicker "Add" tile followed by 80×80 thumbnails in a horizontal
/// scroll. Each thumbnail has a delete overlay. Long-press + drag reorders items.
/// The parent receives updates via the `images: [UIImage]` binding.
struct ImagePicker: View {

    @Binding var images: [UIImage]
    var maxCount: Int = 9

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var internal_images: [PickedImage] = []
    @State private var isLoading = false

    // Drag-reorder state
    @State private var draggingId: UUID? = nil
    @State private var dragOffset: CGFloat = 0

    private let tileSize: CGFloat = 80
    private let tileSpacing: CGFloat = 10

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: tileSpacing) {
                if internal_images.count < maxCount {
                    addTile
                }
                ForEach(Array(internal_images.enumerated()), id: \.element.id) { index, item in
                    thumbnailTile(item: item, index: index)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .onChange(of: pickerItems) { _, newItems in
            Task { await loadImages(from: newItems) }
        }
        .onChange(of: internal_images) { _, newItems in
            images = newItems.map(\.image)
        }
        .onChange(of: images) { _, newImages in
            if newImages.isEmpty {
                internal_images = []
                pickerItems = []
            }
        }
        .onAppear {
            // Sync initial binding value into internal state when first mounted
            if internal_images.isEmpty, !images.isEmpty {
                internal_images = images.map { PickedImage(image: $0) }
            }
        }
    }

    // MARK: Add tile

    private var addTile: some View {
        PhotosPicker(
            selection: $pickerItems,
            maxSelectionCount: maxCount - internal_images.count,
            matching: .images
        ) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        Color.phBorder,
                        style: StrokeStyle(lineWidth: 1.5, dash: [6])
                    )
                    .background(
                        Color.phSurface
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    )

                VStack(spacing: 5) {
                    Image(systemName: isLoading ? "hourglass" : "plus")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.textSecondary)
                    Text(isLoading ? "Loading…" : "Add Photo")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .frame(width: tileSize, height: tileSize)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    // MARK: Thumbnail tile

    private func thumbnailTile(item: PickedImage, index: Int) -> some View {
        let isDragging = draggingId == item.id

        return ZStack(alignment: .topTrailing) {
            Image(uiImage: item.image)
                .resizable()
                .scaledToFill()
                .frame(width: tileSize, height: tileSize)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .opacity(isDragging ? 0.55 : 1)
                .scaleEffect(isDragging ? 1.06 : 1)
                .animation(.spring(response: 0.25), value: isDragging)

            // Delete button
            Button {
                withAnimation(.spring(response: 0.3)) {
                    internal_images.removeAll { $0.id == item.id }
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .background(
                        Circle()
                            .fill(Color.accentBlack.opacity(0.55))
                            .padding(2)
                    )
            }
            .buttonStyle(.plain)
            .offset(x: 6, y: -6)
        }
        .gesture(reorderGesture(for: item, at: index))
    }

    // MARK: Drag-to-reorder gesture

    private func reorderGesture(for item: PickedImage, at index: Int) -> some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 5))
            .onChanged { value in
                switch value {
                case .second(true, let drag?):
                    if draggingId == nil { draggingId = item.id }
                    dragOffset = drag.translation.width
                default:
                    break
                }
            }
            .onEnded { value in
                defer {
                    draggingId = nil
                    dragOffset = 0
                }
                guard case .second(true, let drag?) = value else { return }
                let steps = Int(round(drag.translation.width / (tileSize + tileSpacing)))
                guard steps != 0,
                      let fromIndex = internal_images.firstIndex(where: { $0.id == item.id })
                else { return }
                let toIndex = max(0, min(internal_images.count - 1, fromIndex + steps))
                guard toIndex != fromIndex else { return }
                withAnimation(.spring(response: 0.3)) {
                    let moved = internal_images.remove(at: fromIndex)
                    internal_images.insert(moved, at: toIndex)
                }
            }
    }

    // MARK: Image loading

    @MainActor
    private func loadImages(from items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        isLoading = true
        var loaded: [PickedImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                loaded.append(PickedImage(image: uiImage))
            }
        }
        withAnimation(.spring(response: 0.35)) {
            internal_images.append(contentsOf: loaded)
            if internal_images.count > maxCount {
                internal_images = Array(internal_images.prefix(maxCount))
            }
        }
        pickerItems = []
        isLoading = false
    }
}

