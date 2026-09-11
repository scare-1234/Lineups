import SwiftUI

/// Info tab: referee, venue, round and status.
struct MatchInfoView: View {
    let fixture: Fixture

    private var rows: [(String, String)] {
        var rows: [(String, String)] = []
        if let referee = fixture.referee, referee.isEmpty == false {
            rows.append((L10n.MatchDetail.referee, referee))
        }
        if let venue = fixture.venue, venue.isEmpty == false {
            rows.append((L10n.MatchDetail.venue, venue))
        }
        if let city = fixture.venueCity, city.isEmpty == false {
            rows.append((L10n.MatchDetail.city, city))
        }
        if let round = fixture.league.round, round.isEmpty == false {
            rows.append((L10n.MatchDetail.round, round))
        }
        if fixture.league.season > 0 {
            rows.append((L10n.MatchDetail.season, String(fixture.league.season)))
        }
        rows.append((L10n.MatchDetail.status, fixture.statusDescription ?? fixture.status))
        return rows
    }

    var body: some View {
        VStack(spacing: Theme.Layout.sectionSpacing) {
            if rows.isEmpty {
                EmptyStateView(
                    title: L10n.MatchDetail.info,
                    message: L10n.MatchDetail.noInfo,
                    systemImage: "info.circle"
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        HStack(alignment: .top) {
                            Text(row.0)
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Palette.secondaryText)
                            Spacer(minLength: 12)
                            Text(row.1)
                                .font(Theme.Typography.body)
                                .multilineTextAlignment(.trailing)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .cardStyle()
                .padding(.horizontal)

                LeagueInfoCard(league: fixture.league)
            }
        }
    }
}

struct LeagueInfoCard: View {
    let league: League

    var body: some View {
        HStack(spacing: 12) {
            if let logo = league.logo {
                AsyncImage(url: logo) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Image(systemName: "trophy")
                        .foregroundStyle(Theme.Palette.secondaryText)
                }
                .frame(width: 34, height: 34)
            } else {
                Image(systemName: "trophy")
                    .font(.title3)
                    .foregroundStyle(Theme.Palette.secondaryText)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(league.name).font(Theme.Typography.bodyEmphasis)
                Text(NationalityFlag.label(for: league.country))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.secondaryText)
            }
            Spacer()
            Text(league.type)
                .font(Theme.Typography.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Theme.Palette.cardElevated))
        }
        .cardStyle()
        .padding(.horizontal)
    }
}

#Preview("Info") {
    ScrollView {
        MatchInfoView(fixture: MockData.liveFixture)
            .padding(.vertical)
    }
    .background(Theme.Palette.background)
}
