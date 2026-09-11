import Foundation
import Observation

/// Which tab is showing. Kept in the container so "Add to Custom Lineup"
/// can jump from a player sheet straight into the builder.
enum AppTab: Hashable, Sendable {
    case matches
    case builder
    case international
}

/// Composition root: builds the API stack once and hands it to the views.
/// ViewModels receive `FootballAPIServicing`, never a concrete type.
@MainActor
@Observable
final class AppContainer {

    let service: FootballAPIServicing
    let store: CustomLineupStore
    let configurationError: ConfigurationError?
    let season: Int

    /// Player waiting to be dropped into the builder, set by the player detail sheet.
    var pendingBuilderPlayer: Player?
    var selectedTab: AppTab = .matches

    init(
        service: FootballAPIServicing,
        store: CustomLineupStore,
        season: Int,
        configurationError: ConfigurationError? = nil
    ) {
        self.service = service
        self.store = store
        self.season = season
        self.configurationError = configurationError
    }

    var isConfigured: Bool { configurationError == nil }

    static func live() -> AppContainer {
        let store = CustomLineupStore()
        switch AppConfig.load() {
        case .success(let config):
            let client = APIClient(config: config)
            return AppContainer(
                service: FootballAPIService(client: client, defaultSeason: config.season),
                store: store,
                season: config.season
            )
        case .failure(let error):
            return AppContainer(
                service: UnconfiguredAPIService(error: error),
                store: store,
                season: AppConfig.currentSeason(),
                configurationError: error
            )
        }
    }

    /// Sends the user to the builder with a player ready to place.
    func startBuilding(with player: Player) {
        pendingBuilderPlayer = player
        selectedTab = .builder
    }
}

/// Stand-in used when `Configuration.plist` has no usable API key: every call fails
/// with the configuration error so the UI can show setup instructions.
struct UnconfiguredAPIService: FootballAPIServicing {
    let error: ConfigurationError

    private var failure: APIError { .configuration(error) }

    func fixtures(on date: Date, leagueID: Int?) async throws -> APIResponse<[Fixture]> { throw failure }
    func fixture(id: Int) async throws -> APIResponse<Fixture> { throw failure }
    func lineups(fixtureID: Int) async throws -> APIResponse<MatchLineups> { throw failure }
    func playerMatchStats(fixtureID: Int) async throws -> APIResponse<[Int: PlayerMatchStats]> { throw failure }
    func events(fixtureID: Int) async throws -> APIResponse<[MatchEvent]> { throw failure }
    func statistics(fixtureID: Int) async throws -> APIResponse<[TeamMatchStatistics]> { throw failure }
    func player(id: Int, season: Int?) async throws -> APIResponse<Player> { throw failure }
    func searchPlayers(named name: String, season: Int?) async throws -> APIResponse<[Player]> { throw failure }
    func league(id: Int, season: Int?) async throws -> APIResponse<League> { throw failure }
    func standings(leagueID: Int, season: Int?) async throws -> APIResponse<[StandingRow]> { throw failure }
    func nationalTeams(country: String) async throws -> APIResponse<[Team]> { throw failure }
    func squad(teamID: Int) async throws -> APIResponse<[Player]> { throw failure }
    func recentFixtures(leagueID: Int, season: Int?, last: Int) async throws -> APIResponse<[Fixture]> { throw failure }
}
