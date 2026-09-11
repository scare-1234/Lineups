import SwiftUI

/// Tab 3: international football — competitions, recent internationals and national squads.
struct InternationalView: View {

    @Environment(AppContainer.self) private var container
    @State private var viewModel: InternationalViewModel

    init(service: FootballAPIServicing) {
        _viewModel = State(initialValue: InternationalViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Layout.sectionSpacing) {
                    competitionStrip

                    if let banner = viewModel.banner {
                        DataBannerView(banner: banner)
                    }

                    matchesSection
                    squadSection
                }
                .padding(.vertical, 12)
            }
            .background(Theme.Palette.background)
            .navigationTitle(L10n.International.title)
            .refreshable { await viewModel.refresh() }
            .navigationDestination(for: Fixture.self) { fixture in
                MatchDetailView(fixture: fixture, service: container.service)
            }
            .task { await viewModel.loadIfNeeded() }
        }
    }

    private var competitionStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.International.competitions)
                .font(Theme.Typography.sectionTitle)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.competitions) { competition in
                        FilterChip(
                            title: competition.name,
                            isSelected: competition.id == viewModel.selectedCompetition.id,
                            systemImage: "globe"
                        ) {
                            Haptics.selection()
                            Task { await viewModel.select(competition: competition) }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private var matchesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Layout.rowSpacing) {
            Text(L10n.International.recentMatches)
                .font(Theme.Typography.sectionTitle)
                .padding(.horizontal)

            if viewModel.isLoadingFixtures {
                LoadingView(rows: 3)
            } else if let error = viewModel.error, viewModel.fixtures.isEmpty {
                ErrorStateView(error: error) {
                    Task { await viewModel.loadFixtures() }
                }
            } else if viewModel.fixtures.isEmpty {
                EmptyStateView(
                    title: L10n.Matches.emptyTitle,
                    message: L10n.Matches.emptyMessage,
                    systemImage: "globe.europe.africa"
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.fixtures) { fixture in
                        NavigationLink(value: fixture) {
                            FixtureRowView(fixture: fixture)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var squadSection: some View {
        VStack(alignment: .leading, spacing: Theme.Layout.rowSpacing) {
            Text(L10n.International.squads)
                .font(Theme.Typography.sectionTitle)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.filteredCountries, id: \.self) { country in
                        FilterChip(
                            title: NationalityFlag.label(for: country),
                            isSelected: country == viewModel.selectedCountry
                        ) {
                            Haptics.selection()
                            Task { await viewModel.selectCountry(country) }
                        }
                    }
                }
                .padding(.horizontal)
            }

            if viewModel.isLoadingSquad {
                LoadingView(rows: 4)
            } else if viewModel.selectedCountry == nil {
                Text(L10n.International.selectCountry)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.secondaryText)
                    .padding(.horizontal)
            } else if viewModel.squad.isEmpty {
                Text(L10n.International.noSquad)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.secondaryText)
                    .padding(.horizontal)
            } else {
                SquadListView(
                    team: viewModel.selectedTeam,
                    players: viewModel.squad,
                    averageRating: viewModel.squadAverageRating
                )
            }
        }
    }
}

/// National team squad with ages, clubs and ratings.
struct SquadListView: View {

    @Environment(AppContainer.self) private var container
    let team: Team?
    let players: [Player]
    let averageRating: Double?

    @State private var playerSheet: PlayerSheetTarget?

    var body: some View {
        VStack(spacing: Theme.Layout.rowSpacing) {
            if let team {
                HStack(spacing: 10) {
                    TeamLogoView(team: team, size: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(team.name).font(Theme.Typography.bodyEmphasis)
                        Text(NationalityFlag.label(for: team.country))
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.secondaryText)
                    }
                    Spacer()
                    RatingBadge(rating: averageRating)
                }
                .cardStyle()
            }

            VStack(spacing: 10) {
                ForEach(players) { player in
                    Button {
                        playerSheet = PlayerSheetTarget(id: player.id, player: player, matchStats: nil)
                    } label: {
                        PlayerCardView(player: player)
                    }
                    .buttonStyle(.plain)
                }
            }
            .cardStyle()
        }
        .padding(.horizontal)
        .sheet(item: $playerSheet) { target in
            PlayerDetailView(player: target.player, service: container.service, store: container.store)
        }
    }
}

#Preview("International") {
    InternationalView(service: PreviewFootballAPIService())
        .environment(AppContainer.preview())
}
