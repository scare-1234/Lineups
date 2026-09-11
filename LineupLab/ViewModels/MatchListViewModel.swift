import Foundation
import Observation

/// League filter chips on the match list.
enum LeagueFilter: Hashable, Identifiable, Sendable {
    case all
    case league(id: Int, name: String)
    case international

    var id: String {
        switch self {
        case .all: "all"
        case .league(let id, _): "league-\(id)"
        case .international: "international"
        }
    }

    var title: String {
        switch self {
        case .all: L10n.Common.all
        case .league(_, let name): name
        case .international: L10n.International.title
        }
    }

    func matches(_ fixture: Fixture) -> Bool {
        switch self {
        case .all: true
        case .league(let id, _): fixture.league.id == id
        case .international: fixture.league.isInternational
        }
    }

    static var chips: [LeagueFilter] {
        var chips: [LeagueFilter] = [.all]
        chips += LeagueCatalog.clubFilters.map { .league(id: $0.id, name: $0.name) }
        chips.append(.league(id: LeagueCatalog.worldCup.id, name: LeagueCatalog.worldCup.name))
        chips.append(.international)
        return chips
    }
}

/// Fixtures for one league, as shown in a section of the match list.
struct FixtureGroup: Identifiable, Hashable, Sendable {
    let league: League
    let fixtures: [Fixture]

    var id: Int { league.id }
}

@MainActor
@Observable
final class MatchListViewModel {

    private let service: FootballAPIServicing
    private let store: CustomLineupStore?

    private(set) var fixtures: [Fixture] = []
    private(set) var isLoading = false
    private(set) var error: APIError?
    private(set) var banner: DataBanner?

    var selectedDate: Date
    var filter: LeagueFilter = .all

    let dates: [Date]

    private var loadedDayKey: String?

    init(service: FootballAPIServicing, store: CustomLineupStore? = nil, referenceDate: Date = Date()) {
        self.service = service
        self.store = store
        self.selectedDate = referenceDate.startOfDay()
        self.dates = Date.matchDayStrip(around: referenceDate)
    }

    var groups: [FixtureGroup] {
        let filtered = fixtures.filter { filter.matches($0) }
        let grouped = Dictionary(grouping: filtered) { $0.league.id }
        return grouped.values.compactMap { fixtures -> FixtureGroup? in
            guard let league = fixtures.first?.league else { return nil }
            return FixtureGroup(league: league, fixtures: fixtures.sorted { $0.date < $1.date })
        }
        .sorted { lhs, rhs in
            let lhsPriority = MatchListViewModel.priority(for: lhs.league)
            let rhsPriority = MatchListViewModel.priority(for: rhs.league)
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
            if lhs.league.country != rhs.league.country { return lhs.league.country < rhs.league.country }
            return lhs.league.name < rhs.league.name
        }
    }

    var isEmpty: Bool { isLoading == false && error == nil && groups.isEmpty }

    var liveCount: Int { fixtures.filter(\.isLive).count }

    func select(date: Date) async {
        let normalised = date.startOfDay()
        guard normalised != selectedDate else { return }
        selectedDate = normalised
        await load()
    }

    func select(filter: LeagueFilter) {
        self.filter = filter
    }

    func loadIfNeeded() async {
        guard fixtures.isEmpty || loadedDayKey != selectedDate.apiDayString else { return }
        await load()
    }

    func load() async {
        isLoading = true
        error = nil
        let dayKey = selectedDate.apiDayString

        do {
            let response = try await service.fixtures(on: selectedDate, leagueID: nil)
            fixtures = response.value
            banner = DataBanner(source: response.source)
            loadedDayKey = dayKey
            await store?.cacheFixtures(response.value, dayKey: dayKey)
        } catch {
            let apiError = APIError.wrap(error)
            let cached = await store?.cachedFixtures(dayKey: dayKey) ?? []
            if cached.isEmpty {
                fixtures = []
                self.error = apiError
                banner = nil
            } else {
                fixtures = cached
                loadedDayKey = dayKey
                self.error = nil
                banner = apiError == .rateLimited ? .rateLimited(storedAt: Date()) : .offline(storedAt: Date())
            }
        }

        isLoading = false
    }

    func refresh() async {
        await load()
    }

    /// Big leagues float to the top of the list.
    private static func priority(for league: League) -> Int {
        if let index = LeagueCatalog.all.firstIndex(where: { $0.id == league.id }) { return index }
        return LeagueCatalog.all.count + (league.isInternational ? 0 : 1)
    }
}
