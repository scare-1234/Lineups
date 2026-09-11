import CoreData
import Foundation

/// Core Data stack for saved lineups, favourite teams and the offline caches.
///
/// The model is built in code rather than shipped as a `.xcdatamodeld` bundle: it keeps
/// the schema reviewable in a pull request and removes any codegen ambiguity.
/// Lightweight migration is enabled, so adding attributes later stays safe.
final class CoreDataStack {

    static let shared = CoreDataStack()

    let container: NSPersistentContainer

    /// Reads happen on the main context, writes on background contexts.
    var viewContext: NSManagedObjectContext { container.viewContext }

    private(set) var loadError: Error?

    /// Built once per process: creating the same entities twice makes Core Data complain
    /// that several entity descriptions claim the same `NSManagedObject` subclass.
    static let sharedModel: NSManagedObjectModel = makeModel()

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "LineupLab", managedObjectModel: CoreDataStack.sharedModel)

        if let description = container.persistentStoreDescriptions.first {
            if inMemory {
                description.url = URL(fileURLWithPath: "/dev/null")
                description.type = NSInMemoryStoreType
            }
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }

        var capturedError: Error?
        container.loadPersistentStores { _, error in
            capturedError = error
        }
        loadError = capturedError

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        container.viewContext.undoManager = nil
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.automaticallyMergesChangesFromParent = true
        return context
    }

    /// Runs work on a background context and hands the result back to the caller.
    func perform<T: Sendable>(_ block: @escaping @Sendable (NSManagedObjectContext) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            container.performBackgroundTask { context in
                context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
                do {
                    let value = try block(context)
                    continuation.resume(returning: value)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Model

    enum EntityName {
        static let customLineup = "CustomLineup"
        static let customLineupPlayer = "CustomLineupPlayer"
        static let favoriteTeam = "FavoriteTeam"
        static let cachedPlayer = "CachedPlayer"
        static let cachedFixture = "CachedFixture"
    }

    static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // CustomLineup
        let lineup = NSEntityDescription()
        lineup.name = EntityName.customLineup
        lineup.managedObjectClassName = NSStringFromClass(CDCustomLineup.self)
        lineup.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("name", .stringAttributeType),
            attribute("formation", .stringAttributeType),
            attribute("createdAt", .dateAttributeType),
            attribute("updatedAt", .dateAttributeType)
        ]

        // CustomLineupPlayer
        let player = NSEntityDescription()
        player.name = EntityName.customLineupPlayer
        player.managedObjectClassName = NSStringFromClass(CDCustomLineupPlayer.self)
        player.properties = [
            attribute("playerId", .integer64AttributeType, optional: false, defaultValue: 0),
            attribute("playerName", .stringAttributeType),
            attribute("playerNationality", .stringAttributeType),
            attribute("playerAge", .integer32AttributeType, optional: false, defaultValue: 0),
            attribute("playerRating", .doubleAttributeType),
            attribute("positionSlot", .stringAttributeType),
            attribute("formationPosition", .stringAttributeType),
            attribute("playerPhoto", .stringAttributeType),
            attribute("playerClub", .stringAttributeType),
            attribute("playerPosition", .stringAttributeType),
            attribute("slotOrder", .integer16AttributeType, optional: false, defaultValue: 0)
        ]

        // CustomLineup <->> CustomLineupPlayer
        let players = NSRelationshipDescription()
        players.name = "players"
        players.destinationEntity = player
        players.minCount = 0
        players.maxCount = 0 // to-many
        players.deleteRule = .cascadeDeleteRule
        players.isOptional = true

        let owner = NSRelationshipDescription()
        owner.name = "lineup"
        owner.destinationEntity = lineup
        owner.minCount = 0
        owner.maxCount = 1
        owner.deleteRule = .nullifyDeleteRule
        owner.isOptional = true

        players.inverseRelationship = owner
        owner.inverseRelationship = players
        lineup.properties.append(players)
        player.properties.append(owner)

        // FavoriteTeam
        let favorite = NSEntityDescription()
        favorite.name = EntityName.favoriteTeam
        favorite.managedObjectClassName = NSStringFromClass(CDFavoriteTeam.self)
        favorite.properties = [
            attribute("teamId", .integer64AttributeType, optional: false, defaultValue: 0),
            attribute("name", .stringAttributeType),
            attribute("logo", .stringAttributeType),
            attribute("country", .stringAttributeType),
            attribute("addedAt", .dateAttributeType)
        ]

        // CachedPlayer
        let cachedPlayer = NSEntityDescription()
        cachedPlayer.name = EntityName.cachedPlayer
        cachedPlayer.managedObjectClassName = NSStringFromClass(CDCachedPlayer.self)
        cachedPlayer.properties = [
            attribute("playerId", .integer64AttributeType, optional: false, defaultValue: 0),
            attribute("payload", .binaryDataAttributeType),
            attribute("updatedAt", .dateAttributeType)
        ]

        // CachedFixture
        let cachedFixture = NSEntityDescription()
        cachedFixture.name = EntityName.cachedFixture
        cachedFixture.managedObjectClassName = NSStringFromClass(CDCachedFixture.self)
        cachedFixture.properties = [
            attribute("dayKey", .stringAttributeType),
            attribute("payload", .binaryDataAttributeType),
            attribute("updatedAt", .dateAttributeType)
        ]

        model.entities = [lineup, player, favorite, cachedPlayer, cachedFixture]
        return model
    }

    private static func attribute(
        _ name: String,
        _ type: NSAttributeType,
        optional: Bool = true,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        attribute.defaultValue = defaultValue
        return attribute
    }
}
