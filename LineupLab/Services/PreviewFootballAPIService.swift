import Foundation

/// In-memory implementation of `FootballAPIServicing` used by SwiftUI previews and tests.
/// It can also be told to fail, so error states are as easy to preview as happy paths.
struct PreviewFootballAPIService: FootballAPIServicing {

    enum Behaviour: Sendable {
        case success
        case failure(APIError)
        case empty
    }

    var behaviour: Behaviour = .success
    var source: DataSource = .network
    var delay: Duration = .zero

    init(behaviour: Behaviour = .success, source: DataSource = .network, delay: Duration = .zero) {
        self.behaviour = behaviour
        self.source = source
        self.delay = delay
    }

    private func respond<T: Sendable>(_ value: T, empty: T) async throws -> APIResponse<T> {
        if delay > .zero {
            try? await Task.sleep(for: delay)
        }
        switch behaviour {
        case .success: return APIResponse(value: value, source: source)
        case .empty: return APIResponse(value: empty, source: source)
        case .failure(let error): throw error
        }
    }

    func fixtures(on date: Date, leagueID: Int?) async throws -> APIResponse<[Fixture]> {
        try await respond(MockData.fixtures, empty: [])
    }

    func fixture(id: Int) async throws -> APIResponse<Fixture> {
        try await respond(MockData.liveFixture, empty: MockData.liveFixture)
    }

    func lineups(fixtureID: Int) async throws -> APIResponse<MatchLineups> {
        try await respond(MockData.matchLineups, empty: MatchLineups(home: nil, away: nil))
    }

    func playerMatchStats(fixtureID: Int) async throws -> APIResponse<[Int: PlayerMatchStats]> {
        try await respond([:], empty: [:])
    }

    func events(fixtureID: Int) async throws -> APIResponse<[MatchEvent]> {
        try await respond(MockData.events, empty: [])
    }

    func statistics(fixtureID: Int) async throws -> APIResponse<[TeamMatchStatistics]> {
        try await respond(MockData.statistics, empty: [])
    }

    func player(id: Int, season: Int?) async throws -> APIResponse<Player> {
        try await respond(MockData.featuredPlayer, empty: MockData.featuredPlayer)
    }

    func searchPlayers(named name: String, season: Int?) async throws -> APIResponse<[Player]> {
        let matches = MockData.searchResults.filter {
            name.count < AppConstants.minimumSearchLength || $0.name.localizedCaseInsensitiveContains(name)
        }
        return try await respond(matches, empty: [])
    }

    func league(id: Int, season: Int?) async throws -> APIResponse<League> {
        try await respond(MockData.premierLeague, empty: MockData.premierLeague)
    }

    func standings(leagueID: Int, season: Int?) async throws -> APIResponse<[StandingRow]> {
        try await respond(MockData.standings, empty: [])
    }

    func nationalTeams(country: String) async throws -> APIResponse<[Team]> {
        try await respond([MockData.brazil, MockData.france], empty: [])
    }

    func squad(teamID: Int) async throws -> APIResponse<[Player]> {
        try await respond(MockData.squad, empty: [])
    }

    func recentFixtures(leagueID: Int, season: Int?, last: Int) async throws -> APIResponse<[Fixture]> {
        try await respond(MockData.fixtures, empty: [])
    }
}

extension AppContainer {
    /// Container wired to preview data and an in-memory Core Data store.
    @MainActor
    static func preview(
        behaviour: PreviewFootballAPIService.Behaviour = .success,
        configurationError: ConfigurationError? = nil
    ) -> AppContainer {
        AppContainer(
            service: PreviewFootballAPIService(behaviour: behaviour),
            store: CustomLineupStore(stack: CoreDataStack(inMemory: true)),
            season: 2026,
            configurationError: configurationError
        )
    }
}
