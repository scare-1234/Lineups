import Foundation

/// A football player.
///
/// `nationality` is the country the player represents (API field `player.nationality`)
/// and `age` is the API's own `player.age`. `rating` is the most recent match rating
/// (API field `games.rating` from the fixtures/players endpoint).
struct Player: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    var name: String
    var firstName: String?
    var lastName: String?
    var age: Int
    var nationality: String
    var photo: URL?
    var height: String?
    var weight: String?
    var position: String?
    var rating: Double?
    var clubTeam: String?
    var birthDate: Date?
    var birthPlace: String?
    var birthCountry: String?
    var seasonStats: [PlayerSeasonStats]

    init(
        id: Int,
        name: String,
        firstName: String? = nil,
        lastName: String? = nil,
        age: Int = 0,
        nationality: String = "",
        photo: URL? = nil,
        height: String? = nil,
        weight: String? = nil,
        position: String? = nil,
        rating: Double? = nil,
        clubTeam: String? = nil,
        birthDate: Date? = nil,
        birthPlace: String? = nil,
        birthCountry: String? = nil,
        seasonStats: [PlayerSeasonStats] = []
    ) {
        self.id = id
        self.name = name
        self.firstName = firstName
        self.lastName = lastName
        self.age = age
        self.nationality = nationality
        self.photo = photo
        self.height = height
        self.weight = weight
        self.position = position
        self.rating = rating
        self.clubTeam = clubTeam
        self.birthDate = birthDate
        self.birthPlace = birthPlace
        self.birthCountry = birthCountry
        self.seasonStats = seasonStats
    }

    var fullName: String {
        let parts = [firstName, lastName].compactMap { $0 }.filter { $0.isEmpty == false }
        return parts.isEmpty ? name : parts.joined(separator: " ")
    }

    var pitchRole: PitchRole? { PitchRole(apiValue: position) }

    /// Localised position name, falling back to whatever the API sent.
    var positionLabel: String { pitchRole?.displayName ?? position ?? L10n.Common.unknown }

    var flagEmoji: String? { NationalityFlag.emoji(for: nationality) }

    /// Flag + country, or the country on its own when there is no flag for it.
    var nationalityLabel: String { NationalityFlag.label(for: nationality) }

    var ageLabel: String { L10n.Player.age(age) }

    /// Initials for the silhouette placeholder when a photo is missing.
    var initials: String {
        let words = name.split(separator: " ").prefix(2)
        let letters = words.compactMap { $0.first }.map(String.init)
        return letters.joined().uppercased()
    }

    /// The best season line to summarise the player with: most minutes played.
    var primarySeasonStats: PlayerSeasonStats? {
        seasonStats.max { ($0.minutes ?? 0) < ($1.minutes ?? 0) }
    }
}

extension Player {
    /// Rebuilds a `Player` from a saved lineup entry so the detail sheet can open
    /// straight from the builder (it refreshes the full profile from the API afterwards).
    init(custom: CustomLineupPlayer) {
        self.init(
            id: custom.playerId,
            name: custom.playerName,
            age: custom.playerAge,
            nationality: custom.playerNationality,
            photo: custom.playerPhoto,
            position: custom.playerPosition,
            rating: custom.playerRating,
            clubTeam: custom.playerClub
        )
    }
}

/// One row of the `statistics` array on the players endpoint.
struct PlayerSeasonStats: Codable, Hashable, Sendable, Identifiable {
    var teamId: Int?
    var teamName: String?
    var teamLogo: URL?
    var leagueId: Int?
    var leagueName: String?
    var season: Int?
    var appearances: Int?
    var lineups: Int?
    var minutes: Int?
    var goals: Int?
    var assists: Int?
    var rating: Double?
    var position: String?
    var yellowCards: Int?
    var redCards: Int?

    var id: String {
        "\(leagueId ?? 0)-\(teamId ?? 0)-\(season ?? 0)-\(position ?? "")"
    }
}

/// Per-match statistics from `GET /fixtures/players`.
struct PlayerMatchStats: Codable, Hashable, Sendable {
    var playerId: Int
    var rating: Double?
    var minutes: Int?
    var position: String?
    var number: Int?
    var isCaptain: Bool
    var isSubstitute: Bool
    var goals: Int?
    var assists: Int?
    var shotsTotal: Int?
    var shotsOn: Int?
    var passesTotal: Int?
    var passesKey: Int?
    var passAccuracy: Int?
    var tacklesTotal: Int?
    var blocks: Int?
    var interceptions: Int?
    var duelsTotal: Int?
    var duelsWon: Int?
    var dribbleAttempts: Int?
    var dribbleSuccess: Int?
    var foulsDrawn: Int?
    var foulsCommitted: Int?
    var yellowCards: Int?
    var redCards: Int?

    init(
        playerId: Int,
        rating: Double? = nil,
        minutes: Int? = nil,
        position: String? = nil,
        number: Int? = nil,
        isCaptain: Bool = false,
        isSubstitute: Bool = false,
        goals: Int? = nil,
        assists: Int? = nil,
        shotsTotal: Int? = nil,
        shotsOn: Int? = nil,
        passesTotal: Int? = nil,
        passesKey: Int? = nil,
        passAccuracy: Int? = nil,
        tacklesTotal: Int? = nil,
        blocks: Int? = nil,
        interceptions: Int? = nil,
        duelsTotal: Int? = nil,
        duelsWon: Int? = nil,
        dribbleAttempts: Int? = nil,
        dribbleSuccess: Int? = nil,
        foulsDrawn: Int? = nil,
        foulsCommitted: Int? = nil,
        yellowCards: Int? = nil,
        redCards: Int? = nil
    ) {
        self.playerId = playerId
        self.rating = rating
        self.minutes = minutes
        self.position = position
        self.number = number
        self.isCaptain = isCaptain
        self.isSubstitute = isSubstitute
        self.goals = goals
        self.assists = assists
        self.shotsTotal = shotsTotal
        self.shotsOn = shotsOn
        self.passesTotal = passesTotal
        self.passesKey = passesKey
        self.passAccuracy = passAccuracy
        self.tacklesTotal = tacklesTotal
        self.blocks = blocks
        self.interceptions = interceptions
        self.duelsTotal = duelsTotal
        self.duelsWon = duelsWon
        self.dribbleAttempts = dribbleAttempts
        self.dribbleSuccess = dribbleSuccess
        self.foulsDrawn = foulsDrawn
        self.foulsCommitted = foulsCommitted
        self.yellowCards = yellowCards
        self.redCards = redCards
    }
}
