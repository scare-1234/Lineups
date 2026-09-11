import Foundation

struct Fixture: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    var date: Date
    /// API short status: "NS", "1H", "HT", "2H", "FT", "PST", "CANC"…
    var status: String
    var homeTeam: Team
    var awayTeam: Team
    var homeScore: Int?
    var awayScore: Int?
    var league: League
    var venue: String?
    var venueCity: String?
    var referee: String?
    var elapsed: Int?
    var statusDescription: String?

    init(
        id: Int,
        date: Date,
        status: String,
        homeTeam: Team,
        awayTeam: Team,
        homeScore: Int? = nil,
        awayScore: Int? = nil,
        league: League,
        venue: String? = nil,
        venueCity: String? = nil,
        referee: String? = nil,
        elapsed: Int? = nil,
        statusDescription: String? = nil
    ) {
        self.id = id
        self.date = date
        self.status = status
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.league = league
        self.venue = venue
        self.venueCity = venueCity
        self.referee = referee
        self.elapsed = elapsed
        self.statusDescription = statusDescription
    }

    var kind: FixtureStatusKind { FixtureStatusKind(apiStatus: status) }

    var isLive: Bool { kind == .live }

    var hasScore: Bool { homeScore != nil && awayScore != nil }

    var scoreLine: String {
        guard let homeScore, let awayScore else { return date.kickoffString }
        return "\(homeScore) – \(awayScore)"
    }

    /// Lineups are published roughly an hour before kick-off.
    var lineupsLikelyAvailable: Bool {
        kind != .scheduled || date.timeIntervalSinceNow < 60 * 60
    }
}

enum FixtureStatusKind: String, Sendable, Hashable {
    case scheduled
    case live
    case halfTime
    case finished
    case postponed
    case cancelled
    case unknown

    init(apiStatus: String) {
        switch apiStatus.uppercased() {
        case "TBD", "NS": self = .scheduled
        case "1H", "2H", "ET", "BT", "P", "LIVE", "INT": self = .live
        case "HT": self = .halfTime
        case "FT", "AET", "PEN": self = .finished
        case "PST": self = .postponed
        case "CANC", "ABD", "SUSP", "AWD", "WO": self = .cancelled
        default: self = .unknown
        }
    }

    /// Badge caption, e.g. "LIVE", "FT", "HT".
    func badgeText(apiStatus: String, elapsed: Int?) -> String {
        switch self {
        case .live:
            if let elapsed { return "\(elapsed)'" }
            return L10n.Matches.live
        case .halfTime: return "HT"
        case .finished: return "FT"
        case .postponed: return "PST"
        case .cancelled: return apiStatus.uppercased()
        case .scheduled, .unknown: return apiStatus.uppercased()
        }
    }

    var isInPlay: Bool { self == .live || self == .halfTime }
}

/// One entry of the match timeline (`GET /fixtures/events`).
struct MatchEvent: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var minute: Int
    var extraMinute: Int?
    var teamId: Int
    var teamName: String
    var teamLogo: URL?
    var playerId: Int?
    var playerName: String?
    var assistName: String?
    /// "Goal", "Card", "subst", "Var"
    var type: String
    var detail: String
    var comments: String?

    var kind: MatchEventKind { MatchEventKind(type: type, detail: detail) }

    var minuteLabel: String {
        guard let extraMinute, extraMinute > 0 else { return "\(minute)'" }
        return "\(minute)+\(extraMinute)'"
    }
}

enum MatchEventKind: Sendable, Hashable {
    case goal
    case ownGoal
    case penaltyMissed
    case yellowCard
    case redCard
    case substitution
    case varDecision
    case other

    init(type: String, detail: String) {
        let type = type.lowercased()
        let detail = detail.lowercased()
        if type == "goal" {
            if detail.contains("own") { self = .ownGoal }
            else if detail.contains("missed") { self = .penaltyMissed }
            else { self = .goal }
        } else if type == "card" {
            self = detail.contains("red") ? .redCard : .yellowCard
        } else if type.contains("subst") {
            self = .substitution
        } else if type == "var" {
            self = .varDecision
        } else {
            self = .other
        }
    }

    var symbol: String {
        switch self {
        case .goal: "⚽️"
        case .ownGoal: "🥅"
        case .penaltyMissed: "❌"
        case .yellowCard: "🟨"
        case .redCard: "🟥"
        case .substitution: "🔄"
        case .varDecision: "📺"
        case .other: "•"
        }
    }
}

/// One team's side of `GET /fixtures/statistics`.
struct TeamMatchStatistics: Codable, Hashable, Sendable, Identifiable {
    var teamId: Int
    var teamName: String
    var values: [String: String]

    var id: Int { teamId }

    func value(for key: MatchStatisticKey) -> String? { values[key.apiName] }

    func intValue(for key: MatchStatisticKey) -> Int? {
        guard let raw = values[key.apiName] else { return nil }
        return Int(raw.replacingOccurrences(of: "%", with: ""))
    }
}

enum MatchStatisticKey: String, CaseIterable, Sendable {
    case possession
    case shotsTotal
    case shotsOnGoal
    case corners
    case fouls
    case yellowCards
    case redCards
    case offsides
    case passAccuracy

    var apiName: String {
        switch self {
        case .possession: "Ball Possession"
        case .shotsTotal: "Total Shots"
        case .shotsOnGoal: "Shots on Goal"
        case .corners: "Corner Kicks"
        case .fouls: "Fouls"
        case .yellowCards: "Yellow Cards"
        case .redCards: "Red Cards"
        case .offsides: "Offsides"
        case .passAccuracy: "Passes %"
        }
    }

    var displayName: String {
        switch self {
        case .possession: String(localized: "Possession", comment: "Match statistic")
        case .shotsTotal: String(localized: "Shots", comment: "Match statistic")
        case .shotsOnGoal: String(localized: "Shots on Target", comment: "Match statistic")
        case .corners: String(localized: "Corners", comment: "Match statistic")
        case .fouls: String(localized: "Fouls", comment: "Match statistic")
        case .yellowCards: String(localized: "Yellow Cards", comment: "Match statistic")
        case .redCards: String(localized: "Red Cards", comment: "Match statistic")
        case .offsides: String(localized: "Offsides", comment: "Match statistic")
        case .passAccuracy: String(localized: "Pass Accuracy", comment: "Match statistic")
        }
    }

    /// Rows shown on the Stats tab, in order, below the possession bar.
    static let comparisonRows: [MatchStatisticKey] = [
        .shotsTotal, .shotsOnGoal, .corners, .fouls, .yellowCards, .redCards, .offsides, .passAccuracy
    ]
}
