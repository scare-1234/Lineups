import Foundation
import Observation

/// Loads the full profile (age, nationality, season stats) for the player detail sheet.
@MainActor
@Observable
final class PlayerDetailViewModel {

    private let service: FootballAPIServicing
    private let store: CustomLineupStore?

    private(set) var player: Player
    private(set) var isLoading = false
    private(set) var error: APIError?
    private(set) var banner: DataBanner?

    let matchStats: PlayerMatchStats?

    init(
        player: Player,
        matchStats: PlayerMatchStats? = nil,
        service: FootballAPIServicing,
        store: CustomLineupStore? = nil
    ) {
        self.player = player
        self.matchStats = matchStats
        self.service = service
        self.store = store
    }

    /// The rating shown large at the top: this match if we have it, otherwise the season average.
    var headlineRating: Double? {
        matchStats?.rating ?? player.rating ?? player.primarySeasonStats?.rating
    }

    var seasonStats: PlayerSeasonStats? { player.primarySeasonStats }

    func load() async {
        // A cached profile keeps the daily request budget intact.
        if let cached = await store?.cachedPlayer(id: player.id) {
            player = merge(cached)
        }

        isLoading = true
        error = nil
        do {
            let response = try await service.player(id: player.id, season: nil)
            player = merge(response.value)
            banner = DataBanner(source: response.source)
            await store?.cachePlayer(player)
        } catch {
            // The sheet already has enough to be useful, so only surface hard failures.
            let apiError = APIError.wrap(error)
            if player.age == 0, player.nationality.isEmpty {
                self.error = apiError
            }
        }
        isLoading = false
    }

    /// Keeps whatever the lineup already told us when the profile is missing a field.
    private func merge(_ fetched: Player) -> Player {
        var merged = fetched
        if merged.rating == nil { merged.rating = player.rating }
        if merged.position == nil { merged.position = player.position }
        if merged.clubTeam == nil { merged.clubTeam = player.clubTeam }
        if merged.name.isEmpty { merged.name = player.name }
        return merged
    }
}
