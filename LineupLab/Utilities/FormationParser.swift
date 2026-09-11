import Foundation
import CoreGraphics

// MARK: - Roles

/// The four buckets API-Football uses for player positions.
enum PitchRole: String, CaseIterable, Codable, Sendable, Identifiable {
    case goalkeeper
    case defender
    case midfielder
    case attacker

    var id: String { rawValue }

    /// Accepts both the lineup short codes ("G", "D", "M", "F") and the long
    /// spellings the players endpoint returns ("Goalkeeper", "Attacker", …).
    init?(apiValue: String?) {
        guard let raw = apiValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              raw.isEmpty == false else { return nil }
        switch raw {
        case "g", "gk", "goalkeeper", "keeper": self = .goalkeeper
        case "d", "def", "defender", "defence", "defense": self = .defender
        case "m", "mid", "midfielder", "midfield": self = .midfielder
        case "f", "a", "att", "fw", "attacker", "forward", "striker": self = .attacker
        default: return nil
        }
    }

    var apiCode: String {
        switch self {
        case .goalkeeper: "G"
        case .defender: "D"
        case .midfielder: "M"
        case .attacker: "F"
        }
    }

    var displayName: String {
        switch self {
        case .goalkeeper: L10n.Positions.goalkeeper
        case .defender: L10n.Positions.defender
        case .midfielder: L10n.Positions.midfielder
        case .attacker: L10n.Positions.attacker
        }
    }

    var abbreviation: String {
        switch self {
        case .goalkeeper: L10n.Positions.goalkeeperShort
        case .defender: L10n.Positions.defenderShort
        case .midfielder: L10n.Positions.midfielderShort
        case .attacker: L10n.Positions.attackerShort
        }
    }

    /// Distance up the pitch: 0 for a keeper, 3 for a striker.
    var depth: Int {
        switch self {
        case .goalkeeper: 0
        case .defender: 1
        case .midfielder: 2
        case .attacker: 3
        }
    }

    /// 1.0 for an exact match, lower the further apart two roles are.
    /// A keeper never belongs anywhere but in goal, and nobody else belongs in goal.
    func compatibility(with other: PitchRole) -> Double {
        if self == other { return 1 }
        if self == .goalkeeper || other == .goalkeeper { return 0.05 }
        return max(0, 1 - 0.35 * Double(abs(depth - other.depth)))
    }
}

// MARK: - Slots

/// One position in a formation: where it sits on the pitch and what it is called.
struct FormationSlot: Identifiable, Hashable, Sendable {
    /// Stable identifier, also used as the persisted `positionSlot` ("GK", "LCB", "ST").
    let id: String
    let label: String
    let role: PitchRole
    /// 0 is the goalkeeper line, 1 the defensive line, and so on.
    let line: Int
    let indexInLine: Int
    /// API-Football style "row:column" coordinate, persisted as `formationPosition`.
    let grid: String
    /// Normalised pitch position: x runs left→right, y runs own goal→opponent goal.
    let point: CGPoint
}

/// A parsed formation such as "4-2-3-1".
struct Formation: Identifiable, Hashable, Sendable {
    let name: String
    /// Outfield lines only, e.g. [4, 2, 3, 1].
    let lines: [Int]
    let slots: [FormationSlot]

    var id: String { name }
    var playerCount: Int { slots.count }

    func slot(id: String) -> FormationSlot? {
        slots.first { $0.id == id }
    }

    func slots(in role: PitchRole) -> [FormationSlot] {
        slots.filter { $0.role == role }
    }
}

// MARK: - Parser

enum FormationParser {

    /// Formations offered in the builder.
    static let supportedNames = [
        "4-3-3", "4-4-2", "4-2-3-1", "3-5-2", "3-4-3", "5-3-2", "4-1-4-1", "4-5-1"
    ]

    static var supported: [Formation] {
        supportedNames.compactMap { parse($0) }
    }

    static let defaultFormationName = "4-3-3"

    static var defaultFormation: Formation {
        parse(defaultFormationName) ?? Formation(name: defaultFormationName, lines: [4, 3, 3], slots: [])
    }

    /// Hand-tuned labels so the common formations read the way a coach would write them.
    private static let blueprints: [String: [[String]]] = [
        "4-3-3": [["LB", "LCB", "RCB", "RB"], ["LCM", "CM", "RCM"], ["LW", "ST", "RW"]],
        "4-4-2": [["LB", "LCB", "RCB", "RB"], ["LM", "LCM", "RCM", "RM"], ["LST", "RST"]],
        "4-2-3-1": [["LB", "LCB", "RCB", "RB"], ["LDM", "RDM"], ["LW", "CAM", "RW"], ["ST"]],
        "3-5-2": [["LCB", "CB", "RCB"], ["LWB", "LCM", "CM", "RCM", "RWB"], ["LST", "RST"]],
        "3-4-3": [["LCB", "CB", "RCB"], ["LM", "LCM", "RCM", "RM"], ["LW", "ST", "RW"]],
        "5-3-2": [["LWB", "LCB", "CB", "RCB", "RWB"], ["LCM", "CM", "RCM"], ["LST", "RST"]],
        "4-1-4-1": [["LB", "LCB", "RCB", "RB"], ["CDM"], ["LM", "LCM", "RCM", "RM"], ["ST"]],
        "4-5-1": [["LB", "LCB", "RCB", "RB"], ["LM", "LCM", "CM", "RCM", "RM"], ["ST"]]
    ]

    /// Labels that describe a role more precisely than their line does.
    private static let roleOverrides: [String: PitchRole] = [
        "LW": .attacker, "RW": .attacker, "ST": .attacker, "LST": .attacker,
        "RST": .attacker, "CF": .attacker, "LF": .attacker, "RF": .attacker,
        "CAM": .midfielder, "CDM": .midfielder, "LDM": .midfielder, "RDM": .midfielder,
        "LWB": .defender, "RWB": .defender
    ]

    /// Parses "4-3-3" (or any other dash separated shape the API returns) into slots.
    /// Returns `nil` for shapes that cannot be understood.
    static func parse(_ raw: String?) -> Formation? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.isEmpty == false else { return nil }

        let components = trimmed.split(whereSeparator: { $0 == "-" || $0 == "–" })
        guard components.isEmpty == false else { return nil }

        var lines: [Int] = []
        for component in components {
            guard let value = Int(component.trimmingCharacters(in: .whitespaces)), value > 0, value <= 6 else { return nil }
            lines.append(value)
        }
        guard lines.count >= 2, lines.reduce(0, +) <= 10 else { return nil }

        let name = lines.map(String.init).joined(separator: "-")
        let labels = blueprints[name] ?? lines.enumerated().map { index, count in
            genericLabels(count: count, role: role(forLine: index, of: lines.count))
        }

        var slots: [FormationSlot] = [
            FormationSlot(
                id: "GK",
                label: "GK",
                role: .goalkeeper,
                line: 0,
                indexInLine: 0,
                grid: "1:1",
                point: CGPoint(x: 0.5, y: 0.07)
            )
        ]

        var usedIDs: Set<String> = ["GK"]
        for (lineIndex, count) in lines.enumerated() {
            let lineLabels = labels.indices.contains(lineIndex) ? labels[lineIndex] : []
            let defaultRole = role(forLine: lineIndex, of: lines.count)
            for index in 0..<count {
                let rawLabel = lineLabels.indices.contains(index) ? lineLabels[index] : "\(defaultRole.abbreviation)\(index + 1)"
                let identifier = uniqueID(rawLabel, taken: &usedIDs)
                slots.append(
                    FormationSlot(
                        id: identifier,
                        label: rawLabel,
                        role: roleOverrides[rawLabel] ?? defaultRole,
                        line: lineIndex + 1,
                        indexInLine: index,
                        grid: "\(lineIndex + 2):\(index + 1)",
                        point: CGPoint(
                            x: horizontalPosition(index: index, count: count),
                            y: verticalPosition(lineIndex: lineIndex, lineCount: lines.count)
                        )
                    )
                )
            }
        }

        return Formation(name: name, lines: lines, slots: slots)
    }

    /// Positions for a lineup coming from the API, which supplies "row:column" grids.
    /// Falls back to the parsed formation when grids are missing or malformed.
    static func layoutPoints(grids: [String?], fallbackFormation: String?) -> [CGPoint] {
        let parsed = grids.map { gridCoordinate(from: $0) }

        if parsed.allSatisfy({ $0 != nil }) {
            let coordinates = parsed.compactMap { $0 }
            let rows = Set(coordinates.map(\.row)).sorted()
            let rowCount = rows.count
            var columnsByRow: [Int: [Int]] = [:]
            for coordinate in coordinates {
                columnsByRow[coordinate.row, default: []].append(coordinate.column)
            }
            for key in columnsByRow.keys {
                columnsByRow[key]?.sort()
            }

            return coordinates.map { coordinate in
                let rowIndex = rows.firstIndex(of: coordinate.row) ?? 0
                let columns = columnsByRow[coordinate.row] ?? [coordinate.column]
                let columnIndex = columns.firstIndex(of: coordinate.column) ?? 0
                let y: CGFloat = rowIndex == 0
                    ? 0.07
                    : verticalPosition(lineIndex: rowIndex - 1, lineCount: max(1, rowCount - 1))
                let x = rowIndex == 0 ? 0.5 : horizontalPosition(index: columnIndex, count: columns.count)
                return CGPoint(x: x, y: y)
            }
        }

        if let formation = parse(fallbackFormation) {
            let points = formation.slots.map(\.point)
            if points.count >= grids.count {
                return Array(points.prefix(grids.count))
            }
            return points + Array(repeating: CGPoint(x: 0.5, y: 0.5), count: grids.count - points.count)
        }

        // Last resort: spread everybody out in evenly sized rows.
        return grids.indices.map { index in
            let perRow = 4
            let row = index / perRow
            let column = index % perRow
            return CGPoint(
                x: horizontalPosition(index: column, count: perRow),
                y: verticalPosition(lineIndex: row, lineCount: max(1, (grids.count + perRow - 1) / perRow))
            )
        }
    }

    /// Parses "2:3" into its row and column.
    static func gridCoordinate(from grid: String?) -> (row: Int, column: Int)? {
        guard let grid, grid.isEmpty == false else { return nil }
        let parts = grid.split(separator: ":")
        guard parts.count == 2,
              let row = Int(parts[0].trimmingCharacters(in: .whitespaces)),
              let column = Int(parts[1].trimmingCharacters(in: .whitespaces)),
              row > 0, column > 0 else { return nil }
        return (row, column)
    }

    // MARK: - Re-assignment when the formation changes

    /// Moves existing picks onto a new formation, keeping everyone as close as possible
    /// to where they were and preferring slots that match their role.
    /// Players with nowhere to go come back in `unplaced`.
    static func remap<Value>(
        _ assignments: [String: Value],
        from old: Formation,
        to new: Formation,
        role: (Value) -> PitchRole?
    ) -> (assigned: [String: Value], unplaced: [Value]) {
        guard assignments.isEmpty == false else { return ([:], []) }

        // Keepers first, then back to front, so the spine settles before the wide players.
        let ordered = assignments.compactMap { key, value -> (slot: FormationSlot, value: Value)? in
            guard let slot = old.slot(id: key) else { return nil }
            return (slot, value)
        }
        .sorted { lhs, rhs in
            if lhs.slot.line != rhs.slot.line { return lhs.slot.line < rhs.slot.line }
            return lhs.slot.indexInLine < rhs.slot.indexInLine
        }

        // Anything whose old slot disappeared still deserves a place.
        let orphans = assignments.filter { old.slot(id: $0.key) == nil }.map(\.value)

        var available = new.slots
        var assigned: [String: Value] = [:]
        var unplaced: [Value] = orphans

        for entry in ordered {
            guard available.isEmpty == false else {
                unplaced.append(entry.value)
                continue
            }
            let playerRole = role(entry.value)
            let best = available.enumerated().min { lhs, rhs in
                cost(from: entry.slot, to: lhs.element, role: playerRole)
                    < cost(from: entry.slot, to: rhs.element, role: playerRole)
            }
            guard let best else {
                unplaced.append(entry.value)
                continue
            }
            assigned[best.element.id] = entry.value
            available.remove(at: best.offset)
        }

        return (assigned, unplaced)
    }

    /// The free slot that suits a role best — used when a player is picked without a target slot.
    static func bestSlot(for role: PitchRole?, in formation: Formation, occupied: Set<String>) -> FormationSlot? {
        let free = formation.slots.filter { occupied.contains($0.id) == false }
        guard free.isEmpty == false else { return nil }
        guard let role else { return free.first }
        return free.min { lhs, rhs in
            let lhsScore = role.compatibility(with: lhs.role)
            let rhsScore = role.compatibility(with: rhs.role)
            if lhsScore != rhsScore { return lhsScore > rhsScore }
            if lhs.line != rhs.line { return lhs.line < rhs.line }
            return lhs.indexInLine < rhs.indexInLine
        }
    }

    // MARK: - Geometry helpers

    static func horizontalPosition(index: Int, count: Int) -> CGFloat {
        guard count > 0 else { return 0.5 }
        guard count > 1 else { return 0.5 }
        let spread: CGFloat = count >= 5 ? 0.90 : 0.80
        let start = (1 - spread) / 2
        return start + spread * CGFloat(index) / CGFloat(count - 1)
    }

    static func verticalPosition(lineIndex: Int, lineCount: Int) -> CGFloat {
        let first: CGFloat = 0.24
        let last: CGFloat = 0.90
        guard lineCount > 1 else { return 0.62 }
        return first + (last - first) * CGFloat(lineIndex) / CGFloat(lineCount - 1)
    }

    // MARK: - Private

    private static func cost(from origin: FormationSlot, to destination: FormationSlot, role: PitchRole?) -> Double {
        let dx = Double(origin.point.x - destination.point.x)
        let dy = Double(origin.point.y - destination.point.y)
        let distance = (dx * dx + dy * dy).squareRoot()
        let roleScore = (role ?? origin.role).compatibility(with: destination.role)
        return distance + (1 - roleScore) * 1.5
    }

    private static func role(forLine index: Int, of lineCount: Int) -> PitchRole {
        if index == 0 { return .defender }
        if index == lineCount - 1 { return .attacker }
        return .midfielder
    }

    private static func genericLabels(count: Int, role: PitchRole) -> [String] {
        switch (role, count) {
        case (.defender, 2): ["LCB", "RCB"]
        case (.defender, 3): ["LCB", "CB", "RCB"]
        case (.defender, 4): ["LB", "LCB", "RCB", "RB"]
        case (.defender, 5): ["LWB", "LCB", "CB", "RCB", "RWB"]
        case (.midfielder, 1): ["CM"]
        case (.midfielder, 2): ["LCM", "RCM"]
        case (.midfielder, 3): ["LCM", "CM", "RCM"]
        case (.midfielder, 4): ["LM", "LCM", "RCM", "RM"]
        case (.midfielder, 5): ["LM", "LCM", "CM", "RCM", "RM"]
        case (.attacker, 1): ["ST"]
        case (.attacker, 2): ["LST", "RST"]
        case (.attacker, 3): ["LW", "ST", "RW"]
        case (.attacker, 4): ["LW", "LF", "RF", "RW"]
        default: (0..<count).map { "\(role.abbreviation)\($0 + 1)" }
        }
    }

    private static func uniqueID(_ label: String, taken: inout Set<String>) -> String {
        var candidate = label
        var suffix = 2
        while taken.contains(candidate) {
            candidate = "\(label)\(suffix)"
            suffix += 1
        }
        taken.insert(candidate)
        return candidate
    }
}
