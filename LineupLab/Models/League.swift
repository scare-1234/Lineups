import Foundation

struct League: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    var name: String
    var country: String
    var logo: URL?
    var season: Int
    /// "League" or "Cup".
    var type: String
    var flag: URL?
    var round: String?

    init(
        id: Int,
        name: String,
        country: String = "",
        logo: URL? = nil,
        season: Int = 0,
        type: String = "League",
        flag: URL? = nil,
        round: String? = nil
    ) {
        self.id = id
        self.name = name
        self.country = country
        self.logo = logo
        self.season = season
        self.type = type
        self.flag = flag
        self.round = round
    }

    var isInternational: Bool {
        LeagueCatalog.internationalIDs.contains(id) || country.lowercased() == "world"
    }

    var flagEmoji: String? { NationalityFlag.emoji(for: country) }
}

/// The leagues LineupLab surfaces as one-tap filters.
enum LeagueCatalog {
    struct Entry: Identifiable, Hashable, Sendable {
        let id: Int
        let name: String
        let isInternational: Bool
    }

    static let premierLeague = Entry(id: 39, name: "Premier League", isInternational: false)
    static let laLiga = Entry(id: 140, name: "La Liga", isInternational: false)
    static let serieA = Entry(id: 135, name: "Serie A", isInternational: false)
    static let bundesliga = Entry(id: 78, name: "Bundesliga", isInternational: false)
    static let ligue1 = Entry(id: 61, name: "Ligue 1", isInternational: false)
    static let championsLeague = Entry(id: 2, name: "Champions League", isInternational: false)
    static let europaLeague = Entry(id: 3, name: "Europa League", isInternational: false)

    static let worldCup = Entry(id: 1, name: "World Cup", isInternational: true)
    static let euro = Entry(id: 4, name: "Euro Championship", isInternational: true)
    static let copaAmerica = Entry(id: 9, name: "Copa America", isInternational: true)
    static let afcon = Entry(id: 6, name: "Africa Cup of Nations", isInternational: true)
    static let asianCup = Entry(id: 7, name: "Asian Cup", isInternational: true)
    static let nationsLeague = Entry(id: 5, name: "UEFA Nations League", isInternational: true)
    static let worldCupQualifiers = Entry(id: 32, name: "World Cup Qualification", isInternational: true)
    static let friendlies = Entry(id: 10, name: "International Friendlies", isInternational: true)

    /// Chips shown on the match list.
    static let clubFilters: [Entry] = [
        premierLeague, laLiga, serieA, bundesliga, ligue1, championsLeague
    ]

    static let internationalCompetitions: [Entry] = [
        worldCup, euro, copaAmerica, afcon, asianCup, nationsLeague, worldCupQualifiers, friendlies
    ]

    static let internationalIDs: Set<Int> = Set(internationalCompetitions.map(\.id))

    static var all: [Entry] { clubFilters + internationalCompetitions }
}
