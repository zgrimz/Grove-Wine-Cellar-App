import CoreData

/// Maps ``Wine`` values to and from Core Data. Used only through ``WineStore``, which keeps the
/// one in-memory copy the screens read from.
final class WineRepository {
    enum RepositoryError: LocalizedError {
        case notFound

        var errorDescription: String? {
            switch self {
            case .notFound: return "This wine no longer exists. It may have been deleted."
            }
        }
    }

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchWines() throws -> [Wine] {
        let request = WineEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WineEntity.dateAdded, ascending: false)]
        return try context.fetch(request).compactMap(Self.wine(from:))
    }

    func insert(_ wine: Wine) throws {
        let entity = WineEntity(context: context)
        entity.id = wine.id
        entity.dateAdded = wine.dateAdded
        apply(wine, to: entity)
        try save()
    }

    /// Updates an existing wine. Deliberately not an upsert: saving a stale copy of a wine that was
    /// deleted elsewhere used to quietly re-create it.
    func update(_ wine: Wine) throws {
        guard let entity = try entity(id: wine.id) else { throw RepositoryError.notFound }
        apply(wine, to: entity)
        try save()
    }

    func delete(id: UUID) throws {
        guard let entity = try entity(id: id) else { return }
        context.delete(entity)
        try save()
    }

    // MARK: Private

    private func entity(id: UUID) throws -> WineEntity? {
        let request = WineEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    /// A failed save leaves its changes pending in the context, where they would ride along with
    /// the next unrelated save — so undo them before reporting the failure.
    private func save() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private func apply(_ wine: Wine, to entity: WineEntity) {
        entity.name = wine.name
        entity.color = wine.color.rawValue
        entity.style = wine.style.rawValue
        // Stored as a comma-separated string.
        entity.sweetness = wine.sweetness.map(\.rawValue).joined(separator: ",")
        entity.producer = wine.producer
        entity.notes = wine.notes
        // Int16 with 0 meaning "no vintage". `Int16(exactly:)`, not `Int16(_:)`, which traps on
        // anything over 32767; the form only lets real years through, so this is a backstop.
        entity.vintage = wine.vintage.flatMap { Int16(exactly: $0) } ?? 0
        entity.region = wine.region
        entity.varietal = wine.varietal
        entity.imagePath = wine.imagePath
        entity.isArchived = wine.isArchived
    }

    private static func wine(from entity: WineEntity) -> Wine? {
        guard let id = entity.id,
              let name = entity.name,
              let color = entity.color.flatMap(WineColor.init(rawValue:)),
              let style = entity.style.flatMap(WineStyle.init(rawValue:)) else {
            return nil
        }
        let sweetness = Set((entity.sweetness?.split(separator: ",") ?? [])
            .compactMap { WineSweetness(rawValue: String($0)) })

        return Wine(
            id: id,
            name: name,
            color: color,
            style: style,
            sweetness: sweetness,
            producer: entity.producer,
            vintage: entity.vintage == 0 ? nil : Int(entity.vintage),
            region: entity.region,
            varietal: entity.varietal,
            notes: entity.notes,
            imagePath: entity.imagePath,
            dateAdded: entity.dateAdded ?? Date(),
            isArchived: entity.isArchived
        )
    }
}
