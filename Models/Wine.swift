import Foundation

struct Wine: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: WineType
    var subTypes: Set<WineSubType>
    var producer: String?
    var vintage: Int?
    var region: String?
    var varietal: String?
    var imagePath: String?
    var dateAdded: Date
    var isArchived: Bool 
    var markedForDeletion: Bool = false // Add this property to Wine struct
    
    init(
        id: UUID = UUID(),
        name: String,
        type: WineType,
        subTypes: Set<WineSubType> = [],
        producer: String? = nil,
        vintage: Int? = nil,
        region: String? = nil,
        varietal: String? = nil,
        imagePath: String? = nil,
        dateAdded: Date = Date(),
        isArchived: Bool = false,
        markedForDeletion: Bool = false // Add this property to Wine struct
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.subTypes = subTypes
        self.producer = producer
        self.vintage = vintage
        self.region = region
        self.varietal = varietal
        self.imagePath = imagePath
        self.dateAdded = dateAdded
        self.isArchived = isArchived
        self.markedForDeletion = markedForDeletion // Add this property to Wine struct
    }
}

extension Wine {
    func deleteFlag() -> Wine {
        var copy = self
        copy.isArchived = true // Mark as archived first
        copy.markedForDeletion = true // Add this property to Wine struct
        return copy
    }
}
