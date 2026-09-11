import SwiftUI

/// Maps a match rating onto the app's colour scale.
///
/// 9.0+ dark green · 8.0–8.9 green · 7.0–7.9 light green · 6.0–6.9 yellow
/// 5.0–5.9 orange · below 5.0 red · missing ratings render as a grey dash.
enum RatingTier: String, CaseIterable, Sendable {
    case elite
    case great
    case good
    case average
    case poor
    case bad
    case unrated

    init(rating: Double?) {
        guard let rating else {
            self = .unrated
            return
        }
        switch rating {
        case 9.0...: self = .elite
        case 8.0..<9.0: self = .great
        case 7.0..<8.0: self = .good
        case 6.0..<7.0: self = .average
        case 5.0..<6.0: self = .poor
        default: self = .bad
        }
    }

    var color: Color {
        switch self {
        case .elite: Theme.Palette.ratingElite
        case .great: Theme.Palette.ratingGreat
        case .good: Theme.Palette.ratingGood
        case .average: Theme.Palette.ratingAverage
        case .poor: Theme.Palette.ratingPoor
        case .bad: Theme.Palette.ratingBad
        case .unrated: Theme.Palette.ratingUnknown
        }
    }

    /// Yellow backgrounds need dark text to stay legible.
    var foreground: Color {
        switch self {
        case .average: Color.black.opacity(0.82)
        default: Color.white
        }
    }
}

enum RatingScale {
    static func tier(for rating: Double?) -> RatingTier {
        RatingTier(rating: rating)
    }

    static func color(for rating: Double?) -> Color {
        RatingTier(rating: rating).color
    }

    /// One decimal place, or an em dash when the rating is missing.
    static func text(for rating: Double?) -> String {
        guard let rating else { return L10n.Common.noRating }
        return String(format: "%.1f", rating)
    }

    static func average(of ratings: [Double?]) -> Double? {
        let values = ratings.compactMap { $0 }
        guard values.isEmpty == false else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
