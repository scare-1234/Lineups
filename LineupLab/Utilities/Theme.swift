import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Design tokens for the whole app: dark-mode first, light mode fully supported.
enum Theme {

    enum Palette {
        /// Deep football green — #1B5E20
        static let primary = Color(hex: 0x1B5E20)
        /// Bright green — #00C853
        static let accent = Color(hex: 0x00C853)
        /// Pitch fill — #2E7D32
        static let pitch = Color(hex: 0x2E7D32)
        static let pitchDark = Color(hex: 0x1B5E20)
        static let pitchLine = Color.white.opacity(0.75)

        static let background = dynamic(light: 0xF5F5F5, dark: 0x121212)
        static let card = dynamic(light: 0xFFFFFF, dark: 0x1E1E1E)
        static let cardElevated = dynamic(light: 0xFFFFFF, dark: 0x272727)
        static let separator = dynamic(light: 0xE0E0E0, dark: 0x2C2C2C)
        static let primaryText = dynamic(light: 0x121212, dark: 0xF5F5F5)
        static let secondaryText = dynamic(light: 0x5F6368, dark: 0x9E9E9E)

        static let live = Color(hex: 0xE53935)
        static let warning = Color(hex: 0xFFB300)

        // Rating scale
        static let ratingElite = Color(hex: 0x1B5E20)
        static let ratingGreat = Color(hex: 0x2E7D32)
        static let ratingGood = Color(hex: 0x66BB6A)
        static let ratingAverage = Color(hex: 0xFDD835)
        static let ratingPoor = Color(hex: 0xFB8C00)
        static let ratingBad = Color(hex: 0xE53935)
        static let ratingUnknown = Color(hex: 0x9E9E9E)

        private static func dynamic(light: UInt32, dark: UInt32) -> Color {
            #if canImport(UIKit)
            return Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(rgb: dark)
                    : UIColor(rgb: light)
            })
            #else
            return Color(hex: light)
            #endif
        }
    }

    enum Layout {
        static let cornerRadius: CGFloat = 12
        static let smallCornerRadius: CGFloat = 8
        static let cardPadding: CGFloat = 14
        static let sectionSpacing: CGFloat = 18
        static let rowSpacing: CGFloat = 10
        static let ratingBadgeSize: CGFloat = 28
        static let avatarSize: CGFloat = 40
        static let largeAvatarSize: CGFloat = 108
        static let pitchAspectRatio: CGFloat = 0.68
    }

    /// Semantic text styles. Using the semantic sizes keeps Dynamic Type working while
    /// matching the intended scale (large title 34, title 22, body 17, caption 12).
    enum Typography {
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title = Font.title2.weight(.semibold)
        static let sectionTitle = Font.headline
        static let body = Font.body
        static let bodyEmphasis = Font.body.weight(.semibold)
        static let callout = Font.callout
        static let caption = Font.caption
        static let captionEmphasis = Font.caption.weight(.semibold)
        static let monoNumber = Font.system(.body, design: .rounded).weight(.bold)
    }

    enum Motion {
        static let slotSpring = Animation.spring(response: 0.38, dampingFraction: 0.72)
        static let formationChange = Animation.spring(response: 0.5, dampingFraction: 0.78)
        static let quick = Animation.easeInOut(duration: 0.2)
    }
}

extension Color {
    /// Builds a colour from a 0xRRGGBB literal. Never fails, so no force unwrapping.
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

#if canImport(UIKit)
extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
#endif

// MARK: - Reusable modifiers

struct CardBackground: ViewModifier {
    var padding: CGFloat = Theme.Layout.cardPadding

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius, style: .continuous))
    }
}

extension View {
    func cardStyle(padding: CGFloat = Theme.Layout.cardPadding) -> some View {
        modifier(CardBackground(padding: padding))
    }
}
