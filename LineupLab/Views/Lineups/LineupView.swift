import SwiftUI

/// Both teams' starting elevens on one pitch, followed by the substitutes.
struct LineupView: View {
    let lineups: MatchLineups
    let homeTeam: Team
    let awayTeam: Team
    var onSelectPlayer: (LineupPlayer) -> Void

    private let homeColor = Color.white
    private let awayColor = Color(hex: 0x90CAF9)

    var body: some View {
        VStack(spacing: Theme.Layout.sectionSpacing) {
            header
            pitch

            if let home = lineups.home {
                SubstitutesSection(lineup: home, tint: homeColor, onSelect: onSelectPlayer)
            }
            if let away = lineups.away {
                SubstitutesSection(lineup: away, tint: awayColor, onSelect: onSelectPlayer)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            teamColumn(team: homeTeam, lineup: lineups.home, alignment: .leading, tint: homeColor)
            Spacer(minLength: 8)
            Text("vs")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.secondaryText)
            Spacer(minLength: 8)
            teamColumn(team: awayTeam, lineup: lineups.away, alignment: .trailing, tint: awayColor)
        }
        .cardStyle()
        .padding(.horizontal)
    }

    private func teamColumn(
        team: Team,
        lineup: MatchLineup?,
        alignment: HorizontalAlignment,
        tint: Color
    ) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            HStack(spacing: 6) {
                if alignment == .leading { TeamLogoView(team: team, size: 22) }
                Text(team.name)
                    .font(Theme.Typography.bodyEmphasis)
                    .lineLimit(1)
                if alignment == .trailing { TeamLogoView(team: team, size: 22) }
            }
            Text(lineup?.formation.isEmpty == false ? (lineup?.formation ?? "") : L10n.Common.unknown)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
            if let average = lineup?.averageRating {
                Text("\(L10n.Builder.teamAverageRating) \(RatingScale.text(for: average))")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    private var pitch: some View {
        PitchView(aspectRatio: 0.62) { size in
            if let home = lineups.home {
                markers(for: home, orientation: .bottomHalf, tint: homeColor, size: size)
            }
            if let away = lineups.away {
                markers(for: away, orientation: .topHalf, tint: awayColor, size: size)
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func markers(
        for lineup: MatchLineup,
        orientation: PitchOrientation,
        tint: Color,
        size: CGSize
    ) -> some View {
        let points = lineup.startingPoints
        ForEach(Array(lineup.startXI.enumerated()), id: \.element.id) { index, player in
            Button {
                onSelectPlayer(player)
            } label: {
                PitchPlayerMarker(
                    number: player.number,
                    name: player.player.name,
                    rating: player.rating,
                    accent: tint,
                    diameter: 30
                )
            }
            .buttonStyle(.plain)
            .position(orientation.screenPoint(
                for: points.indices.contains(index) ? points[index] : CGPoint(x: 0.5, y: 0.5),
                in: size
            ))
        }
    }
}

/// Substitutes for one team, with their ratings when they played.
struct SubstitutesSection: View {
    let lineup: MatchLineup
    var tint: Color = .white
    var onSelect: (LineupPlayer) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Layout.rowSpacing) {
            HStack(spacing: 8) {
                TeamLogoView(team: lineup.team, size: 20)
                Text(lineup.team.name)
                    .font(Theme.Typography.sectionTitle)
                Spacer()
                Text(L10n.MatchDetail.substitutes)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.secondaryText)
            }

            if lineup.substitutes.isEmpty {
                Text(L10n.Common.none)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.secondaryText)
            } else {
                ForEach(lineup.substitutes) { player in
                    Button {
                        onSelect(player)
                    } label: {
                        PlayerCardView(lineupPlayer: player)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let coach = lineup.coachName, coach.isEmpty == false {
                Divider().overlay(Theme.Palette.separator)
                HStack {
                    Text(L10n.MatchDetail.coach)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.secondaryText)
                    Spacer()
                    Text(coach).font(Theme.Typography.caption)
                }
            }
        }
        .cardStyle()
        .padding(.horizontal)
    }
}

#Preview("Lineups") {
    ScrollView {
        LineupView(
            lineups: MockData.matchLineups,
            homeTeam: MockData.homeTeam,
            awayTeam: MockData.awayTeam,
            onSelectPlayer: { _ in }
        )
        .padding(.vertical)
    }
    .background(Theme.Palette.background)
}
