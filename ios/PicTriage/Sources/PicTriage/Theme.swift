import SwiftUI

extension Color {
    /// Convenience initializer for the design's hex palette (e.g. "E89B1C" or "#E89B1C").
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value & 0xFF0000) >> 16) / 255
        let g = Double((value & 0x00FF00) >> 8) / 255
        let b = Double(value & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

/// Color and layout constants pulled 1:1 from `Photo Cleaner Dashboard.dc.html`.
enum Theme {
    static let screenBackground = Color(hex: "FDF3E4")

    static let textPrimary = Color(hex: "241f1b")
    static let textSecondary = Color(hex: "8b7d6d")
    static let textMuted = Color(hex: "9c8d7c")
    static let labelMuted = Color(hex: "A8998A")

    static let accent = Color(hex: "E89B1C")
    static let cardBorder = Color(hex: "EFE2CC")
    static let ringTrack = Color(hex: "F4EADA")

    static let badgeBg = Color(hex: "F7E7CE")
    static let quickAmountText = Color(hex: "C77A1E")
    static let quickAmountBg = Color(hex: "FBEFD9")

    static let navBorder = Color(hex: "F0E3CE")
    static let navActiveBg = Color(hex: "FBEFD9")

    static let pink = Color(hex: "EA4C93")
    static let red = Color(hex: "D63F3F")
    static let green = Color(hex: "2E9E6B")
    static let dark = Color(hex: "241f1b")

    static let stripeLight = Color(hex: "EFE6D8")
    static let stripeDark = Color(hex: "E4D8C6")

    static let segmentBg = Color(hex: "F7EEDF")
    static let dividerLine = Color(hex: "F4EADA")
    static let chevron = Color(hex: "C0B3A3")
    static let remindOffTrack = Color(hex: "DFD3C1")
    static let confirmIdleBg = Color(hex: "CFC2AE")
    static let dashedBorder = Color(hex: "E5D5BC")
    static let cardShadow = Color(hex: "785A32")

    static let sprintStart = Color(hex: "F0A63C")
    static let sprintMid = Color(hex: "F4855F")
    static let sprintEnd = Color(hex: "EE6F86")

    static let ctaStart = Color(hex: "E9A02C")
    static let ctaMid = Color(hex: "F0705F")
    static let ctaEnd = Color(hex: "EA4C93")
}

/// The design uses Nunito (headings/body) and IBM Plex Mono (placeholder captions) via Google Fonts.
/// Neither ships on iOS, so this stands in with the system's rounded design as an interim look-alike.
/// For full brand fidelity, add the Nunito + IBM Plex Mono .ttf files (both SIL OFL licensed) to the
/// target and switch `.system(size:weight:design:.rounded)` calls to `.custom(_:size:)`.
extension Font {
    static func heading(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func mono(_ size: CGFloat) -> Font {
        .system(size: size, design: .monospaced)
    }
}
