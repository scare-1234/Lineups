import XCTest
@testable import LineupLab

final class FormationParserTests: XCTestCase {

    func testParsesEverySupportedFormationIntoElevenSlots() throws {
        for name in FormationParser.supportedNames {
            let formation = try XCTUnwrap(FormationParser.parse(name), "\(name) should parse")
            XCTAssertEqual(formation.name, name)
            XCTAssertEqual(formation.playerCount, 11, "\(name) should have 11 slots")
            XCTAssertEqual(formation.slots(in: .goalkeeper).count, 1, "\(name) needs exactly one keeper")

            let ids = Set(formation.slots.map(\.id))
            XCTAssertEqual(ids.count, formation.slots.count, "\(name) has duplicate slot ids")

            for slot in formation.slots {
                XCTAssertTrue((0...1).contains(slot.point.x), "\(name)/\(slot.id) x out of bounds")
                XCTAssertTrue((0...1).contains(slot.point.y), "\(name)/\(slot.id) y out of bounds")
                XCTAssertNotNil(FormationParser.gridCoordinate(from: slot.grid))
            }
        }
    }

    func testLineCountsMatchTheFormationName() throws {
        let formation = try XCTUnwrap(FormationParser.parse("4-2-3-1"))
        XCTAssertEqual(formation.lines, [4, 2, 3, 1])
        XCTAssertEqual(formation.slots(in: .defender).count, 4)
        XCTAssertEqual(formation.slot(id: "CAM")?.role, .midfielder)
        XCTAssertEqual(formation.slot(id: "ST")?.role, .attacker)
        XCTAssertEqual(formation.slot(id: "GK")?.grid, "1:1")
    }

    func testWingBacksCountAsDefenders() throws {
        let formation = try XCTUnwrap(FormationParser.parse("5-3-2"))
        XCTAssertEqual(formation.slots(in: .defender).count, 5)
        XCTAssertEqual(formation.slot(id: "LWB")?.role, .defender)
    }

    func testKeeperSitsDeepestAndStrikersHighest() throws {
        let formation = try XCTUnwrap(FormationParser.parse("4-3-3"))
        let keeper = try XCTUnwrap(formation.slot(id: "GK"))
        let striker = try XCTUnwrap(formation.slot(id: "ST"))
        XCTAssertLessThan(keeper.point.y, striker.point.y)
    }

    func testRejectsNonsense() {
        XCTAssertNil(FormationParser.parse(nil))
        XCTAssertNil(FormationParser.parse(""))
        XCTAssertNil(FormationParser.parse("banana"))
        XCTAssertNil(FormationParser.parse("4-3-x"))
        XCTAssertNil(FormationParser.parse("9-9-9"))
        XCTAssertNil(FormationParser.parse("11"))
    }

    func testParsesUnusualShapesFromTheAPI() throws {
        let formation = try XCTUnwrap(FormationParser.parse("3-4-2-1"))
        XCTAssertEqual(formation.playerCount, 11)
        XCTAssertEqual(formation.lines, [3, 4, 2, 1])
    }

    func testGridCoordinateParsing() {
        XCTAssertEqual(FormationParser.gridCoordinate(from: "2:3")?.row, 2)
        XCTAssertEqual(FormationParser.gridCoordinate(from: "2:3")?.column, 3)
        XCTAssertNil(FormationParser.gridCoordinate(from: "2"))
        XCTAssertNil(FormationParser.gridCoordinate(from: "x:y"))
        XCTAssertNil(FormationParser.gridCoordinate(from: nil))
        XCTAssertNil(FormationParser.gridCoordinate(from: "0:1"))
    }

    func testLayoutPointsUseGridsWhenAvailable() {
        let grids = ["1:1", "2:1", "2:2", "2:3", "2:4", "3:1", "3:2", "3:3", "4:1", "4:2", "4:3"]
        let points = FormationParser.layoutPoints(grids: grids, fallbackFormation: "4-3-3")
        XCTAssertEqual(points.count, grids.count)

        // Keeper is deepest, forwards are highest up the pitch.
        XCTAssertEqual(points[0].y, 0.07, accuracy: 0.001)
        XCTAssertGreaterThan(points[10].y, points[0].y)
        // Column 1 renders on the left of column 4 in the same row.
        XCTAssertLessThan(points[1].x, points[4].x)
    }

    func testLayoutPointsFallBackToFormationWhenGridsAreMissing() {
        let grids: [String?] = Array(repeating: nil, count: 11)
        let points = FormationParser.layoutPoints(grids: grids, fallbackFormation: "4-4-2")
        XCTAssertEqual(points.count, 11)
        XCTAssertEqual(points.first?.y ?? 1, 0.07, accuracy: 0.001)
    }

    func testLayoutPointsSurviveUnknownFormationAndMissingGrids() {
        let points = FormationParser.layoutPoints(grids: Array(repeating: nil, count: 7), fallbackFormation: "nonsense")
        XCTAssertEqual(points.count, 7)
    }

    // MARK: - Re-assignment

    func testRemapKeepsPlayersCloseToTheirOldSlots() throws {
        let from = try XCTUnwrap(FormationParser.parse("4-3-3"))
        let to = try XCTUnwrap(FormationParser.parse("3-5-2"))

        var assignments: [String: CustomLineupPlayer] = [:]
        for slot in from.slots {
            assignments[slot.id] = CustomLineupPlayer(
                playerId: abs(slot.id.hashValue % 10_000),
                playerName: slot.id,
                playerNationality: "Brazil",
                playerAge: 25,
                playerRating: 7,
                positionSlot: slot.id,
                formationPosition: slot.grid,
                playerPosition: slot.role.rawValue
            )
        }

        let result = FormationParser.remap(assignments, from: from, to: to, role: { $0.role })
        XCTAssertEqual(result.assigned.count, 11)
        XCTAssertTrue(result.unplaced.isEmpty)

        // The keeper stays in goal.
        XCTAssertEqual(result.assigned["GK"]?.playerName, "GK")

        // Nobody is placed twice.
        let ids = result.assigned.values.map(\.playerId)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testRemapToASmallerFormationReportsUnplacedPlayers() throws {
        let from = try XCTUnwrap(FormationParser.parse("4-3-3"))
        // A deliberately short shape: seven outfield slots plus the keeper.
        let to = try XCTUnwrap(FormationParser.parse("3-3-1"))

        var assignments: [String: CustomLineupPlayer] = [:]
        for slot in from.slots {
            assignments[slot.id] = CustomLineupPlayer(
                playerId: abs(slot.id.hashValue % 10_000),
                playerName: slot.id,
                playerNationality: "France",
                playerAge: 24,
                playerRating: 7,
                positionSlot: slot.id,
                formationPosition: slot.grid,
                playerPosition: slot.role.rawValue
            )
        }

        let result = FormationParser.remap(assignments, from: from, to: to, role: { $0.role })
        XCTAssertEqual(result.assigned.count, to.playerCount)
        XCTAssertEqual(result.assigned.count + result.unplaced.count, 11)
    }

    func testBestSlotPrefersTheMatchingRole() throws {
        let formation = try XCTUnwrap(FormationParser.parse("4-3-3"))
        let keeperSlot = FormationParser.bestSlot(for: .goalkeeper, in: formation, occupied: [])
        XCTAssertEqual(keeperSlot?.id, "GK")

        let attackerSlot = FormationParser.bestSlot(for: .attacker, in: formation, occupied: [])
        XCTAssertEqual(attackerSlot?.role, .attacker)

        let occupiedAllAttack = Set(formation.slots(in: .attacker).map(\.id))
        let fallback = FormationParser.bestSlot(for: .attacker, in: formation, occupied: occupiedAllAttack)
        XCTAssertNotNil(fallback)
        XCTAssertNotEqual(fallback?.role, .attacker)

        let full = Set(formation.slots.map(\.id))
        XCTAssertNil(FormationParser.bestSlot(for: .midfielder, in: formation, occupied: full))
    }

    func testRoleCompatibility() {
        XCTAssertEqual(PitchRole.attacker.compatibility(with: .attacker), 1)
        XCTAssertGreaterThan(
            PitchRole.midfielder.compatibility(with: .attacker),
            PitchRole.defender.compatibility(with: .attacker)
        )
        XCTAssertLessThan(PitchRole.goalkeeper.compatibility(with: .defender), 0.1)
        XCTAssertLessThan(PitchRole.attacker.compatibility(with: .goalkeeper), 0.1)
    }

    func testRoleParsingAcceptsShortAndLongCodes() {
        XCTAssertEqual(PitchRole(apiValue: "G"), .goalkeeper)
        XCTAssertEqual(PitchRole(apiValue: "D"), .defender)
        XCTAssertEqual(PitchRole(apiValue: "M"), .midfielder)
        XCTAssertEqual(PitchRole(apiValue: "F"), .attacker)
        XCTAssertEqual(PitchRole(apiValue: "Goalkeeper"), .goalkeeper)
        XCTAssertEqual(PitchRole(apiValue: "attacker"), .attacker)
        XCTAssertNil(PitchRole(apiValue: nil))
        XCTAssertNil(PitchRole(apiValue: "Coach"))
    }
}
