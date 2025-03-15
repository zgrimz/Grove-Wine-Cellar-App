import CoreData
import SwiftUI

class WineRepository: ObservableObject {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func saveWine(_ wine: Wine) throws {
        // Check if marked for deletion
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
        entity.color = wine.color.rawValue
        entity.style = wine.style.rawValue
        // Convert sweetness to a string for CoreData storage
        entity.sweetness = Array(wine.sweetness).map { $0.rawValue }.joined(separator: ",")
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
                  let colorString = entity.color,
                  let color = WineColor(rawValue: colorString),
                  let styleString = entity.style,
                  let style = WineStyle(rawValue: styleString) else {
                return nil
            }
            
            // Convert stored comma-separated string back to Set<WineSweetness>
            let sweetness = Set((entity.sweetness?.split(separator: ",") ?? [])
                .compactMap { WineSweetness(rawValue: String($0)) })
            
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
                color: color,
                style: style,
                sweetness: sweetness,
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