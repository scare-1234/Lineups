import SwiftUI

/// Circular, colour-coded match rating. Shows a grey dash when a rating is missing.
struct RatingBadge: View {
    let rating: Double?
    var size: CGFloat = Theme.Layout.ratingBadgeSize
    var showsBorder = true

    private var tier: RatingTier { RatingScale.tier(for: rating) }

    var body: some View {
        Text(RatingScale.text(for: rating))
            .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .foregroundStyle(rating == nil ? Theme.Palette.secondaryText : tier.foreground)
            .frame(width: size, height: size)
            .background {
                Circle()
                    .fill(rating == nil ? Theme.Palette.ratingUnknown.opacity(0.18) : tier.color)
            }
            .overlay {
                if showsBorder {
                    Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.A11y.ratingBadge)
            .accessibilityValue(rating == nil ? L10n.Common.noRating : RatingScale.text(for: rating))
    }
}

/// Larger rating used on the player detail sheet.
struct RatingHeadline: View {
    let rating: Double?

    var body: some View {
        VStack(spacing: 2) {
            Text(RatingScale.text(for: rating))
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(rating == nil ? Theme.Palette.secondaryText : RatingScale.color(for: rating))
            Text(L10n.Player.latestRating)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Rating badges") {
    VStack(spacing: 12) {
        HStack(spacing: 10) {
            RatingBadge(rating: 9.4)
            RatingBadge(rating: 8.3)
            RatingBadge(rating: 7.1)
            RatingBadge(rating: 6.4)
            RatingBadge(rating: 5.2)
            RatingBadge(rating: 4.1)
            RatingBadge(rating: nil)
        }
        RatingHeadline(rating: 8.4)
        RatingHeadline(rating: nil)
    }
    .padding()
    .background(Theme.Palette.background)
}
