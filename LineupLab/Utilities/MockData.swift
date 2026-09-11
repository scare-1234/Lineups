import Foundation

/// Sample data for SwiftUI previews, empty-state placeholders and tests.
/// Names are fictional so nothing here can be mistaken for real API output.
enum MockData {

    static let referenceDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 11
        components.hour = 19
        components.minute = 0
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar.date(from: components) ?? Date()
    }()

    // MARK: - Teams and leagues

    static let homeTeam = Team(id: 33, name: "Riverside United", country: "England")
    static let awayTeam = Team(id: 40, name: "Northgate City", country: "England")
    static let brazil = Team(id: 6, name: "Brazil", country: "Brazil", isNational: true)
    static let france = Team(id: 2, name: "France", country: "France", isNational: true)

    static let premierLeague = League(
        id: 39,
        name: "Premier League",
        country: "England",
        season: 2026,
        type: "League"
    )

    static let worldCup = League(
        id: 1,
        name: "World Cup",
        country: "World",
        season: 2026,
        type: "Cup"
    )

    // MARK: - Fixtures

    static let liveFixture = Fixture(
        id: 1_001_001,
        date: referenceDate,
        status: "2H",
        homeTeam: homeTeam,
        awayTeam: awayTeam,
        homeScore: 2,
        awayScore: 1,
        league: premierLeague,
        venue: "Riverside Stadium",
        venueCity: "Riverside",
        referee: "A. Fielding",
        elapsed: 67,
        statusDescription: "Second Half"
    )

    static let upcomingFixture = Fixture(
        id: 1_001_002,
        date: referenceDate.addingTimeInterval(60 * 60 * 26),
        status: "NS",
        homeTeam: awayTeam,
        awayTeam: homeTeam,
        homeScore: nil,
        awayScore: nil,
        league: premierLeague,
        venue: "Northgate Park",
        venueCity: "Northgate"
    )

    static let finishedFixture = Fixture(
        id: 1_001_003,
        date: referenceDate.addingTimeInterval(-60 * 60 * 48),
        status: "FT",
        homeTeam: brazil,
        awayTeam: france,
        homeScore: 3,
        awayScore: 3,
        league: worldCup,
        venue: "Estádio Central",
        venueCity: "São Paulo",
        referee: "M. Duarte"
    )

    static let fixtures: [Fixture] = [liveFixture, upcomingFixture, finishedFixture]

    // MARK: - Players

    static func player(
        id: Int,
        name: String,
        age: Int,
        nationality: String,
        position: PitchRole,
        rating: Double?,
        club: String = "Riverside United"
    ) -> Player {
        Player(
            id: id,
            name: name,
            firstName: name.split(separator: " ").first.map(String.init),
            lastName: name.split(separator: " ").dropFirst().joined(separator: " "),
            age: age,
            nationality: nationality,
            photo: nil,
            height: "183 cm",
            weight: "77 kg",
            position: position.rawValue,
            rating: rating,
            clubTeam: club,
            birthDate: Calendar(identifier: .gregorian).date(byAdding: .year, value: -age, to: referenceDate),
            birthPlace: "Riverside",
            birthCountry: nationality,
            seasonStats: [
                PlayerSeasonStats(
                    teamId: 33,
                    teamName: club,
                    teamLogo: nil,
                    leagueId: 39,
                    leagueName: "Premier League",
                    season: 2026,
                    appearances: 28,
                    lineups: 25,
                    minutes: 2_240,
                    goals: position == .attacker ? 14 : 3,
                    assists: 7,
                    rating: rating,
                    position: position.rawValue,
                    yellowCards: 3,
                    redCards: 0
                )
            ]
        )
    }

    static let featuredPlayer = player(
        id: 276,
        name: "Rafael Moreno",
        age: 24,
        nationality: "Brazil",
        position: .attacker,
        rating: 8.4
    )

    static let searchResults: [Player] = [
        featuredPlayer,
        player(id: 277, name: "Luc Bertrand", age: 27, nationality: "France", position: .midfielder, rating: 7.6, club: "Northgate City"),
        player(id: 278, name: "Tomas Vidal", age: 31, nationality: "Spain", position: .defender, rating: 6.9, club: "Riverside United"),
        player(id: 279, name: "Kwame Asante", age: 22, nationality: "Ghana", position: .attacker, rating: 7.2, club: "Northgate City"),
        player(id: 280, name: "Ivan Petrov", age: 29, nationality: "Croatia", position: .goalkeeper, rating: 5.8, club: "Riverside United"),
        player(id: 281, name: "Ken Ito", age: 26, nationality: "Japan", position: .midfielder, rating: 9.1, club: "Riverside United"),
        player(id: 282, name: "Diego Salas", age: 19, nationality: "Argentina", position: .defender, rating: nil, club: "Northgate City")
    ]

    // MARK: - Lineups

    private static let homeNames: [(String, String, Int, PitchRole, Double?)] = [
        ("Ivan Petrov", "Croatia", 29, .goalkeeper, 7.1),
        ("Tomas Vidal", "Spain", 31, .defender, 6.9),
        ("Marcus Fell", "England", 26, .defender, 7.4),
        ("Yannick Boye", "Belgium", 28, .defender, 8.2),
        ("Diego Salas", "Argentina", 19, .defender, 6.4),
        ("Ken Ito", "Japan", 26, .midfielder, 9.1),
        ("Luc Bertrand", "France", 27, .midfielder, 7.6),
        ("Samir Haddad", "Morocco", 24, .midfielder, 5.6),
        ("Rafael Moreno", "Brazil", 24, .attacker, 8.4),
        ("Owen Blake", "Wales", 23, .attacker, 4.8),
        ("Kwame Asante", "Ghana", 22, .attacker, 7.2)
    ]

    private static let awayNames: [(String, String, Int, PitchRole, Double?)] = [
        ("Nils Berger", "Germany", 30, .goalkeeper, 6.8),
        ("Paolo Ricci", "Italy", 27, .defender, 7.0),
        ("Ade Okafor", "Nigeria", 25, .defender, 7.7),
        ("Hugo Lindqvist", "Sweden", 29, .defender, 6.2),
        ("Ciaran Doyle", "Ireland", 24, .defender, 6.6),
        ("Milos Janko", "Serbia", 28, .midfielder, 7.9),
        ("Andre Costa", "Portugal", 26, .midfielder, 7.3),
        ("Felix Adler", "Austria", 22, .midfielder, nil),
        ("Bruno Alves", "Brazil", 25, .midfielder, 8.0),
        ("Jae-won Park", "South Korea", 23, .midfielder, 6.1),
        ("Idris Bakary", "Senegal", 27, .attacker, 8.8)
    ]

    static func lineup(
        team: Team,
        formation: String,
        roster: [(String, String, Int, PitchRole, Double?)]
    ) -> MatchLineup {
        let parsed = FormationParser.parse(formation)
        let slots = parsed?.slots ?? []
        let starters = roster.enumerated().map { index, entry -> LineupPlayer in
            let slot = slots.indices.contains(index) ? slots[index] : nil
            let person = player(
                id: team.id * 100 + index,
                name: entry.0,
                age: entry.2,
                nationality: entry.1,
                position: entry.3,
                rating: entry.4,
                club: team.name
            )
            return LineupPlayer(
                player: person,
                number: index + 1,
                position: entry.3.apiCode,
                grid: slot?.grid,
                isStarting: true,
                rating: entry.4,
                matchStats: PlayerMatchStats(
                    playerId: person.id,
                    rating: entry.4,
                    minutes: 90,
                    position: entry.3.apiCode,
                    number: index + 1,
                    goals: entry.3 == .attacker ? 1 : 0,
                    assists: 1,
                    shotsTotal: 3,
                    shotsOn: 2,
                    passesTotal: 48,
                    passesKey: 2,
                    passAccuracy: 87,
                    tacklesTotal: 2,
                    duelsTotal: 9,
                    duelsWon: 6,
                    dribbleAttempts: 4,
                    dribbleSuccess: 3,
                    foulsDrawn: 2,
                    foulsCommitted: 1,
                    yellowCards: 0,
                    redCards: 0
                )
            )
        }

        let substitutes = (0..<5).map { index -> LineupPlayer in
            let person = player(
                id: team.id * 100 + 50 + index,
                name: "Sub Player \(index + 1)",
                age: 21 + index,
                nationality: "England",
                position: index == 0 ? .goalkeeper : .midfielder,
                rating: index % 2 == 0 ? nil : 6.5 + Double(index) / 10,
                club: team.name
            )
            return LineupPlayer(
                player: person,
                number: 12 + index,
                position: (index == 0 ? PitchRole.goalkeeper : .midfielder).apiCode,
                grid: nil,
                isStarting: false,
                rating: index % 2 == 0 ? nil : 6.5 + Double(index) / 10
            )
        }

        return MatchLineup(
            team: team,
            formation: formation,
            startXI: starters,
            substitutes: substitutes,
            coachName: "R. Calder"
        )
    }

    static let homeLineup = lineup(team: homeTeam, formation: "4-3-3", roster: homeNames)
    static let awayLineup = lineup(team: awayTeam, formation: "4-2-3-1", roster: awayNames)
    static let matchLineups = MatchLineups(home: homeLineup, away: awayLineup)

    // MARK: - Events and statistics

    static let events: [MatchEvent] = [
        MatchEvent(id: "1", minute: 12, extraMinute: nil, teamId: homeTeam.id, teamName: homeTeam.name, teamLogo: nil, playerId: 3_301, playerName: "Rafael Moreno", assistName: "Ken Ito", type: "Goal", detail: "Normal Goal"),
        MatchEvent(id: "2", minute: 29, extraMinute: nil, teamId: awayTeam.id, teamName: awayTeam.name, teamLogo: nil, playerId: 4_005, playerName: "Idris Bakary", assistName: nil, type: "Goal", detail: "Header"),
        MatchEvent(id: "3", minute: 45, extraMinute: 2, teamId: homeTeam.id, teamName: homeTeam.name, teamLogo: nil, playerId: 3_307, playerName: "Samir Haddad", assistName: nil, type: "Card", detail: "Yellow Card"),
        MatchEvent(id: "4", minute: 58, extraMinute: nil, teamId: homeTeam.id, teamName: homeTeam.name, teamLogo: nil, playerId: 3_309, playerName: "Owen Blake", assistName: "Sub Player 2", type: "subst", detail: "Substitution 1"),
        MatchEvent(id: "5", minute: 66, extraMinute: nil, teamId: homeTeam.id, teamName: homeTeam.name, teamLogo: nil, playerId: 3_305, playerName: "Ken Ito", assistName: nil, type: "Goal", detail: "Penalty")
    ]

    static let statistics: [TeamMatchStatistics] = [
        TeamMatchStatistics(teamId: homeTeam.id, teamName: homeTeam.name, values: [
            "Ball Possession": "58%",
            "Total Shots": "14",
            "Shots on Goal": "6",
            "Corner Kicks": "7",
            "Fouls": "9",
            "Yellow Cards": "2",
            "Red Cards": "0",
            "Offsides": "1",
            "Passes %": "87%"
        ]),
        TeamMatchStatistics(teamId: awayTeam.id, teamName: awayTeam.name, values: [
            "Ball Possession": "42%",
            "Total Shots": "9",
            "Shots on Goal": "3",
            "Corner Kicks": "4",
            "Fouls": "13",
            "Yellow Cards": "3",
            "Red Cards": "1",
            "Offsides": "3",
            "Passes %": "79%"
        ])
    ]

    // MARK: - Custom lineups

    static var customLineup: CustomLineup {
        let formation = FormationParser.parse("4-3-3") ?? FormationParser.defaultFormation
        let roster = homeNames
        let players = zip(formation.slots, roster).map { slot, entry in
            CustomLineupPlayer(
                playerId: abs(entry.0.hashValue % 90_000) + 1_000,
                playerName: entry.0,
                playerNationality: entry.1,
                playerAge: entry.2,
                playerRating: entry.4,
                positionSlot: slot.id,
                formationPosition: slot.grid,
                playerPhoto: nil,
                playerClub: "Riverside United",
                playerPosition: entry.3.rawValue
            )
        }
        return CustomLineup(
            name: "Dream XI",
            formation: "4-3-3",
            players: players,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )
    }

    static var savedLineups: [CustomLineup] {
        let second = CustomLineup(
            name: "Counter Attack",
            formation: "3-5-2",
            players: [],
            createdAt: referenceDate,
            updatedAt: referenceDate
        )
        return [customLineup, second]
    }

    static let squad: [Player] = homeNames.enumerated().map { index, entry in
        player(id: 9_000 + index, name: entry.0, age: entry.2, nationality: "Brazil", position: entry.3, rating: entry.4, club: "Riverside United")
    }

    static let standings: [StandingRow] = [
        StandingRow(rank: 1, team: homeTeam, points: 24, goalDifference: 12, played: 10, wins: 7, draws: 3, losses: 0, goalsFor: 22, goalsAgainst: 10, group: "Premier League", form: "WWDWW"),
        StandingRow(rank: 2, team: awayTeam, points: 19, goalDifference: 5, played: 10, wins: 6, draws: 1, losses: 3, goalsFor: 17, goalsAgainst: 12, group: "Premier League", form: "LWWDW")
    ]
}
