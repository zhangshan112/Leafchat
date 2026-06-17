import SwiftUI

// MARK: - PostImageCarousel

/// Horizontal swipe carousel for bundled post images.
/// Aspect ratio 4:5. Single image shows no indicator; multiple images show
/// a dot indicator at the bottom (current dot = primaryBlue, rest = phBorder).
struct PostImageCarousel: View {

    let assetNames: [String]

    @State private var currentIndex = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentIndex) {
                ForEach(Array(assetNames.enumerated()), id: \.offset) { index, assetName in
                    imageSlide(assetName: assetName)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .mediaFill()

            if assetNames.count > 1 {
                pageIndicator
            }
        }
        .mediaContainer(aspectRatio: 4.0 / 5.0)
    }

    // MARK: Private

    private func imageSlide(assetName: String) -> some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
            .mediaFill()
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0 ..< assetNames.count, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? Color.primaryBlue : Color.phBorder)
                    .frame(width: 6, height: 6)
                    .animation(.easeInOut(duration: 0.15), value: currentIndex)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.28))
        .clipShape(Capsule())
        .padding(.bottom, 12)
    }
}
