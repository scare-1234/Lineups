import CoreGraphics
import Foundation

/// A player inside a match lineup, with the shirt number and pitch grid the API supplies.
struct LineupPlayer: Codable, Identifiable, Hashable, Sendable {
    var player: Player
    var number: Int
    var position: String
    /// "1:1", "2:3" … used to place the player on the pitch.
    var grid: String?
    var isStarting: Bool
    var rating: Double?
    var matchStats: PlayerMatchStats?

    var id: Int { player.id }

    var role: PitchRole? { PitchRole(apiValue: position) ?? player.pitchRole }

    init(
        player: Player,
        number: Int,
        position: String,
        grid: String? = nil,
        isStarting: Bool,
        rating: Double? = nil,
        matchStats: PlayerMatchStats? = nil
    ) {
        self.player = player
        self.number = number
        self.position = position
        self.grid = grid
        self.isStarting = isStarting
        self.rating = rating
        self.matchStats = matchStats
    }
}

/// One team's lineup for a fixture (`GET /fixtures/lineups`).
struct MatchLineup: Codable, Identifiable, Hashable, Sendable {
    var team: Team
    var formation: String
    var startXI: [LineupPlayer]
    var substitutes: [LineupPlayer]
    var coachName: String?
    var coachPhoto: URL?

    var id: Int { team.id }

    var parsedFormation: Formation? { FormationParser.parse(formation) }

    var averageRating: Double? {
        RatingScale.average(of: startXI.map(\.rating))
    }

    /// Pitch coordinates for the starting XI, honouring the API grid when present.
    var startingPoints: [CGPoint] {
        FormationParser.layoutPoints(grids: startXI.map(\.grid), fallbackFormation: formation)
    }
}

/// Both teams' lineups plus the ratings merged in from `GET /fixtures/players`.
struct MatchLineups: Hashable, Sendable {
    var home: MatchLineup?
    var away: MatchLineup?

    var isEmpty: Bool { home == nil && away == nil }
}
