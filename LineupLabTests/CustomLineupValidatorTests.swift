import XCTest
@testable import LineupLab

final class CustomLineupValidatorTests: XCTestCase {

    private func makePlayer(id: Int, slot: FormationSlot, name: String? = nil) -> CustomLineupPlayer {
        CustomLineupPlayer(
            playerId: id,
            playerName: name ?? "Player \(id)",
            playerNationality: "Brazil",
            playerAge: 25,
            playerRating: 7.5,
            positionSlot: slot.id,
            formationPosition: slot.grid,
            playerPosition: slot.role.rawValue
        )
    }

    private func makeCompleteLineup(formation name: String = "4-3-3") throws -> CustomLineup {
        let formation = try XCTUnwrap(FormationParser.parse(name))
        let players = formation.slots.enumerated().map { index, slot in
            makePlayer(id: index + 1, slot: slot)
        }
        return CustomLineup(name: "Dream XI", formation: name, players: players)
    }

    func testCompleteLineupIsValid() throws {
        let lineup = try makeCompleteLineup()
        XCTAssertTrue(CustomLineupValidator.isValid(lineup))
        XCTAssertTrue(lineup.isComplete)
        XCTAssertEqual(lineup.players.count, 11)
    }

    func testDuplicatePlayerIsRejected() throws {
        var lineup = try makeCompleteLineup()
        let formation = try XCTUnwrap(lineup.parsedFormation)
        let duplicateSlot = try XCTUnwrap(formation.slots.last)
        lineup.players[lineup.players.count - 1] = makePlayer(id: 1, slot: duplicateSlot, name: "Player 1")

        let issues = CustomLineupValidator.validate(lineup)
        XCTAssertTrue(issues.contains(.duplicatePlayer(name: "Player 1")))
        XCTAssertFalse(CustomLineupValidator.isValid(lineup))
    }

    func testWrongPlayerCountIsRejectedWhenCompletenessIsRequired() throws {
        var lineup = try makeCompleteLineup()
        lineup.players.removeLast()

        XCTAssertTrue(CustomLineupValidator.validate(lineup).contains(.wrongPlayerCount(expected: 11, actual: 10)))
        // Work in progress can still be saved.
        XCTAssertTrue(CustomLineupValidator.isValid(lineup, requireComplete: false))
        XCTAssertFalse(lineup.isComplete)
    }

    func testUnknownSlotIsRejected() throws {
        var lineup = try makeCompleteLineup()
        lineup.players[0].positionSlot = "SWEEPER"
        XCTAssertTrue(CustomLineupValidator.validate(lineup).contains(.unknownSlot("SWEEPER")))
    }

    func testDuplicateSlotIsRejected() throws {
        var lineup = try makeCompleteLineup()
        let secondSlot = lineup.players[1].positionSlot
        lineup.players[0].positionSlot = secondSlot
        XCTAssertTrue(CustomLineupValidator.validate(lineup).contains(.duplicateSlot(secondSlot)))
    }

    func testUnknownFormationIsRejected() {
        let lineup = CustomLineup(name: "Nonsense", formation: "banana", players: [])
        let issues = CustomLineupValidator.validate(lineup)
        XCTAssertEqual(issues, [.unknownFormation("banana")])
    }

    func testMissingNameIsRejected() throws {
        var lineup = try makeCompleteLineup()
        lineup.name = "   "
        XCTAssertTrue(CustomLineupValidator.validate(lineup).contains(.missingName))
    }

    func testSquadStatistics() throws {
        let formation = try XCTUnwrap(FormationParser.parse("4-3-3"))
        let players = formation.slots.enumerated().map { index, slot -> CustomLineupPlayer in
            CustomLineupPlayer(
                playerId: index + 1,
                playerName: "Player \(index)",
                playerNationality: index < 5 ? "Brazil" : "France",
                playerAge: 20 + index,
                playerRating: index == 0 ? nil : 7.0,
                positionSlot: slot.id,
                formationPosition: slot.grid
            )
        }
        let lineup = CustomLineup(name: "Stats", formation: "4-3-3", players: players)

        XCTAssertEqual(lineup.totalAge, (20...30).reduce(0, +))
        let average = try XCTUnwrap(lineup.averageRating)
        XCTAssertEqual(average, 7.0, accuracy: 0.0001)

        let breakdown = lineup.nationalityBreakdown
        XCTAssertEqual(breakdown.first?.nationality, "France")
        XCTAssertEqual(breakdown.first?.count, 6)
        XCTAssertEqual(breakdown.last?.nationality, "Brazil")
        XCTAssertEqual(breakdown.last?.count, 5)
        XCTAssertEqual(lineup.playersBySlot["GK"]?.playerId, 1)
    }
}
