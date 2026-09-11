import SwiftUI

/// Stats tab: possession split plus the headline comparison rows.
struct MatchStatsView: View {
    let home: TeamMatchStatistics?
    let away: TeamMatchStatistics?
    let homeTeam: Team
    let awayTeam: Team
    let homePossession: Double

    var body: some View {
        VStack(spacing: Theme.Layout.sectionSpacing) {
            possessionCard
            comparisonCard
        }
    }

    private var possessionCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text(homeTeam.name).font(Theme.Typography.caption).lineLimit(1)
                Spacer()
                Text(L10n.MatchDetail.possession)
                    .font(Theme.Typography.captionEmphasis)
                    .foregroundStyle(Theme.Palette.secondaryText)
                Spacer()
                Text(awayTeam.name).font(Theme.Typography.caption).lineLimit(1)
            }

            GeometryReader { proxy in
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Palette.accent)
                        .frame(width: max(0, proxy.size.width * homePossession - 1))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Palette.secondaryText.opacity(0.55))
                }
            }
            .frame(height: 14)

            HStack {
                Text(percentText(homePossession))
                    .font(Theme.Typography.captionEmphasis)
                Spacer()
                Text(percentText(1 - homePossession))
                    .font(Theme.Typography.captionEmphasis)
            }
        }
        .cardStyle()
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }

    private var comparisonCard: some View {
        VStack(spacing: 12) {
            ForEach(MatchStatisticKey.comparisonRows, id: \.self) { key in
                StatComparisonRow(
                    title: key.displayName,
                    homeValue: home?.value(for: key),
                    awayValue: away?.value(for: key),
                    homeNumber: home?.intValue(for: key),
                    awayNumber: away?.intValue(for: key)
                )
            }
        }
        .cardStyle()
        .padding(.horizontal)
    }

    private func percentText(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

/// One stat row with a proportional bar on each side.
struct StatComparisonRow: View {
    let title: String
    let homeValue: String?
    let awayValue: String?
    let homeNumber: Int?
    let awayNumber: Int?

    private var total: Double {
        Double((homeNumber ?? 0) + (awayNumber ?? 0))
    }

    private var homeShare: Double {
        guard total > 0 else { return 0.5 }
        return Double(homeNumber ?? 0) / total
    }

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(homeValue ?? L10n.Common.noRating)
                    .font(Theme.Typography.captionEmphasis)
                Spacer()
                Text(title)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.secondaryText)
                Spacer()
                Text(awayValue ?? L10n.Common.noRating)
                    .font(Theme.Typography.captionEmphasis)
            }

            GeometryReader { proxy in
                HStack(spacing: 2) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.Palette.accent)
                        .frame(width: max(2, proxy.size.width / 2 * homeShare))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.Palette.secondaryText.opacity(0.55))
                        .frame(width: max(2, proxy.size.width / 2 * (1 - homeShare)))
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue("\(homeValue ?? L10n.Common.noRating), \(awayValue ?? L10n.Common.noRating)")
    }
}

#Preview("Stats") {
    ScrollView {
        MatchStatsView(
            home: MockData.statistics.first,
            away: MockData.statistics.last,
            homeTeam: MockData.homeTeam,
            awayTeam: MockData.awayTeam,
            homePossession: 0.58
        )
        .padding(.vertical)
    }
    .background(Theme.Palette.background)
}
