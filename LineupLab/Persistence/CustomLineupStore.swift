import CoreData
import Foundation
import Observation

/// Repository over Core Data for everything the app persists:
/// saved lineups, favourite teams and the offline caches for players and fixtures.
@MainActor
@Observable
final class CustomLineupStore {

    private(set) var lineups: [CustomLineup] = []
    private(set) var favoriteTeams: [Team] = []
    private(set) var lastError: String?

    private let stack: CoreDataStack
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(stack: CoreDataStack = .shared) {
        self.stack = stack
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    var favoriteTeamIDs: Set<Int> { Set(favoriteTeams.map(\.id)) }

    // MARK: - Lineups

    func loadLineups() async {
        do {
            lineups = try await stack.perform { context in
                let request = CDCustomLineup.makeFetchRequest()
                request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
                return try context.fetch(request).compactMap { $0.toValue() }
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    @discardableResult
    func save(_ lineup: CustomLineup) async -> Bool {
        let toSave = CustomLineup(
            id: lineup.id,
            name: lineup.name,
            formation: lineup.formation,
            players: lineup.players,
            createdAt: lineup.createdAt,
            updatedAt: Date()
        )
        do {
            try await stack.perform { context in
                let object = try Self.findOrCreateLineup(id: toSave.id, in: context)
                object.id = toSave.id
                object.name = toSave.name
                object.formation = toSave.formation
                object.createdAt = toSave.createdAt
                object.updatedAt = toSave.updatedAt

                // Replace the squad wholesale: lineups are small and this keeps slots consistent.
                for existing in object.playerObjects {
                    context.delete(existing)
                }
                let slotOrder = FormationParser.parse(toSave.formation)?.slots.map(\.id) ?? []
                for player in toSave.players {
                    let entity = CDCustomLineupPlayer(context: context)
                    let order = slotOrder.firstIndex(of: player.positionSlot) ?? Int.max
                    entity.apply(player, order: order == Int.max ? toSave.players.count : order)
                    entity.lineup = object
                }
                if context.hasChanges {
                    try context.save()
                }
            }
            await loadLineups()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func delete(id: UUID) async {
        do {
            try await stack.perform { context in
                let request = CDCustomLineup.makeFetchRequest()
                request.predicate = NSPredicate(format: "id == %@", id as NSUUID)
                for object in try context.fetch(request) {
                    context.delete(object)
                }
                if context.hasChanges {
                    try context.save()
                }
            }
            lineups.removeAll { $0.id == id }
        } catch {
            lastError = error.localizedDescription
        }
    }

    @discardableResult
    func duplicate(_ lineup: CustomLineup) async -> CustomLineup {
        let copy = CustomLineup(
            id: UUID(),
            name: L10n.Builder.copyName(lineup.name),
            formation: lineup.formation,
            players: lineup.players,
            createdAt: Date(),
            updatedAt: Date()
        )
        await save(copy)
        return copy
    }

    func lineup(id: UUID) -> CustomLineup? {
        lineups.first { $0.id == id }
    }

    // MARK: - Favourite teams

    func loadFavorites() async {
        do {
            favoriteTeams = try await stack.perform { context in
                let request = CDFavoriteTeam.makeFetchRequest()
                request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
                return try context.fetch(request).map { $0.toValue() }
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func toggleFavorite(_ team: Team) async {
        let isFavorite = favoriteTeamIDs.contains(team.id)
        do {
            try await stack.perform { context in
                let request = CDFavoriteTeam.makeFetchRequest()
                request.predicate = NSPredicate(format: "teamId == %lld", Int64(team.id))
                let existing = try context.fetch(request)
                if isFavorite {
                    for object in existing { context.delete(object) }
                } else if existing.isEmpty {
                    let object = CDFavoriteTeam(context: context)
                    object.teamId = Int64(team.id)
                    object.name = team.name
                    object.logo = team.logo?.absoluteString
                    object.country = team.country
                    object.addedAt = Date()
                }
                if context.hasChanges {
                    try context.save()
                }
            }
            await loadFavorites()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Offline caches

    /// Cached player profiles cut down on API calls, which matter on a 100-a-day plan.
    func cachePlayer(_ player: Player) async {
        guard let data = try? encoder.encode(player) else { return }
        try? await stack.perform { context in
            let request = CDCachedPlayer.makeFetchRequest()
            request.predicate = NSPredicate(format: "playerId == %lld", Int64(player.id))
            let object = try context.fetch(request).first ?? CDCachedPlayer(context: context)
            object.playerId = Int64(player.id)
            object.payload = data
            object.updatedAt = Date()
            if context.hasChanges {
                try context.save()
            }
        }
    }

    func cachedPlayer(id: Int, maxAge: TimeInterval = AppConstants.referenceCacheTTL) async -> Player? {
        let payload: Data? = try? await stack.perform { context in
            let request = CDCachedPlayer.makeFetchRequest()
            request.predicate = NSPredicate(format: "playerId == %lld", Int64(id))
            request.fetchLimit = 1
            guard let object = try context.fetch(request).first,
                  let updatedAt = object.updatedAt,
                  Date().timeIntervalSince(updatedAt) <= maxAge else { return nil }
            return object.payload
        }
        guard let payload else { return nil }
        return try? decoder.decode(Player.self, from: payload)
    }

    func cacheFixtures(_ fixtures: [Fixture], dayKey: String) async {
        guard let data = try? encoder.encode(fixtures) else { return }
        try? await stack.perform { context in
            let request = CDCachedFixture.makeFetchRequest()
            request.predicate = NSPredicate(format: "dayKey == %@", dayKey)
            let object = try context.fetch(request).first ?? CDCachedFixture(context: context)
            object.dayKey = dayKey
            object.payload = data
            object.updatedAt = Date()
            if context.hasChanges {
                try context.save()
            }
        }
    }

    func cachedFixtures(dayKey: String) async -> [Fixture] {
        let payload: Data? = try? await stack.perform { context in
            let request = CDCachedFixture.makeFetchRequest()
            request.predicate = NSPredicate(format: "dayKey == %@", dayKey)
            request.fetchLimit = 1
            return try context.fetch(request).first?.payload
        }
        guard let payload else { return [] }
        return (try? decoder.decode([Fixture].self, from: payload)) ?? []
    }

    // MARK: - Helpers

    private static func findOrCreateLineup(id: UUID, in context: NSManagedObjectContext) throws -> CDCustomLineup {
        let request = CDCustomLineup.makeFetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as NSUUID)
        request.fetchLimit = 1
        if let existing = try context.fetch(request).first { return existing }
        return CDCustomLineup(context: context)
    }
}
