import Foundation

/// A user-built lineup. This is the value type the UI works with; `CoreDataStack`
/// persists it as the `CustomLineup` / `CustomLineupPlayer` Core Data entities.
struct CustomLineup: Identifiable, Hashable, Codable, Sendable {
    var id: UUID
    var name: String
    var formation: String
    var players: [CustomLineupPlayer]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        formation: String = FormationParser.defaultFormationName,
        players: [CustomLineupPlayer] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.formation = formation
        self.players = players
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var parsedFormation: Formation? { FormationParser.parse(formation) }

    /// Slot id → player, which is how the builder and the pitch view read the squad.
    var playersBySlot: [String: CustomLineupPlayer] {
        Dictionary(players.map { ($0.positionSlot, $0) }, uniquingKeysWith: { first, _ in first })
    }

    var averageRating: Double? { RatingScale.average(of: players.map(\.playerRating)) }

    var totalAge: Int { players.reduce(0) { $0 + $1.playerAge } }

    var averageAge: Double? {
        guard players.isEmpty == false else { return nil }
        return Double(totalAge) / Double(players.count)
    }

    /// Nationality breakdown, most represented first, e.g. 5 Brazil, 3 France.
    var nationalityBreakdown: [NationalityCount] {
        Dictionary(grouping: players, by: \.playerNationality)
            .map { NationalityCount(nationality: $0.key, count: $0.value.count) }
            .sorted {
                $0.count == $1.count ? $0.nationality < $1.nationality : $0.count > $1.count
            }
    }

    var isComplete: Bool {
        guard let formation = parsedFormation else { return false }
        return players.count == formation.playerCount
    }
}

/// One line of a lineup's nationality breakdown, e.g. "5 Brazil".
struct NationalityCount: Identifiable, Hashable, Sendable {
    let nationality: String
    let count: Int

    var id: String { nationality }
    var flagEmoji: String? { NationalityFlag.emoji(for: nationality) }
    var label: String { L10n.Builder.nationalityCount(count, nationality) }
}

/// One player inside a saved lineup. Deliberately denormalised so saved lineups keep
/// working offline and without re-hitting the API.
struct CustomLineupPlayer: Identifiable, Hashable, Codable, Sendable {
    var playerId: Int
    var playerName: String
    var playerNationality: String
    var playerAge: Int
    var playerRating: Double?
    /// "GK", "LB", "CB1" … matches `FormationSlot.id`.
    var positionSlot: String
    /// "1:1", "2:3" … matches `FormationSlot.grid`.
    var formationPosition: String
    var playerPhoto: URL?
    var playerClub: String?
    var playerPosition: String?

    var id: Int { playerId }

    var role: PitchRole? { PitchRole(apiValue: playerPosition) }

    var flagEmoji: String? { NationalityFlag.emoji(for: playerNationality) }

    var nationalityLabel: String { NationalityFlag.label(for: playerNationality) }

    var initials: String {
        playerName.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }

    init(
        playerId: Int,
        playerName: String,
        playerNationality: String,
        playerAge: Int,
        playerRating: Double? = nil,
        positionSlot: String,
        formationPosition: String,
        playerPhoto: URL? = nil,
        playerClub: String? = nil,
        playerPosition: String? = nil
    ) {
        self.playerId = playerId
        self.playerName = playerName
        self.playerNationality = playerNationality
        self.playerAge = playerAge
        self.playerRating = playerRating
        self.positionSlot = positionSlot
        self.formationPosition = formationPosition
        self.playerPhoto = playerPhoto
        self.playerClub = playerClub
        self.playerPosition = playerPosition
    }

    init(player: Player, slot: FormationSlot) {
        self.init(
            playerId: player.id,
            playerName: player.name,
            playerNationality: player.nationality,
            playerAge: player.age,
            playerRating: player.rating,
            positionSlot: slot.id,
            formationPosition: slot.grid,
            playerPhoto: player.photo,
            playerClub: player.clubTeam,
            playerPosition: player.position
        )
    }

    /// Returns a copy moved to another slot.
    func moved(to slot: FormationSlot) -> CustomLineupPlayer {
        var copy = self
        copy.positionSlot = slot.id
        copy.formationPosition = slot.grid
        return copy
    }
}

// MARK: - Validation

enum CustomLineupIssue: Hashable, Sendable, Identifiable {
    case unknownFormation(String)
    case duplicatePlayer(name: String)
    case wrongPlayerCount(expected: Int, actual: Int)
    case unknownSlot(String)
    case duplicateSlot(String)
    case missingName

    var id: String {
        switch self {
        case .unknownFormation(let value): "unknownFormation-\(value)"
        case .duplicatePlayer(let name): "duplicate-\(name)"
        case .wrongPlayerCount(let expected, let actual): "count-\(expected)-\(actual)"
        case .unknownSlot(let slot): "unknownSlot-\(slot)"
        case .duplicateSlot(let slot): "duplicateSlot-\(slot)"
        case .missingName: "missingName"
        }
    }

    var message: String {
        switch self {
        case .unknownFormation(let value):
            String(localized: "\(value) is not a formation LineupLab understands.", comment: "Validation error")
        case .duplicatePlayer(let name):
            String(localized: "\(name) appears more than once.", comment: "Validation error")
        case .wrongPlayerCount(let expected, let actual):
            String(localized: "This formation needs \(expected) players, but \(actual) are selected.", comment: "Validation error")
        case .unknownSlot(let slot):
            String(localized: "\(slot) is not a position in this formation.", comment: "Validation error")
        case .duplicateSlot(let slot):
            String(localized: "Two players are assigned to \(slot).", comment: "Validation error")
        case .missingName:
            String(localized: "Give your lineup a name.", comment: "Validation error")
        }
    }
}

enum CustomLineupValidator {
    /// Checks a lineup is saveable: a known formation, the right number of players,
    /// no duplicated players and no duplicated or unknown slots.
    static func validate(_ lineup: CustomLineup, requireComplete: Bool = true) -> [CustomLineupIssue] {
        var issues: [CustomLineupIssue] = []

        if lineup.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.missingName)
        }

        guard let formation = FormationParser.parse(lineup.formation) else {
            issues.append(.unknownFormation(lineup.formation))
            return issues
        }

        if requireComplete, lineup.players.count != formation.playerCount {
            issues.append(.wrongPlayerCount(expected: formation.playerCount, actual: lineup.players.count))
        }

        var seenPlayers: Set<Int> = []
        for player in lineup.players where seenPlayers.insert(player.playerId).inserted == false {
            issues.append(.duplicatePlayer(name: player.playerName))
        }

        var seenSlots: Set<String> = []
        for player in lineup.players {
            if formation.slot(id: player.positionSlot) == nil {
                issues.append(.unknownSlot(player.positionSlot))
            }
            if seenSlots.insert(player.positionSlot).inserted == false {
                issues.append(.duplicateSlot(player.positionSlot))
            }
        }

        return issues
    }

    static func isValid(_ lineup: CustomLineup, requireComplete: Bool = true) -> Bool {
        validate(lineup, requireComplete: requireComplete).isEmpty
    }
}
