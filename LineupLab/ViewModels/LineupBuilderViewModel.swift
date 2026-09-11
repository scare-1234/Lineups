import Foundation
import Observation

/// Drives the custom lineup builder: formation choice, slot assignment, drag-to-swap,
/// quick fill, validation and saving to Core Data.
@MainActor
@Observable
final class LineupBuilderViewModel {

    private let store: CustomLineupStore

    /// Identity of the lineup being edited; a new lineup gets a fresh id.
    private(set) var lineupID: UUID
    private var createdAt: Date

    var name: String
    private(set) var formation: Formation
    private(set) var assignments: [String: CustomLineupPlayer] = [:]
    /// Players pushed out by a formation change; they stay around so nothing is lost.
    private(set) var unplaced: [CustomLineupPlayer] = []

    var selectedSlot: FormationSlot?
    var isShowingPlayerPicker = false
    var isShowingSaveDialog = false
    var lastSavedAt: Date?
    private(set) var saveIssues: [CustomLineupIssue] = []

    init(store: CustomLineupStore, existing: CustomLineup? = nil) {
        self.store = store
        let lineup = existing ?? CustomLineup(name: "", formation: FormationParser.defaultFormationName)
        lineupID = lineup.id
        createdAt = lineup.createdAt
        name = lineup.name
        formation = FormationParser.parse(lineup.formation) ?? FormationParser.defaultFormation
        assignments = lineup.playersBySlot
    }

    // MARK: - Derived state

    var slots: [FormationSlot] { formation.slots }

    var filledCount: Int { assignments.count }

    var totalSlots: Int { formation.playerCount }

    var isComplete: Bool { filledCount == totalSlots && totalSlots > 0 }

    var progressLabel: String { L10n.Builder.slotsFilled(filledCount, totalSlots) }

    var usedPlayerIDs: Set<Int> { Set(assignments.values.map(\.playerId)) }

    var currentLineup: CustomLineup {
        CustomLineup(
            id: lineupID,
            name: name,
            formation: formation.name,
            players: orderedPlayers,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }

    /// Players in formation order, so the saved lineup reads top-down.
    var orderedPlayers: [CustomLineupPlayer] {
        formation.slots.compactMap { assignments[$0.id] }
    }

    var averageRating: Double? { RatingScale.average(of: orderedPlayers.map(\.playerRating)) }

    var totalAge: Int { orderedPlayers.reduce(0) { $0 + $1.playerAge } }

    var averageAge: Double? {
        guard orderedPlayers.isEmpty == false else { return nil }
        return Double(totalAge) / Double(orderedPlayers.count)
    }

    var nationalityBreakdown: [NationalityCount] { currentLineup.nationalityBreakdown }

    func player(in slot: FormationSlot) -> CustomLineupPlayer? { assignments[slot.id] }

    func slot(withID id: String) -> FormationSlot? { formation.slot(id: id) }

    // MARK: - Editing

    func change(formationNamed name: String) {
        guard let newFormation = FormationParser.parse(name), newFormation.name != formation.name else { return }
        let result = FormationParser.remap(
            assignments,
            from: formation,
            to: newFormation,
            role: { $0.role }
        )
        // Move each player onto the slot it landed in so the persisted grid stays correct.
        var remapped: [String: CustomLineupPlayer] = [:]
        for (slotID, player) in result.assigned {
            guard let slot = newFormation.slot(id: slotID) else { continue }
            remapped[slotID] = player.moved(to: slot)
        }
        assignments = remapped
        unplaced = result.unplaced + unplaced
        formation = newFormation
        Haptics.impact(.light)
    }

    /// Places a player, using the selected slot when there is one and the best free
    /// slot for the player's position otherwise. Returns the slot that was filled.
    @discardableResult
    func assign(_ player: Player, to slot: FormationSlot? = nil) -> FormationSlot? {
        let target = slot
            ?? selectedSlot
            ?? FormationParser.bestSlot(for: player.pitchRole, in: formation, occupied: Set(assignments.keys))
        guard let target else { return nil }

        // A player can only appear once in a lineup.
        for (slotID, existing) in assignments where existing.playerId == player.id && slotID != target.id {
            assignments.removeValue(forKey: slotID)
        }
        unplaced.removeAll { $0.playerId == player.id }

        assignments[target.id] = CustomLineupPlayer(player: player, slot: target)
        selectedSlot = nil
        Haptics.impact(.medium)
        return target
    }

    @discardableResult
    func assign(_ player: CustomLineupPlayer, to slot: FormationSlot) -> FormationSlot? {
        for (slotID, existing) in assignments where existing.playerId == player.playerId && slotID != slot.id {
            assignments.removeValue(forKey: slotID)
        }
        unplaced.removeAll { $0.playerId == player.playerId }
        assignments[slot.id] = player.moved(to: slot)
        selectedSlot = nil
        Haptics.impact(.medium)
        return slot
    }

    func remove(slotID: String) {
        guard assignments.removeValue(forKey: slotID) != nil else { return }
        Haptics.impact(.light)
    }

    func clearAll() {
        assignments.removeAll()
        unplaced.removeAll()
        Haptics.warning()
    }

    /// Swaps two slots, or moves a player into an empty slot. Used by drag and drop.
    func move(from sourceSlotID: String, to destinationSlotID: String) {
        guard sourceSlotID != destinationSlotID,
              let source = formation.slot(id: sourceSlotID),
              let destination = formation.slot(id: destinationSlotID),
              let moving = assignments[sourceSlotID] else { return }

        if let displaced = assignments[destinationSlotID] {
            assignments[sourceSlotID] = displaced.moved(to: source)
        } else {
            assignments.removeValue(forKey: sourceSlotID)
        }
        assignments[destinationSlotID] = moving.moved(to: destination)
        Haptics.selection()
    }

    /// Fills every empty slot with the highest-rated compatible player from `candidates`.
    /// Returns how many slots were filled.
    @discardableResult
    func quickFill(from candidates: [Player]) -> Int {
        var used = usedPlayerIDs
        var filled = 0

        for slot in formation.slots where assignments[slot.id] == nil {
            let best = candidates
                .filter { used.contains($0.id) == false }
                .max { lhs, rhs in
                    quickFillScore(lhs, for: slot) < quickFillScore(rhs, for: slot)
                }
            guard let best else { continue }
            assignments[slot.id] = CustomLineupPlayer(player: best, slot: slot)
            used.insert(best.id)
            filled += 1
        }

        if filled > 0 { Haptics.success() }
        return filled
    }

    private func quickFillScore(_ player: Player, for slot: FormationSlot) -> Double {
        let rating = player.rating ?? 5.5
        guard let role = player.pitchRole else { return rating * 0.8 }
        return rating * role.compatibility(with: slot.role)
    }

    // MARK: - Saving

    /// Saves the lineup. Duplicate players, unknown slots and a missing name block the
    /// save; an incomplete XI is allowed so work in progress is never lost.
    func save() async -> Bool {
        let lineup = currentLineup
        let issues = CustomLineupValidator.validate(lineup, requireComplete: false)
        saveIssues = issues
        guard issues.isEmpty else {
            Haptics.warning()
            return false
        }
        let saved = await store.save(lineup)
        if saved {
            lastSavedAt = Date()
            Haptics.success()
        }
        return saved
    }

    /// Starts a fresh lineup in the same builder.
    func reset(to lineup: CustomLineup? = nil) {
        let target = lineup ?? CustomLineup(name: "", formation: FormationParser.defaultFormationName)
        lineupID = target.id
        createdAt = target.createdAt
        name = target.name
        formation = FormationParser.parse(target.formation) ?? FormationParser.defaultFormation
        assignments = target.playersBySlot
        unplaced = []
        saveIssues = []
        selectedSlot = nil
    }
}
