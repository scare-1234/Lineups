import XCTest
@testable import LineupLab

/// Decoding tests against sample payloads shaped like real API-Football responses.
final class APIDecodingTests: XCTestCase {

    private let decoder = APIClient.makeDecoder()

    func testDecodesFixtures() throws {
        let envelope = try decoder.decode(APIEnvelope<FixtureItemDTO>.self, from: SampleJSON.data(SampleJSON.fixtures))
        XCTAssertEqual(envelope.results, 2)
        XCTAssertEqual(envelope.response.count, 2)

        let fixtures = envelope.response.compactMap(FootballAPIService.makeFixture(from:))
        XCTAssertEqual(fixtures.count, 2)

        let live = try XCTUnwrap(fixtures.first)
        XCTAssertEqual(live.id, 1001)
        XCTAssertEqual(live.status, "2H")
        XCTAssertEqual(live.kind, .live)
        XCTAssertTrue(live.isLive)
        XCTAssertEqual(live.elapsed, 67)
        XCTAssertEqual(live.homeScore, 2)
        XCTAssertEqual(live.awayScore, 1)
        XCTAssertEqual(live.homeTeam.name, "Riverside United")
        XCTAssertEqual(live.league.id, 39)
        XCTAssertEqual(live.league.country, "England")
        XCTAssertEqual(live.league.round, "Regular Season - 4")
        XCTAssertEqual(live.venue, "Riverside Stadium")
        XCTAssertEqual(live.referee, "A. Fielding")

        let expectedDate = try XCTUnwrap(APIDateParsing.date(fromISO8601: "2026-09-11T14:00:00+00:00"))
        XCTAssertEqual(live.date, expectedDate)
    }

    func testDecodesFixtureWithNullsAndInternationalLeague() throws {
        let envelope = try decoder.decode(APIEnvelope<FixtureItemDTO>.self, from: SampleJSON.data(SampleJSON.fixtures))
        let fixtures = envelope.response.compactMap(FootballAPIService.makeFixture(from:))
        let upcoming = try XCTUnwrap(fixtures.last)

        XCTAssertNil(upcoming.homeScore)
        XCTAssertNil(upcoming.venue)
        XCTAssertNil(upcoming.referee)
        XCTAssertEqual(upcoming.kind, .scheduled)
        XCTAssertTrue(upcoming.league.isInternational)
        XCTAssertFalse(upcoming.hasScore)
    }

    func testDecodesLineups() throws {
        let envelope = try decoder.decode(APIEnvelope<LineupItemDTO>.self, from: SampleJSON.data(SampleJSON.lineups))
        let lineups = envelope.response.compactMap(FootballAPIService.makeLineup(from:))
        XCTAssertEqual(lineups.count, 2)

        let home = try XCTUnwrap(lineups.first)
        XCTAssertEqual(home.formation, "4-3-3")
        XCTAssertEqual(home.startXI.count, 11)
        XCTAssertEqual(home.substitutes.count, 2)
        XCTAssertEqual(home.coachName, "R. Calder")

        let keeper = try XCTUnwrap(home.startXI.first)
        XCTAssertEqual(keeper.number, 1)
        XCTAssertEqual(keeper.grid, "1:1")
        XCTAssertEqual(keeper.role, .goalkeeper)
        XCTAssertTrue(keeper.isStarting)

        XCTAssertNil(home.substitutes.first?.grid)
        XCTAssertEqual(home.parsedFormation?.playerCount, 11)
    }

    func testDecodesPlayerMatchStatsIncludingRating() throws {
        let envelope = try decoder.decode(APIEnvelope<FixturePlayersItemDTO>.self, from: SampleJSON.data(SampleJSON.fixturePlayers))
        let entries = try XCTUnwrap(envelope.response.first?.players)
        XCTAssertEqual(entries.count, 2)

        let scorer = try XCTUnwrap(entries.first)
        let stats = try XCTUnwrap(FootballAPIService.makeMatchStats(playerId: 9, from: scorer.statistics?.first))
        XCTAssertEqual(stats.rating, 8.4)
        XCTAssertEqual(stats.minutes, 90)
        XCTAssertEqual(stats.goals, 2)
        XCTAssertEqual(stats.assists, 1)
        XCTAssertEqual(stats.shotsTotal, 5)
        XCTAssertEqual(stats.shotsOn, 3)
        // "82" arrives as a string and has to survive as a number.
        XCTAssertEqual(stats.passAccuracy, 82)
        XCTAssertEqual(stats.duelsWon, 9)
        XCTAssertEqual(stats.dribbleSuccess, 5)
        XCTAssertFalse(stats.isSubstitute)

        let benchStats = try XCTUnwrap(FootballAPIService.makeMatchStats(playerId: 10, from: entries[1].statistics?.first))
        XCTAssertNil(benchStats.rating)
        XCTAssertNil(benchStats.shotsTotal)
        // The same field can arrive as a bare number.
        XCTAssertEqual(benchStats.passAccuracy, 75)
        XCTAssertTrue(benchStats.isSubstitute)
        XCTAssertEqual(benchStats.yellowCards, 1)
    }

    func testDecodesPlayerProfileAgeNationalityAndStats() throws {
        let envelope = try decoder.decode(APIEnvelope<PlayerProfileItemDTO>.self, from: SampleJSON.data(SampleJSON.playerProfile))
        let dto = try XCTUnwrap(envelope.response.first)
        let player = FootballAPIService.makePlayer(from: dto)

        XCTAssertEqual(player.id, 276)
        XCTAssertEqual(player.age, 24)
        XCTAssertEqual(player.nationality, "Brazil")
        XCTAssertEqual(player.height, "175 cm")
        XCTAssertEqual(player.fullName, "Rafael Moreno")
        XCTAssertEqual(player.birthPlace, "Riverside")
        XCTAssertNotNil(player.birthDate)
        XCTAssertNotNil(player.photo)
        XCTAssertEqual(player.seasonStats.count, 2)

        // The league with the most minutes is the one summarised.
        XCTAssertEqual(player.clubTeam, "Riverside United")
        XCTAssertEqual(player.pitchRole, .attacker)
        let rating = try XCTUnwrap(player.rating)
        XCTAssertEqual(rating, 7.833333, accuracy: 0.000001)

        let league = try XCTUnwrap(player.primarySeasonStats)
        XCTAssertEqual(league.appearances, 28)
        XCTAssertEqual(league.goals, 14)
        XCTAssertEqual(league.assists, 7)
        XCTAssertEqual(league.minutes, 2240)
        XCTAssertEqual(league.season, 2026)
    }

    func testDecodesEventsAndStatistics() throws {
        let events = try decoder.decode(APIEnvelope<EventItemDTO>.self, from: SampleJSON.data(SampleJSON.events))
        let mapped = events.response.enumerated().compactMap { FootballAPIService.makeEvent(from: $1, index: $0) }
        XCTAssertEqual(mapped.count, 2)

        let card = try XCTUnwrap(mapped.first { $0.type == "Card" })
        XCTAssertEqual(card.kind, .yellowCard)
        XCTAssertEqual(card.minuteLabel, "45+2'")

        let goal = try XCTUnwrap(mapped.first { $0.type == "Goal" })
        XCTAssertEqual(goal.kind, .goal)
        XCTAssertEqual(goal.assistName, "Ken Ito")

        let stats = try decoder.decode(APIEnvelope<TeamStatisticsItemDTO>.self, from: SampleJSON.data(SampleJSON.statistics))
        let team = try XCTUnwrap(stats.response.first)
        var values: [String: String] = [:]
        for entry in team.statistics ?? [] {
            guard let type = entry.type, let value = entry.value?.value else { continue }
            values[type] = value
        }
        let statistics = TeamMatchStatistics(teamId: 33, teamName: "Riverside United", values: values)
        XCTAssertEqual(statistics.value(for: .possession), "58%")
        XCTAssertEqual(statistics.intValue(for: .possession), 58)
        XCTAssertEqual(statistics.intValue(for: .shotsOnGoal), 6)
        // Null values are dropped rather than decoded as zero.
        XCTAssertNil(statistics.value(for: .redCards))
    }

    func testDecodesBothShapesOfTheErrorsField() throws {
        struct Probe: Decodable { let errors: APIErrorPayload }

        let empty = try decoder.decode(Probe.self, from: SampleJSON.data(SampleJSON.fixtures))
        XCTAssertTrue(empty.errors.messages.isEmpty)

        let token = try decoder.decode(Probe.self, from: SampleJSON.data(SampleJSON.tokenError))
        XCTAssertEqual(token.errors.messages["token"], "Error/Missing application key.")
    }

    func testFlexiblePrimitivesAcceptStringsNumbersAndNull() throws {
        struct Holder: Decodable {
            let int: FlexibleInt
            let double: FlexibleDouble
            let string: FlexibleString
        }

        let json = """
        { "int": "85", "double": 7, "string": 12 }
        """
        let holder = try decoder.decode(Holder.self, from: SampleJSON.data(json))
        XCTAssertEqual(holder.int.value, 85)
        XCTAssertEqual(holder.double.value, 7)
        XCTAssertEqual(holder.string.value, "12")

        let nulls = """
        { "int": null, "double": null, "string": null }
        """
        let empty = try decoder.decode(Holder.self, from: SampleJSON.data(nulls))
        XCTAssertNil(empty.int.value)
        XCTAssertNil(empty.double.value)
        XCTAssertNil(empty.string.value)
    }

    func testMergesRatingsIntoLineups() throws {
        let lineupsEnvelope = try decoder.decode(APIEnvelope<LineupItemDTO>.self, from: SampleJSON.data(SampleJSON.lineups))
        let lineups = lineupsEnvelope.response.compactMap(FootballAPIService.makeLineup(from:))
        let matchLineups = MatchLineups(home: lineups.first, away: lineups.last)

        let statsEnvelope = try decoder.decode(APIEnvelope<FixturePlayersItemDTO>.self, from: SampleJSON.data(SampleJSON.fixturePlayers))
        var stats: [Int: PlayerMatchStats] = [:]
        for team in statsEnvelope.response {
            for entry in team.players ?? [] {
                guard let id = entry.player.id,
                      let mapped = FootballAPIService.makeMatchStats(playerId: id, from: entry.statistics?.first) else { continue }
                stats[id] = mapped
            }
        }

        let merged = FootballAPIService.merge(lineups: matchLineups, stats: stats)
        let scorer = try XCTUnwrap(merged.home?.startXI.first { $0.player.id == 9 })
        XCTAssertEqual(scorer.rating, 8.4)
        XCTAssertEqual(scorer.player.rating, 8.4)
        XCTAssertEqual(scorer.matchStats?.goals, 2)

        let unrated = try XCTUnwrap(merged.home?.startXI.first { $0.player.id == 2 })
        XCTAssertNil(unrated.rating)
    }

    func testEmptyResponseDecodesToEmptyArray() throws {
        let json = """
        { "get": "fixtures", "parameters": [], "errors": [], "results": 0, "paging": { "current": 1, "total": 1 }, "response": [] }
        """
        let envelope = try decoder.decode(APIEnvelope<FixtureItemDTO>.self, from: SampleJSON.data(json))
        XCTAssertEqual(envelope.results, 0)
        XCTAssertTrue(envelope.response.isEmpty)
    }
}
