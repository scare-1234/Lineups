import CoreData
import Foundation

@objc(CDCustomLineup)
final class CDCustomLineup: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var name: String?
    @NSManaged var formation: String?
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
    @NSManaged var players: NSSet?

    @nonobjc static func makeFetchRequest() -> NSFetchRequest<CDCustomLineup> {
        NSFetchRequest<CDCustomLineup>(entityName: CoreDataStack.EntityName.customLineup)
    }

    var playerObjects: [CDCustomLineupPlayer] {
        let set = players as? Set<CDCustomLineupPlayer> ?? []
        return set.sorted { $0.slotOrder < $1.slotOrder }
    }

    /// Converts the managed object into the value type the UI uses.
    func toValue() -> CustomLineup? {
        guard let id else { return nil }
        return CustomLineup(
            id: id,
            name: name ?? "",
            formation: formation ?? FormationParser.defaultFormationName,
            players: playerObjects.compactMap { $0.toValue() },
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date()
        )
    }
}

@objc(CDCustomLineupPlayer)
final class CDCustomLineupPlayer: NSManagedObject {
    @NSManaged var playerId: Int64
    @NSManaged var playerName: String?
    @NSManaged var playerNationality: String?
    @NSManaged var playerAge: Int32
    @NSManaged var playerRating: NSNumber?
    @NSManaged var positionSlot: String?
    @NSManaged var formationPosition: String?
    @NSManaged var playerPhoto: String?
    @NSManaged var playerClub: String?
    @NSManaged var playerPosition: String?
    @NSManaged var slotOrder: Int16
    @NSManaged var lineup: CDCustomLineup?

    @nonobjc static func makeFetchRequest() -> NSFetchRequest<CDCustomLineupPlayer> {
        NSFetchRequest<CDCustomLineupPlayer>(entityName: CoreDataStack.EntityName.customLineupPlayer)
    }

    func toValue() -> CustomLineupPlayer? {
        guard let positionSlot else { return nil }
        return CustomLineupPlayer(
            playerId: Int(playerId),
            playerName: playerName ?? "",
            playerNationality: playerNationality ?? "",
            playerAge: Int(playerAge),
            playerRating: playerRating?.doubleValue,
            positionSlot: positionSlot,
            formationPosition: formationPosition ?? "",
            playerPhoto: playerPhoto.flatMap(URL.init(string:)),
            playerClub: playerClub,
            playerPosition: playerPosition
        )
    }

    func apply(_ value: CustomLineupPlayer, order: Int) {
        playerId = Int64(value.playerId)
        playerName = value.playerName
        playerNationality = value.playerNationality
        playerAge = Int32(value.playerAge)
        playerRating = value.playerRating.map { NSNumber(value: $0) }
        positionSlot = value.positionSlot
        formationPosition = value.formationPosition
        playerPhoto = value.playerPhoto?.absoluteString
        playerClub = value.playerClub
        playerPosition = value.playerPosition
        slotOrder = Int16(clamping: order)
    }
}

@objc(CDFavoriteTeam)
final class CDFavoriteTeam: NSManagedObject {
    @NSManaged var teamId: Int64
    @NSManaged var name: String?
    @NSManaged var logo: String?
    @NSManaged var country: String?
    @NSManaged var addedAt: Date?

    @nonobjc static func makeFetchRequest() -> NSFetchRequest<CDFavoriteTeam> {
        NSFetchRequest<CDFavoriteTeam>(entityName: CoreDataStack.EntityName.favoriteTeam)
    }

    func toValue() -> Team {
        Team(
            id: Int(teamId),
            name: name ?? "",
            logo: logo.flatMap(URL.init(string:)),
            country: country
        )
    }
}

@objc(CDCachedPlayer)
final class CDCachedPlayer: NSManagedObject {
    @NSManaged var playerId: Int64
    @NSManaged var payload: Data?
    @NSManaged var updatedAt: Date?

    @nonobjc static func makeFetchRequest() -> NSFetchRequest<CDCachedPlayer> {
        NSFetchRequest<CDCachedPlayer>(entityName: CoreDataStack.EntityName.cachedPlayer)
    }
}

@objc(CDCachedFixture)
final class CDCachedFixture: NSManagedObject {
    @NSManaged var dayKey: String?
    @NSManaged var payload: Data?
    @NSManaged var updatedAt: Date?

    @nonobjc static func makeFetchRequest() -> NSFetchRequest<CDCachedFixture> {
        NSFetchRequest<CDCachedFixture>(entityName: CoreDataStack.EntityName.cachedFixture)
    }
}
