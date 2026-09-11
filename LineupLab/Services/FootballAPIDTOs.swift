import Foundation

// MARK: - Envelope

/// Every API-Football response has the same shape:
/// `{ get, parameters, errors, results, paging, response: [...] }`.
struct APIEnvelope<Item: Decodable & Sendable>: Decodable, Sendable {
    let results: Int
    let paging: Paging?
    let response: [Item]

    struct Paging: Decodable, Sendable {
        let current: Int?
        let total: Int?
    }

    private enum CodingKeys: String, CodingKey {
        case results, paging, response
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        results = (try? container.decode(Int.self, forKey: .results)) ?? 0
        paging = try? container.decode(Paging.self, forKey: .paging)
        response = (try? container.decode([Item].self, forKey: .response)) ?? []
    }
}

/// `errors` is `[]` when everything is fine and a dictionary when it is not,
/// so it needs to decode from either shape.
struct APIErrorPayload: Decodable, Sendable {
    let messages: [String: String]

    init(messages: [String: String] = [:]) {
        self.messages = messages
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dictionary = try? container.decode([String: String].self) {
            messages = dictionary
        } else if let list = try? container.decode([String].self) {
            messages = Dictionary(uniqueKeysWithValues: list.enumerated().map { (String($0.offset), $0.element) })
        } else {
            messages = [:]
        }
    }
}

// MARK: - Loose primitives

/// API-Football is inconsistent about numbers: `"85"`, `85` and `85.0` all appear,
/// and `null` shows up nearly everywhere.
struct FlexibleInt: Decodable, Sendable, Hashable {
    let value: Int?

    init(value: Int?) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = nil
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = Int(double)
        } else if let string = try? container.decode(String.self) {
            let cleaned = string.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
            value = Int(cleaned) ?? Double(cleaned).map(Int.init)
        } else {
            value = nil
        }
    }
}

struct FlexibleDouble: Decodable, Sendable, Hashable {
    let value: Double?

    init(value: Double?) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = nil
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let int = try? container.decode(Int.self) {
            value = Double(int)
        } else if let string = try? container.decode(String.self) {
            value = Double(string.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces))
        } else {
            value = nil
        }
    }
}

struct FlexibleString: Decodable, Sendable, Hashable {
    let value: String?

    init(value: String?) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = nil
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = String(int)
        } else if let double = try? container.decode(Double.self) {
            value = String(double)
        } else if let bool = try? container.decode(Bool.self) {
            value = String(bool)
        } else {
            value = nil
        }
    }
}

// MARK: - Shared objects

struct TeamDTO: Decodable, Sendable {
    let id: Int?
    let name: String?
    let logo: String?
    let country: String?
    let national: Bool?
    let winner: Bool?
    let code: String?
    let founded: Int?
}

struct LeagueDTO: Decodable, Sendable {
    let id: Int?
    let name: String?
    let country: String?
    let logo: String?
    let flag: String?
    let season: FlexibleInt?
    let round: String?
    let type: String?
}

struct VenueDTO: Decodable, Sendable {
    let id: Int?
    let name: String?
    let city: String?
    let capacity: Int?
}

// MARK: - Fixtures

struct FixtureItemDTO: Decodable, Sendable {
    let fixture: FixtureCoreDTO
    let league: LeagueDTO
    let teams: FixtureTeamsDTO
    let goals: FixtureGoalsDTO?
}

struct FixtureCoreDTO: Decodable, Sendable {
    let id: Int
    let referee: String?
    let timezone: String?
    let date: Date
    let timestamp: Int?
    let venue: VenueDTO?
    let status: FixtureStatusDTO?
}

struct FixtureStatusDTO: Decodable, Sendable {
    let long: String?
    let short: String?
    let elapsed: Int?
}

struct FixtureTeamsDTO: Decodable, Sendable {
    let home: TeamDTO
    let away: TeamDTO
}

struct FixtureGoalsDTO: Decodable, Sendable {
    let home: Int?
    let away: Int?
}

// MARK: - Lineups

struct LineupItemDTO: Decodable, Sendable {
    let team: TeamDTO
    let formation: String?
    let startXI: [LineupEntryDTO]?
    let substitutes: [LineupEntryDTO]?
    let coach: CoachDTO?
}

struct LineupEntryDTO: Decodable, Sendable {
    let player: LineupPlayerDTO
}

struct LineupPlayerDTO: Decodable, Sendable {
    let id: Int?
    let name: String?
    let number: Int?
    let pos: String?
    let grid: String?
}

struct CoachDTO: Decodable, Sendable {
    let id: Int?
    let name: String?
    let photo: String?
}

// MARK: - Per-player match statistics

struct FixturePlayersItemDTO: Decodable, Sendable {
    let team: TeamDTO
    let players: [FixturePlayerDTO]?
}

struct FixturePlayerDTO: Decodable, Sendable {
    let player: PlayerBriefDTO
    let statistics: [PlayerMatchStatsDTO]?
}

struct PlayerBriefDTO: Decodable, Sendable {
    let id: Int?
    let name: String?
    let photo: String?
}

struct PlayerMatchStatsDTO: Decodable, Sendable {
    let games: GamesDTO?
    let offsides: FlexibleInt?
    let shots: ShotsDTO?
    let goals: GoalsStatDTO?
    let passes: PassesDTO?
    let tackles: TacklesDTO?
    let duels: DuelsDTO?
    let dribbles: DribblesDTO?
    let fouls: FoulsDTO?
    let cards: CardsDTO?
}

struct GamesDTO: Decodable, Sendable {
    let minutes: FlexibleInt?
    let number: FlexibleInt?
    let position: String?
    /// The match rating, e.g. "7.8" — this is the player rating the app shows.
    let rating: FlexibleDouble?
    let captain: Bool?
    let substitute: Bool?
    /// Season aggregates (note the API's own spelling of "appearences").
    let appearences: FlexibleInt?
    let lineups: FlexibleInt?
}

struct ShotsDTO: Decodable, Sendable {
    let total: FlexibleInt?
    let on: FlexibleInt?
}

struct GoalsStatDTO: Decodable, Sendable {
    let total: FlexibleInt?
    let conceded: FlexibleInt?
    let assists: FlexibleInt?
    let saves: FlexibleInt?
}

struct PassesDTO: Decodable, Sendable {
    let total: FlexibleInt?
    let key: FlexibleInt?
    /// Percentage, sometimes a string such as "85".
    let accuracy: FlexibleInt?
}

struct TacklesDTO: Decodable, Sendable {
    let total: FlexibleInt?
    let blocks: FlexibleInt?
    let interceptions: FlexibleInt?
}

struct DuelsDTO: Decodable, Sendable {
    let total: FlexibleInt?
    let won: FlexibleInt?
}

struct DribblesDTO: Decodable, Sendable {
    let attempts: FlexibleInt?
    let success: FlexibleInt?
    let past: FlexibleInt?
}

struct FoulsDTO: Decodable, Sendable {
    let drawn: FlexibleInt?
    let committed: FlexibleInt?
}

struct CardsDTO: Decodable, Sendable {
    let yellow: FlexibleInt?
    let yellowred: FlexibleInt?
    let red: FlexibleInt?
}

// MARK: - Player profiles

struct PlayerProfileItemDTO: Decodable, Sendable {
    let player: PlayerProfileDTO
    let statistics: [PlayerSeasonStatsDTO]?
}

struct PlayerProfileDTO: Decodable, Sendable {
    let id: Int
    let name: String?
    let firstname: String?
    let lastname: String?
    /// The player's age, straight from the API.
    let age: Int?
    let birth: BirthDTO?
    /// The country the player represents.
    let nationality: String?
    let height: String?
    let weight: String?
    let injured: Bool?
    let photo: String?
}

struct BirthDTO: Decodable, Sendable {
    let date: String?
    let place: String?
    let country: String?
}

struct PlayerSeasonStatsDTO: Decodable, Sendable {
    let team: TeamDTO?
    let league: LeagueDTO?
    let games: GamesDTO?
    let goals: GoalsStatDTO?
    let cards: CardsDTO?
}

// MARK: - Squads

struct SquadItemDTO: Decodable, Sendable {
    let team: TeamDTO
    let players: [SquadPlayerDTO]?
}

struct SquadPlayerDTO: Decodable, Sendable {
    let id: Int?
    let name: String?
    let age: Int?
    let number: FlexibleInt?
    let position: String?
    let photo: String?
}

// MARK: - Events and statistics

struct EventItemDTO: Decodable, Sendable {
    let time: EventTimeDTO?
    let team: TeamDTO?
    let player: PlayerBriefDTO?
    let assist: PlayerBriefDTO?
    let type: String?
    let detail: String?
    let comments: String?
}

struct EventTimeDTO: Decodable, Sendable {
    let elapsed: Int?
    let extra: Int?
}

struct TeamStatisticsItemDTO: Decodable, Sendable {
    let team: TeamDTO
    let statistics: [StatisticEntryDTO]?
}

struct StatisticEntryDTO: Decodable, Sendable {
    let type: String?
    let value: FlexibleString?
}

// MARK: - Leagues and standings

struct LeagueItemDTO: Decodable, Sendable {
    let league: LeagueDTO
    let country: CountryDTO?
    let seasons: [SeasonDTO]?
}

struct CountryDTO: Decodable, Sendable {
    let name: String?
    let code: String?
    let flag: String?
}

struct SeasonDTO: Decodable, Sendable {
    let year: Int?
    let current: Bool?
}

struct StandingsItemDTO: Decodable, Sendable {
    let league: StandingsLeagueDTO
}

struct StandingsLeagueDTO: Decodable, Sendable {
    let id: Int?
    let name: String?
    let country: String?
    let logo: String?
    let season: Int?
    let standings: [[StandingRowDTO]]?
}

struct StandingRowDTO: Decodable, Sendable {
    let rank: Int?
    let team: TeamDTO?
    let points: Int?
    let goalsDiff: Int?
    let group: String?
    let form: String?
    let all: StandingGamesDTO?
}

struct StandingGamesDTO: Decodable, Sendable {
    let played: Int?
    let win: Int?
    let draw: Int?
    let lose: Int?
    let goals: StandingGoalsDTO?
}

struct StandingGoalsDTO: Decodable, Sendable {
    let `for`: Int?
    let against: Int?
}
