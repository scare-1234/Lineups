import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Thin wrapper so views can request haptics without importing UIKit everywhere.
@MainActor
enum Haptics {

    enum Impact {
        case light, medium, heavy, soft, rigid
    }

    static func impact(_ style: Impact = .medium) {
        #if canImport(UIKit) && !targetEnvironment(macCatalyst)
        let generator = UIImpactFeedbackGenerator(style: style.uiStyle)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    static func selection() {
        #if canImport(UIKit) && !targetEnvironment(macCatalyst)
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
        #endif
    }

    static func success() {
        #if canImport(UIKit) && !targetEnvironment(macCatalyst)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    static func warning() {
        #if canImport(UIKit) && !targetEnvironment(macCatalyst)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }
}

#if canImport(UIKit)
private extension Haptics.Impact {
    var uiStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .light: .light
        case .medium: .medium
        case .heavy: .heavy
        case .soft: .soft
        case .rigid: .rigid
        }
    }
}
#endif
