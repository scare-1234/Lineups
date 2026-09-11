import XCTest
@testable import LineupLab

@MainActor
final class MatchListViewModelTests: XCTestCase {

    func testLoadGroupsFixturesByLeague() async {
        let viewModel = MatchListViewModel(service: PreviewFootballAPIService(), referenceDate: MockData.referenceDate)
        await viewModel.load()

        XCTAssertEqual(viewModel.fixtures.count, 3)
        XCTAssertEqual(viewModel.groups.count, 2)
        XCTAssertNil(viewModel.error)
        XCTAssertNil(viewModel.banner)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.liveCount, 1)
    }

    func testDateStripCoversTwoWeeks() {
        let viewModel = MatchListViewModel(service: PreviewFootballAPIService(), referenceDate: MockData.referenceDate)
        XCTAssertEqual(viewModel.dates.count, 15)
        XCTAssertEqual(viewModel.selectedDate, MockData.referenceDate.startOfDay())
    }

    func testLeagueFilterNarrowsTheList() async {
        let viewModel = MatchListViewModel(service: PreviewFootballAPIService(), referenceDate: MockData.referenceDate)
        await viewModel.load()

        viewModel.select(filter: .league(id: LeagueCatalog.premierLeague.id, name: "Premier League"))
        XCTAssertEqual(viewModel.groups.count, 1)
        XCTAssertEqual(viewModel.groups.first?.fixtures.count, 2)

        viewModel.select(filter: .international)
        XCTAssertEqual(viewModel.groups.count, 1)
        XCTAssertEqual(viewModel.groups.first?.league.id, LeagueCatalog.worldCup.id)

        viewModel.select(filter: .all)
        XCTAssertEqual(viewModel.groups.count, 2)
    }

    func testCachedResponseRaisesABanner() async {
        let service = PreviewFootballAPIService(
            behaviour: .success,
            source: .cache(storedAt: MockData.referenceDate, reason: .offline)
        )
        let viewModel = MatchListViewModel(service: service, referenceDate: MockData.referenceDate)
        await viewModel.load()

        XCTAssertEqual(viewModel.banner, .offline(storedAt: MockData.referenceDate))
    }

    func testFreshCacheDoesNotRaiseABanner() async {
        let service = PreviewFootballAPIService(
            behaviour: .success,
            source: .cache(storedAt: MockData.referenceDate, reason: .fresh)
        )
        let viewModel = MatchListViewModel(service: service, referenceDate: MockData.referenceDate)
        await viewModel.load()

        XCTAssertNil(viewModel.banner)
    }

    func testFailureWithoutCacheSurfacesAnError() async {
        let service = PreviewFootballAPIService(behaviour: .failure(.rateLimited))
        let viewModel = MatchListViewModel(service: service, referenceDate: MockData.referenceDate)
        await viewModel.load()

        XCTAssertEqual(viewModel.error, .rateLimited)
        XCTAssertTrue(viewModel.fixtures.isEmpty)
    }

    func testEmptyResponseShowsTheEmptyState() async {
        let service = PreviewFootballAPIService(behaviour: .empty)
        let viewModel = MatchListViewModel(service: service, referenceDate: MockData.referenceDate)
        await viewModel.load()

        XCTAssertTrue(viewModel.isEmpty)
        XCTAssertTrue(viewModel.groups.isEmpty)
    }

    func testMatchDetailMergesRatingsAndOrdersTeams() async {
        let viewModel = MatchDetailViewModel(fixture: MockData.liveFixture, service: PreviewFootballAPIService())
        await viewModel.load()

        XCTAssertEqual(viewModel.lineups.home?.team.id, MockData.homeTeam.id)
        XCTAssertEqual(viewModel.lineups.away?.team.id, MockData.awayTeam.id)
        XCTAssertEqual(viewModel.events.count, MockData.events.count)
        XCTAssertEqual(viewModel.statistics.count, 2)
        XCTAssertEqual(viewModel.homePossession, 0.58, accuracy: 0.01)
        XCTAssertTrue(viewModel.hasLoaded)
    }
}
