import SwiftUI

extension Font {
    // 32pt Bold — screen-level titles (rare, e.g. Onboarding hero)
    static let largeTitle = Font.system(size: 32, weight: .bold)

    // 24pt Semibold — page NavigationBar titles when custom
    static let pageTitle = Font.system(size: 24, weight: .semibold)

    // 18pt Semibold — section headers, card headings
    static let sectionTitle = Font.system(size: 18, weight: .semibold)

    // 16pt Regular — default body copy
    static let bodyText = Font.system(size: 16, weight: .regular)

    // 14pt Regular — secondary info, timestamps
    static let captionText = Font.system(size: 14, weight: .regular)

    // 12pt Regular — badges, small labels
    static let smallText = Font.system(size: 12, weight: .regular)
}
