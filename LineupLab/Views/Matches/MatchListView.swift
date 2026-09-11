import SwiftUI

/// Tab 1: fixtures for a day, grouped by league, with a date strip and league filters.
struct MatchListView: View {

    @Environment(AppContainer.self) private var container
    @State private var viewModel: MatchListViewModel

    init(service: FootballAPIServicing, store: CustomLineupStore?) {
        _viewModel = State(initialValue: MatchListViewModel(service: service, store: store))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: Theme.Layout.sectionSpacing, pinnedViews: []) {
                    DateStripView(
                        dates: viewModel.dates,
                        selected: viewModel.selectedDate,
                        onSelect: { date in
                            Task { await viewModel.select(date: date) }
                        }
                    )

                    LeagueFilterStrip(
                        selected: viewModel.filter,
                        onSelect: { filter in
                            Haptics.selection()
                            viewModel.select(filter: filter)
                        }
                    )

                    if let banner = viewModel.banner {
                        DataBannerView(banner: banner)
                    }

                    content
                }
                .padding(.vertical, 12)
            }
            .background(Theme.Palette.background)
            .navigationTitle(L10n.App.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image(systemName: "soccerball")
                        .foregroundStyle(Theme.Palette.accent)
                        .accessibilityHidden(true)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.liveCount > 0 {
                        LiveIndicator()
                    }
                }
            }
            .refreshable { await viewModel.refresh() }
            .navigationDestination(for: Fixture.self) { fixture in
                MatchDetailView(fixture: fixture, service: container.service)
            }
            .task { await viewModel.loadIfNeeded() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading, viewModel.groups.isEmpty {
            LoadingView()
        } else if let error = viewModel.error {
            ErrorStateView(error: error) {
                Task { await viewModel.load() }
            }
            .padding(.top, 40)
        } else if viewModel.isEmpty {
            EmptyStateView(
                title: L10n.Matches.emptyTitle,
                message: L10n.Matches.emptyMessage,
                systemImage: "calendar.badge.exclamationmark"
            )
            .padding(.top, 40)
        } else {
            ForEach(viewModel.groups) { group in
                LeagueSectionView(group: group)
            }
        }
    }
}

/// Horizontally scrollable strip of the last and next seven days.
struct DateStripView: View {
    let dates: [Date]
    let selected: Date
    let onSelect: (Date) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(dates, id: \.self) { date in
                        let isSelected = Calendar.current.isDate(date, inSameDayAs: selected)
                        Button {
                            onSelect(date)
                        } label: {
                            VStack(spacing: 2) {
                                Text(date.dayStripLabel())
                                    .font(.system(size: 12, weight: .semibold))
                                Text(DateFormatter.monthDay.string(from: date))
                                    .font(.system(size: 11))
                                    .foregroundStyle(isSelected ? Color.black.opacity(0.7) : Theme.Palette.secondaryText)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(minWidth: 74)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Layout.smallCornerRadius)
                                    .fill(isSelected ? Theme.Palette.accent : Theme.Palette.card)
                            )
                            .foregroundStyle(isSelected ? Color.black : Theme.Palette.primaryText)
                        }
                        .buttonStyle(.plain)
                        .id(date)
                        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                    }
                }
                .padding(.horizontal)
            }
            .onAppear {
                proxy.scrollTo(selected, anchor: .center)
            }
        }
    }
}

/// League filter chips.
struct LeagueFilterStrip: View {
    let selected: LeagueFilter
    let onSelect: (LeagueFilter) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LeagueFilter.chips) { filter in
                    FilterChip(title: filter.title, isSelected: filter == selected) {
                        onSelect(filter)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

/// One league's fixtures.
struct LeagueSectionView: View {
    let group: FixtureGroup

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Layout.rowSpacing) {
            HStack(spacing: 8) {
                if let logo = group.league.logo {
                    AsyncImage(url: logo) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Image(systemName: "flag.checkered")
                            .foregroundStyle(Theme.Palette.secondaryText)
                    }
                    .frame(width: 20, height: 20)
                }
                Text(group.league.name)
                    .font(Theme.Typography.sectionTitle)
                Text(group.league.country)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.secondaryText)
                Spacer()
            }
            .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(group.fixtures) { fixture in
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

/// A single fixture row: teams, score or kick-off time, status and venue.
struct FixtureRowView: View {
    let fixture: Fixture

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                teamView(fixture.homeTeam, alignment: .leading)

                VStack(spacing: 3) {
                    Text(fixture.hasScore ? fixture.scoreLine : fixture.date.kickoffString)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Palette.primaryText)
                    StatusBadge(fixture: fixture)
                }
                .frame(width: 88)

                teamView(fixture.awayTeam, alignment: .trailing)
            }

            HStack(spacing: 4) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 9))
                Text(fixture.venue ?? L10n.Matches.venueUnknown)
                    .lineLimit(1)
                Spacer()
                if fixture.kind == .postponed || fixture.kind == .cancelled {
                    Text(fixture.statusDescription ?? fixture.status)
                        .foregroundStyle(Theme.Palette.warning)
                }
            }
            .font(Theme.Typography.caption)
            .foregroundStyle(Theme.Palette.secondaryText)
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
    }

    private func teamView(_ team: Team, alignment: HorizontalAlignment) -> some View {
        HStack(spacing: 8) {
            if alignment == .leading { TeamLogoView(team: team) }
            Text(team.name)
                .font(Theme.Typography.body)
                .lineLimit(2)
                .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
            if alignment == .trailing { TeamLogoView(team: team) }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }
}

#Preview("Match list") {
    MatchListView(service: PreviewFootballAPIService(), store: nil)
        .environment(AppContainer.preview())
}

#Preview("Match list — rate limited") {
    MatchListView(service: PreviewFootballAPIService(behaviour: .failure(.rateLimited)), store: nil)
        .environment(AppContainer.preview())
}
