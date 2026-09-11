import Foundation
import Observation

enum MatchDetailTab: String, CaseIterable, Identifiable, Sendable {
    case lineups
    case stats
    case events
    case info

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lineups: L10n.MatchDetail.lineups
        case .stats: L10n.MatchDetail.stats
        case .events: L10n.MatchDetail.events
        case .info: L10n.MatchDetail.info
        }
    }
}

@MainActor
@Observable
final class MatchDetailViewModel {

    private let service: FootballAPIServicing

    let fixture: Fixture

    var selectedTab: MatchDetailTab = .lineups

    private(set) var lineups = MatchLineups(home: nil, away: nil)
    private(set) var events: [MatchEvent] = []
    private(set) var statistics: [TeamMatchStatistics] = []
    private(set) var isLoading = false
    private(set) var error: APIError?
    private(set) var banner: DataBanner?
    private(set) var hasLoaded = false

    init(fixture: Fixture, service: FootballAPIServicing) {
        self.fixture = fixture
        self.service = service
    }

    var homeStatistics: TeamMatchStatistics? {
        statistics.first { $0.teamId == fixture.homeTeam.id }
    }

    var awayStatistics: TeamMatchStatistics? {
        statistics.first { $0.teamId == fixture.awayTeam.id }
    }

    /// Home possession as a fraction, defaulting to an even split.
    var homePossession: Double {
        let home = Double(homeStatistics?.intValue(for: .possession) ?? 50)
        let away = Double(awayStatistics?.intValue(for: .possession) ?? 50)
        let total = home + away
        guard total > 0 else { return 0.5 }
        return home / total
    }

    var lineupsUnavailableMessage: String? {
        guard lineups.isEmpty else { return nil }
        return fixture.lineupsLikelyAvailable ? L10n.MatchDetail.noStats : L10n.MatchDetail.lineupsPending
    }

    func loadIfNeeded() async {
        guard hasLoaded == false else { return }
        await load()
    }

    func load() async {
        isLoading = true
        error = nil

        let fixtureID = fixture.id
        let service = self.service
        async let lineupsTask = service.lineups(fixtureID: fixtureID)
        async let statsTask = service.playerMatchStats(fixtureID: fixtureID)
        async let eventsTask = service.events(fixtureID: fixtureID)
        async let statisticsTask = service.statistics(fixtureID: fixtureID)

        var banners: [DataBanner] = []
        var failures: [APIError] = []

        do {
            let lineupsResponse = try await lineupsTask
            let statsResponse = try? await statsTask
            let merged = FootballAPIService.merge(
                lineups: lineupsResponse.value,
                stats: statsResponse?.value ?? [:]
            )
            lineups = orderedByFixture(merged)
            if let banner = DataBanner(source: lineupsResponse.source) { banners.append(banner) }
        } catch {
            failures.append(APIError.wrap(error))
            _ = try? await statsTask
        }

        do {
            let response = try await eventsTask
            events = response.value
            if let banner = DataBanner(source: response.source) { banners.append(banner) }
        } catch {
            failures.append(APIError.wrap(error))
        }

        do {
            let response = try await statisticsTask
            statistics = response.value
            if let banner = DataBanner(source: response.source) { banners.append(banner) }
        } catch {
            failures.append(APIError.wrap(error))
        }

        banner = banners.first
        // Only surface an error when nothing at all could be loaded.
        if lineups.isEmpty, events.isEmpty, statistics.isEmpty, let first = failures.first {
            error = first
        }
        isLoading = false
        hasLoaded = true
    }

    func refresh() async {
        hasLoaded = false
        await load()
    }

    func events(for teamId: Int) -> [MatchEvent] {
        events.filter { $0.teamId == teamId }
    }

    /// The API returns the two lineups in kick-off order; make sure they line up with
    /// the fixture's home and away teams anyway.
    private func orderedByFixture(_ value: MatchLineups) -> MatchLineups {
        let all = [value.home, value.away].compactMap { $0 }
        let home = all.first { $0.team.id == fixture.homeTeam.id }
        let away = all.first { $0.team.id == fixture.awayTeam.id }
        if home == nil, away == nil { return value }
        return MatchLineups(home: home ?? value.home, away: away ?? value.away)
    }
}
