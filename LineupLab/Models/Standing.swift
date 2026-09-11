import Foundation

/// One row of a league table (`GET /standings`).
struct StandingRow: Identifiable, Hashable, Sendable, Codable {
    var rank: Int
    var team: Team
    var points: Int
    var goalDifference: Int
    var played: Int
    var wins: Int
    var draws: Int
    var losses: Int
    var goalsFor: Int
    var goalsAgainst: Int
    var group: String?
    var form: String?

    var id: Int { team.id }
}
