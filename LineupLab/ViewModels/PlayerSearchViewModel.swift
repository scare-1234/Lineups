import Foundation
import Observation

/// Search + filtering for the player picker. Searches the whole API-Football database,
/// so any player from any league or country can be added to a custom lineup.
@MainActor
@Observable
final class PlayerSearchViewModel {

    private let service: FootballAPIServicing
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    var query: String = ""

    var roleFilter: PitchRole?
    var nationalityFilter: String?
    var minimumRating: Double = 0

    private(set) var results: [Player] = []
    private(set) var isLoading = false
    private(set) var error: APIError?
    private(set) var banner: DataBanner?
    private(set) var hasSearched = false

    /// Everyone seen this session — the pool Quick Fill draws from.
    private(set) var pool: [Player] = []

    init(service: FootballAPIServicing, seed: [Player] = []) {
        self.service = service
        self.pool = seed
        self.results = seed
    }

    var filteredResults: [Player] {
        results.filter { player in
            if let roleFilter, player.pitchRole != roleFilter { return false }
            if let nationalityFilter, player.nationality != nationalityFilter { return false }
            if minimumRating > 0, (player.rating ?? 0) < minimumRating { return false }
            return true
        }
        .sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
    }

    var availableNationalities: [String] {
        Array(Set(results.map(\.nationality))).filter { $0.isEmpty == false }.sorted()
    }

    var isQueryTooShort: Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty == false && trimmed.count < AppConstants.minimumSearchLength
    }

    var showsEmptyState: Bool {
        isLoading == false && error == nil && filteredResults.isEmpty
    }

    func clearFilters() {
        roleFilter = nil
        nationalityFilter = nil
        minimumRating = 0
    }

    /// Called by the view whenever the search field changes; debounces before hitting the API.
    func queryChanged() {
        scheduleSearch()
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.count >= AppConstants.minimumSearchLength else {
            results = pool
            isLoading = false
            error = nil
            return
        }

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: AppConstants.searchDebounce)
            guard Task.isCancelled == false else { return }
            await self?.search(trimmed)
        }
    }

    func search(_ term: String) async {
        isLoading = true
        error = nil
        do {
            let response = try await service.searchPlayers(named: term, season: nil)
            guard Task.isCancelled == false else {
                isLoading = false
                return
            }
            results = response.value
            banner = DataBanner(source: response.source)
            remember(response.value)
            hasSearched = true
        } catch {
            results = []
            self.error = APIError.wrap(error)
        }
        isLoading = false
    }

    func searchNow() async {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= AppConstants.minimumSearchLength else { return }
        await search(trimmed)
    }

    func remember(_ players: [Player]) {
        var seen = Set(pool.map(\.id))
        for player in players where seen.insert(player.id).inserted {
            pool.append(player)
        }
    }

    /// Highest-rated players that are not already in the lineup, best match for the role first.
    func quickFillCandidates(excluding usedIDs: Set<Int>, role: PitchRole?) -> [Player] {
        pool
            .filter { usedIDs.contains($0.id) == false }
            .sorted { lhs, rhs in
                let lhsScore = score(lhs, role: role)
                let rhsScore = score(rhs, role: role)
                if lhsScore != rhsScore { return lhsScore > rhsScore }
                return lhs.name < rhs.name
            }
    }

    private func score(_ player: Player, role: PitchRole?) -> Double {
        let rating = player.rating ?? 5.5
        guard let role, let playerRole = player.pitchRole else { return rating }
        return rating * playerRole.compatibility(with: role)
    }
}
