import SwiftUI

/// Target for the player detail sheet.
struct PlayerSheetTarget: Identifiable, Hashable {
    let id: Int
    let player: Player
    let matchStats: PlayerMatchStats?
}

/// Match detail with Lineups (default), Stats, Events and Info.
struct MatchDetailView: View {

    @Environment(AppContainer.self) private var container
    @State private var viewModel: MatchDetailViewModel
    @State private var playerSheet: PlayerSheetTarget?

    init(fixture: Fixture, service: FootballAPIServicing) {
        _viewModel = State(initialValue: MatchDetailViewModel(fixture: fixture, service: service))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Layout.sectionSpacing) {
                MatchHeaderView(fixture: viewModel.fixture)

                Picker(L10n.MatchDetail.lineups, selection: Bindable(viewModel).selectedTab) {
                    ForEach(MatchDetailTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if let banner = viewModel.banner {
                    DataBannerView(banner: banner)
                }

                tabContent
            }
            .padding(.vertical, 12)
        }
        .background(Theme.Palette.background)
        .navigationTitle(viewModel.fixture.league.name)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.refresh() }
        .task { await viewModel.loadIfNeeded() }
        .sheet(item: $playerSheet) { target in
            PlayerDetailView(
                player: target.player,
                matchStats: target.matchStats,
                service: container.service
            )
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        if viewModel.isLoading, viewModel.lineups.isEmpty, viewModel.events.isEmpty {
            LoadingPitchView()
        } else if let error = viewModel.error {
            ErrorStateView(error: error) {
                Task { await viewModel.load() }
            }
            .padding(.top, 32)
        } else {
            switch viewModel.selectedTab {
            case .lineups: lineupsTab
            case .stats: statsTab
            case .events: eventsTab
            case .info: MatchInfoView(fixture: viewModel.fixture)
            }
        }
    }

    @ViewBuilder
    private var lineupsTab: some View {
        if viewModel.lineups.isEmpty {
            EmptyStateView(
                title: L10n.MatchDetail.lineups,
                message: viewModel.fixture.lineupsLikelyAvailable
                    ? L10n.MatchDetail.noStats
                    : L10n.MatchDetail.lineupsPending,
                systemImage: "person.3.sequence"
            )
            .padding(.top, 24)
        } else {
            LineupView(
                lineups: viewModel.lineups,
                homeTeam: viewModel.fixture.homeTeam,
                awayTeam: viewModel.fixture.awayTeam,
                onSelectPlayer: { lineupPlayer in
                    Haptics.impact(.light)
                    playerSheet = PlayerSheetTarget(
                        id: lineupPlayer.player.id,
                        player: lineupPlayer.player,
                        matchStats: lineupPlayer.matchStats
                    )
                }
            )
        }
    }

    @ViewBuilder
    private var statsTab: some View {
        if viewModel.statistics.isEmpty {
            EmptyStateView(
                title: L10n.MatchDetail.stats,
                message: L10n.MatchDetail.noStats,
                systemImage: "chart.bar.xaxis"
            )
            .padding(.top, 24)
        } else {
            MatchStatsView(
                home: viewModel.homeStatistics,
                away: viewModel.awayStatistics,
                homeTeam: viewModel.fixture.homeTeam,
                awayTeam: viewModel.fixture.awayTeam,
                homePossession: viewModel.homePossession
            )
        }
    }

    @ViewBuilder
    private var eventsTab: some View {
        if viewModel.events.isEmpty {
            EmptyStateView(
                title: L10n.MatchDetail.events,
                message: L10n.MatchDetail.noEvents,
                systemImage: "clock.arrow.circlepath"
            )
            .padding(.top, 24)
        } else {
            MatchEventsView(events: viewModel.events, homeTeamID: viewModel.fixture.homeTeam.id)
        }
    }
}

/// Score header shared by every tab.
struct MatchHeaderView: View {
    let fixture: Fixture

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top) {
                teamBlock(fixture.homeTeam)
                VStack(spacing: 6) {
                    Text(fixture.hasScore ? fixture.scoreLine : fixture.date.kickoffString)
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                    StatusBadge(fixture: fixture)
                    Text(fixture.date.fullDateTimeString)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.secondaryText)
                        .multilineTextAlignment(.center)
                }
                teamBlock(fixture.awayTeam)
            }
        }
        .cardStyle()
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }

    private func teamBlock(_ team: Team) -> some View {
        VStack(spacing: 6) {
            TeamLogoView(team: team, size: 46)
            Text(team.name)
                .font(Theme.Typography.callout)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Match detail") {
    NavigationStack {
        MatchDetailView(fixture: MockData.liveFixture, service: PreviewFootballAPIService())
    }
    .environment(AppContainer.preview())
}
