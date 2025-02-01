import CoreData
import SwiftUI

class WineRepository: ObservableObject {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func saveWine(_ wine: Wine) throws {
        // Add at start of function:
        if wine.markedForDeletion {
            try deleteWine(id: wine.id)
            return
        }
        
        let request = NSFetchRequest<WineEntity>(entityName: "WineEntity")
        request.predicate = NSPredicate(format: "id == %@", wine.id as CVarArg)
        
        let entity: WineEntity
        
        if let existingEntity = try context.fetch(request).first {
            entity = existingEntity
        } else {
            entity = WineEntity(context: context)
            entity.id = wine.id
            entity.dateAdded = wine.dateAdded
        }
        
        // Update properties
        entity.name = wine.name
        entity.type = wine.type.rawValue
        // Convert subTypes to a string for CoreData storage
        entity.subTypes = Array(wine.subTypes).map { $0.rawValue }.joined(separator: ",")
        entity.producer = wine.producer
        // Store vintage as Int16
        if let vintage = wine.vintage {
            entity.vintage = Int16(vintage)
        } else {
            entity.vintage = 0  // or some sentinel value like -1
        }
        entity.region = wine.region
        entity.varietal = wine.varietal
        entity.imagePath = wine.imagePath
        entity.isArchived = wine.isArchived
        
        try context.save()
    }
    
    func fetchWines(includeArchived: Bool = false) throws -> [Wine] {
        let request = NSFetchRequest<WineEntity>(entityName: "WineEntity")
        if !includeArchived {
            request.predicate = NSPredicate(format: "isArchived == NO")
        }
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WineEntity.dateAdded, ascending: false)]
        
        let entities = try context.fetch(request)
        return entities.compactMap { entity in
            guard let id = entity.id,
                  let name = entity.name,
                  let typeString = entity.type,
                  let type = WineType(rawValue: typeString) else {
                return nil
            }
            
            // Convert stored comma-separated string back to Set<WineSubType>
            let subTypes = Set((entity.subTypes?.split(separator: ",") ?? [])
                .compactMap { WineSubType(rawValue: String($0)) })
            
            // Convert vintage from Int16 to Int
            let vintage: Int?
            if entity.vintage != 0 {  // assuming 0 is our sentinel value
                vintage = Int(entity.vintage)
            } else {
                vintage = nil
            }
            
            // Create the Wine object with all required fields
            return Wine(
                id: id,
                name: name,
                type: type,
                subTypes: subTypes,
                producer: entity.producer,
                vintage: vintage,
                region: entity.region,
                varietal: entity.varietal,
                imagePath: entity.imagePath,
                dateAdded: entity.dateAdded ?? Date(),
                isArchived: entity.isArchived
            )
        }
    }
    
    func deleteWine(id: UUID) throws {
        let request = NSFetchRequest<WineEntity>(entityName: "WineEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        let entities = try context.fetch(request)
        entities.forEach(context.delete)
        try context.save()
    }

    func toggleArchived(_ wine: Wine) throws {
        let request = NSFetchRequest<WineEntity>(entityName: "WineEntity")
        request.predicate = NSPredicate(format: "id == %@", wine.id as CVarArg)
        
        if let entity = try context.fetch(request).first {
            entity.isArchived = !entity.isArchived
            try context.save()
        }
    }
}
