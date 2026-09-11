import SwiftUI

/// Player detail sheet: photo, nationality, age, position, ratings and season stats.
struct PlayerDetailView: View {

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PlayerDetailViewModel

    init(player: Player, matchStats: PlayerMatchStats? = nil, service: FootballAPIServicing, store: CustomLineupStore? = nil) {
        _viewModel = State(initialValue: PlayerDetailViewModel(
            player: player,
            matchStats: matchStats,
            service: service,
            store: store
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Layout.sectionSpacing) {
                    if let banner = viewModel.banner {
                        DataBannerView(banner: banner)
                    }
                    profileCard
                    attributesCard
                    if let stats = viewModel.seasonStats {
                        seasonStatsCard(stats)
                    }
                    if let match = viewModel.matchStats {
                        MatchStatsGrid(stats: match)
                    }
                    addToLineupButton
                }
                .padding(.vertical, 12)
            }
            .background(Theme.Palette.background)
            .navigationTitle(L10n.Player.detailsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.close) { dismiss() }
                }
            }
            .task { await viewModel.load() }
        }
    }

    private var profileCard: some View {
        VStack(spacing: 10) {
            PlayerAvatarView(
                url: viewModel.player.photo,
                initials: viewModel.player.initials,
                size: Theme.Layout.largeAvatarSize
            )

            Text(viewModel.player.fullName)
                .font(Theme.Typography.title)
                .multilineTextAlignment(.center)

            Text(NationalityFlag.label(for: viewModel.player.nationality))
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Palette.primaryText)

            HStack(spacing: 10) {
                Text(viewModel.player.ageLabel)
                Text("·")
                Text(viewModel.player.positionLabel)
            }
            .font(Theme.Typography.callout)
            .foregroundStyle(Theme.Palette.secondaryText)

            RatingHeadline(rating: viewModel.headlineRating)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
        .padding(.horizontal)
    }

    private var attributesCard: some View {
        VStack(spacing: 10) {
            attributeRow(L10n.Player.club, viewModel.player.clubTeam)
            attributeRow(L10n.Player.height, viewModel.player.height)
            attributeRow(L10n.Player.weight, viewModel.player.weight)
            attributeRow(L10n.Player.born, bornText)
        }
        .cardStyle()
        .padding(.horizontal)
    }

    private var bornText: String? {
        let date = viewModel.player.birthDate.map { DateFormatter.birthDate.string(from: $0) }
        let place = [viewModel.player.birthPlace, viewModel.player.birthCountry]
            .compactMap { $0 }
            .filter { $0.isEmpty == false }
            .joined(separator: ", ")
        let parts = [date, place.isEmpty ? nil : place].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func attributeRow(_ title: String, _ value: String?) -> some View {
        HStack {
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.secondaryText)
            Spacer(minLength: 12)
            Text(value?.isEmpty == false ? (value ?? "") : L10n.Common.noRating)
                .font(Theme.Typography.body)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private func seasonStatsCard(_ stats: PlayerSeasonStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.Player.seasonStats).font(Theme.Typography.sectionTitle)
                Spacer()
                if let league = stats.leagueName {
                    Text(league)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.secondaryText)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 12) {
                StatTile(title: L10n.Player.appearances, value: stats.appearances.map(String.init))
                StatTile(title: L10n.Player.goals, value: stats.goals.map(String.init))
                StatTile(title: L10n.Player.assists, value: stats.assists.map(String.init))
                StatTile(title: L10n.Player.minutes, value: stats.minutes.map(String.init))
                StatTile(title: L10n.Player.averageRating, value: RatingScale.text(for: stats.rating))
                StatTile(title: L10n.Player.position, value: PitchRole(apiValue: stats.position)?.abbreviation)
            }
        }
        .cardStyle()
        .padding(.horizontal)
    }

    private var addToLineupButton: some View {
        Button {
            container.startBuilding(with: viewModel.player)
            Haptics.impact(.medium)
            dismiss()
        } label: {
            Label(L10n.Player.addToLineup, systemImage: "plus.circle.fill")
                .font(Theme.Typography.bodyEmphasis)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.Palette.accent)
        .foregroundStyle(Color.black)
        .padding(.horizontal)
    }
}

/// Small labelled stat used on the player sheet.
struct StatTile: View {
    let title: String
    let value: String?

    var body: some View {
        VStack(spacing: 4) {
            Text(value?.isEmpty == false ? (value ?? "") : L10n.Common.noRating)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Palette.primaryText)
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.Palette.cardElevated, in: RoundedRectangle(cornerRadius: Theme.Layout.smallCornerRadius))
        .accessibilityElement(children: .combine)
    }
}

/// Per-match statistics from the fixtures/players endpoint.
struct MatchStatsGrid: View {
    let stats: PlayerMatchStats

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Player.matchStats).font(Theme.Typography.sectionTitle)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 12) {
                StatTile(title: L10n.Player.minutes, value: stats.minutes.map(String.init))
                StatTile(title: L10n.Player.goals, value: stats.goals.map(String.init))
                StatTile(title: L10n.Player.assists, value: stats.assists.map(String.init))
                StatTile(title: String(localized: "Shots", comment: "Match statistic"), value: shotsText)
                StatTile(title: String(localized: "Passes", comment: "Match statistic"), value: passesText)
                StatTile(title: String(localized: "Duels", comment: "Match statistic"), value: duelsText)
                StatTile(title: String(localized: "Dribbles", comment: "Match statistic"), value: dribblesText)
                StatTile(title: String(localized: "Tackles", comment: "Match statistic"), value: stats.tacklesTotal.map(String.init))
                StatTile(title: String(localized: "Fouls", comment: "Match statistic"), value: stats.foulsCommitted.map(String.init))
            }
        }
        .cardStyle()
        .padding(.horizontal)
    }

    private var shotsText: String? {
        guard let total = stats.shotsTotal else { return nil }
        return "\(total)/\(stats.shotsOn ?? 0)"
    }

    private var passesText: String? {
        guard let total = stats.passesTotal else { return nil }
        guard let accuracy = stats.passAccuracy else { return String(total) }
        return "\(total) · \(accuracy)%"
    }

    private var duelsText: String? {
        guard let total = stats.duelsTotal else { return nil }
        return "\(stats.duelsWon ?? 0)/\(total)"
    }

    private var dribblesText: String? {
        guard let attempts = stats.dribbleAttempts else { return nil }
        return "\(stats.dribbleSuccess ?? 0)/\(attempts)"
    }
}

#Preview("Player detail") {
    PlayerDetailView(
        player: MockData.featuredPlayer,
        matchStats: MockData.homeLineup.startXI.first?.matchStats,
        service: PreviewFootballAPIService()
    )
    .environment(AppContainer.preview())
}
