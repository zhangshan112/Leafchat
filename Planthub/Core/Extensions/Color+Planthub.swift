import SwiftUI

extension Color {
    // MARK: - Brand — Electric Violet (vibrant social identity, no green)
    static let primaryBlue = Color(hex: "#7C3AED")   // Electric Violet — primary brand, CTAs, selected
    static let secondaryBlue = Color(hex: "#C4B5FD") // Soft Lavender — secondary accents, tags
    static let accentBlack = Color(hex: "#0F0F1A")   // Deep Indigo-Black — auth screens, dark anchor

    // MARK: - Backgrounds
    static let phBackground = Color(.systemBackground)
    static let phSurface = Color(.secondarySystemBackground)

    // MARK: - Text
    static let textPrimary = Color(.label)
    static let textSecondary = Color(.secondaryLabel)

    // MARK: - Borders
    static let phBorder = Color(.separator)

    // MARK: - Tags
    static let tagBackground = Color(hex: "#7C3AED").opacity(0.10) // lavender pill

    // MARK: - Social interaction colors
    static let likeRed = Color(hex: "#FB7185")       // rose red — heart / like active
    static let savedAmber = Color(hex: "#F59E0B")    // amber gold — bookmark / save active
    static let hotCoral = Color(hex: "#F43F5E")      // vivid coral — trending / hot badge

    // MARK: - Neon community accents
    static let neonPink = Color(hex: "#EC4899")      // electric pink — community highlights
    static let neonCyan = Color(hex: "#06B6D4")      // electric cyan — explore / discover
    static let neonOrange = Color(hex: "#FB923C")    // vivid orange — notifications / badges

    // MARK: - Surface tints (replaces garden palette)
    static let surfaceViolet = Color(hex: "#7C3AED").opacity(0.06)  // subtle brand tint on surfaces
    static let surfaceCoral = Color(hex: "#F43F5E").opacity(0.08)   // coral tint for warm sections
    static let surfaceCyan = Color(hex: "#06B6D4").opacity(0.08)    // cyan tint for cool sections
    static let surfaceAmber = Color(hex: "#F59E0B").opacity(0.10)   // amber tint for warm accents

    // MARK: - Legacy garden tokens (kept for compiler safety, no longer used in views)
    static let gardenSage = Color(hex: "#8FAF8A")
    static let gardenMoss = Color(hex: "#5C7A5A")
    static let gardenCream = Color(hex: "#F7F5EF")
    static let gardenWarm = Color(hex: "#E8DCC8")
    static let gardenAmber = Color(hex: "#D4A853")
    static let gardenBlush = Color(hex: "#E8C4B8")

    // MARK: - Auth inputs (dark screens)
    static let authInputBackground = Color.white.opacity(0.05)
    static let authInputBorder = Color.white.opacity(0.10)
    static let authInputPlaceholder = Color(hex: "#6A7282")
}

// MARK: - Hex initialiser

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 200, 200, 200)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
