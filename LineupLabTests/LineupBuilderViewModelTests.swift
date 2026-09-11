import XCTest
@testable import LineupLab

@MainActor
final class LineupBuilderViewModelTests: XCTestCase {

    private func makeStore() -> CustomLineupStore {
        CustomLineupStore(stack: CoreDataStack(inMemory: true))
    }

    private func makeViewModel(existing: CustomLineup? = nil) -> LineupBuilderViewModel {
        LineupBuilderViewModel(store: makeStore(), existing: existing)
    }

    private func player(
        id: Int,
        role: PitchRole,
        rating: Double?,
        nationality: String = "Brazil",
        age: Int = 25
    ) -> Player {
        Player(
            id: id,
            name: "Player \(id)",
            age: age,
            nationality: nationality,
            position: role.rawValue,
            rating: rating,
            clubTeam: "Riverside United"
        )
    }

    func testStartsEmptyOnTheDefaultFormation() {
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.formation.name, FormationParser.defaultFormationName)
        XCTAssertEqual(viewModel.totalSlots, 11)
        XCTAssertEqual(viewModel.filledCount, 0)
        XCTAssertFalse(viewModel.isComplete)
    }

    func testAssignWithoutASlotPicksACompatibleOne() throws {
        let viewModel = makeViewModel()
        let slot = try XCTUnwrap(viewModel.assign(player(id: 1, role: .goalkeeper, rating: 7.0)))
        XCTAssertEqual(slot.id, "GK")
        XCTAssertEqual(viewModel.filledCount, 1)

        let attackerSlot = try XCTUnwrap(viewModel.assign(player(id: 2, role: .attacker, rating: 8.0)))
        XCTAssertEqual(attackerSlot.role, .attacker)
    }

    func testAPlayerCanOnlyAppearOnce() throws {
        let viewModel = makeViewModel()
        let striker = player(id: 7, role: .attacker, rating: 8.5)
        let first = try XCTUnwrap(viewModel.assign(striker))

        let otherSlot = try XCTUnwrap(viewModel.formation.slots.first { $0.id != first.id && $0.role == .attacker })
        viewModel.assign(striker, to: otherSlot)

        XCTAssertEqual(viewModel.filledCount, 1)
        XCTAssertNil(viewModel.assignments[first.id])
        XCTAssertEqual(viewModel.assignments[otherSlot.id]?.playerId, 7)
        let ids = viewModel.currentLineup.players.map(\.playerId)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testRemoveAndClear() throws {
        let viewModel = makeViewModel()
        let slot = try XCTUnwrap(viewModel.assign(player(id: 1, role: .midfielder, rating: 7.0)))
        viewModel.remove(slotID: slot.id)
        XCTAssertEqual(viewModel.filledCount, 0)

        viewModel.assign(player(id: 2, role: .defender, rating: 7.0))
        viewModel.assign(player(id: 3, role: .defender, rating: 7.0))
        viewModel.clearAll()
        XCTAssertEqual(viewModel.filledCount, 0)
        XCTAssertTrue(viewModel.unplaced.isEmpty)
    }

    func testDragAndDropSwapsTwoPlayers() throws {
        let viewModel = makeViewModel()
        let keeperSlot = try XCTUnwrap(viewModel.assign(player(id: 1, role: .goalkeeper, rating: 7.0)))
        let strikerSlot = try XCTUnwrap(viewModel.assign(player(id: 2, role: .attacker, rating: 8.0)))

        viewModel.move(from: keeperSlot.id, to: strikerSlot.id)

        XCTAssertEqual(viewModel.assignments[strikerSlot.id]?.playerId, 1)
        XCTAssertEqual(viewModel.assignments[keeperSlot.id]?.playerId, 2)
        // The persisted grid follows the slot.
        XCTAssertEqual(viewModel.assignments[strikerSlot.id]?.formationPosition, strikerSlot.grid)
        XCTAssertEqual(viewModel.assignments[strikerSlot.id]?.positionSlot, strikerSlot.id)
    }

    func testDragToAnEmptySlotMovesThePlayer() throws {
        let viewModel = makeViewModel()
        let slot = try XCTUnwrap(viewModel.assign(player(id: 1, role: .midfielder, rating: 7.0)))
        let empty = try XCTUnwrap(viewModel.formation.slots.first { viewModel.assignments[$0.id] == nil })

        viewModel.move(from: slot.id, to: empty.id)

        XCTAssertEqual(viewModel.filledCount, 1)
        XCTAssertEqual(viewModel.assignments[empty.id]?.playerId, 1)
        XCTAssertNil(viewModel.assignments[slot.id])
    }

    func testQuickFillUsesTheHighestRatedAvailablePlayers() {
        let viewModel = makeViewModel()
        var candidates: [Player] = []
        for index in 0..<15 {
            let role: PitchRole = index == 0 ? .goalkeeper : (index < 6 ? .defender : (index < 11 ? .midfielder : .attacker))
            candidates.append(player(id: 100 + index, role: role, rating: Double(index) / 2 + 4))
        }

        let filled = viewModel.quickFill(from: candidates)

        XCTAssertEqual(filled, 11)
        XCTAssertTrue(viewModel.isComplete)
        XCTAssertEqual(viewModel.usedPlayerIDs.count, 11)
        // The keeper slot is filled by an actual goalkeeper.
        XCTAssertEqual(viewModel.assignments["GK"]?.playerId, 100)
    }

    func testQuickFillNeverDuplicatesPlayers() {
        let viewModel = makeViewModel()
        let candidates = (0..<4).map { player(id: $0, role: .midfielder, rating: 7.0) }
        let filled = viewModel.quickFill(from: candidates)

        XCTAssertEqual(filled, 4)
        XCTAssertEqual(Set(viewModel.usedPlayerIDs).count, 4)
    }

    func testChangingFormationKeepsEveryone() {
        let viewModel = makeViewModel()
        let candidates = (0..<11).map { index -> Player in
            let role: PitchRole = index == 0 ? .goalkeeper : (index < 5 ? .defender : (index < 8 ? .midfielder : .attacker))
            return player(id: index, role: role, rating: 7.0)
        }
        viewModel.quickFill(from: candidates)
        XCTAssertEqual(viewModel.filledCount, 11)

        viewModel.change(formationNamed: "3-5-2")

        XCTAssertEqual(viewModel.formation.name, "3-5-2")
        XCTAssertEqual(viewModel.filledCount + viewModel.unplaced.count, 11)
        XCTAssertEqual(viewModel.filledCount, 11)
        XCTAssertEqual(viewModel.assignments["GK"]?.playerId, 0, "The keeper stays in goal")

        // Every assignment sits on a slot that exists in the new formation.
        for (slotID, player) in viewModel.assignments {
            XCTAssertNotNil(viewModel.formation.slot(id: slotID))
            XCTAssertEqual(player.positionSlot, slotID)
        }
    }

    func testSquadSummaryStatistics() {
        let viewModel = makeViewModel()
        viewModel.assign(player(id: 1, role: .goalkeeper, rating: 6.0, nationality: "Brazil", age: 30))
        viewModel.assign(player(id: 2, role: .defender, rating: 8.0, nationality: "France", age: 20))

        XCTAssertEqual(viewModel.totalAge, 50)
        XCTAssertEqual(viewModel.averageAge ?? 0, 25, accuracy: 0.001)
        XCTAssertEqual(viewModel.averageRating ?? 0, 7.0, accuracy: 0.001)
        XCTAssertEqual(viewModel.nationalityBreakdown.count, 2)
    }

    func testSaveRequiresANameAndThenPersists() async throws {
        let store = makeStore()
        let viewModel = LineupBuilderViewModel(store: store)
        viewModel.assign(player(id: 1, role: .goalkeeper, rating: 7.0))

        let savedWithoutName = await viewModel.save()
        XCTAssertFalse(savedWithoutName)
        XCTAssertTrue(viewModel.saveIssues.contains(.missingName))

        viewModel.name = "Dream XI"
        let saved = await viewModel.save()
        XCTAssertTrue(saved)
        XCTAssertTrue(viewModel.saveIssues.isEmpty)

        await store.loadLineups()
        XCTAssertEqual(store.lineups.count, 1)
        let stored = try XCTUnwrap(store.lineups.first)
        XCTAssertEqual(stored.name, "Dream XI")
        XCTAssertEqual(stored.players.count, 1)
        XCTAssertEqual(stored.players.first?.positionSlot, "GK")
        XCTAssertEqual(stored.formation, FormationParser.defaultFormationName)
    }

    func testEditingAnExistingLineupKeepsItsIdentity() async {
        let store = makeStore()
        let original = MockData.customLineup
        await store.save(original)

        let viewModel = LineupBuilderViewModel(store: store, existing: original)
        XCTAssertEqual(viewModel.filledCount, original.players.count)
        XCTAssertEqual(viewModel.lineupID, original.id)

        viewModel.name = "Updated XI"
        let saved = await viewModel.save()
        XCTAssertTrue(saved)

        await store.loadLineups()
        XCTAssertEqual(store.lineups.count, 1, "Editing must not create a second lineup")
        XCTAssertEqual(store.lineups.first?.name, "Updated XI")
    }

    func testDeleteAndDuplicate() async throws {
        let store = makeStore()
        await store.save(MockData.customLineup)
        await store.loadLineups()
        let original = try XCTUnwrap(store.lineups.first)

        _ = await store.duplicate(original)
        await store.loadLineups()
        XCTAssertEqual(store.lineups.count, 2)

        await store.delete(id: original.id)
        await store.loadLineups()
        XCTAssertEqual(store.lineups.count, 1)
        XCTAssertNil(store.lineup(id: original.id))
    }
}
