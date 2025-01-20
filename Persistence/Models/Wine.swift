import Foundation

struct Wine: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: WineType
    var subType: WineSubType?
    var producer: String?
    var vintage: String?
    var region: String?
    var varietal: String?
    var imagePath: String?
    var dateAdded: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        type: WineType,
        subType: WineSubType? = nil,
        producer: String? = nil,
        vintage: String? = nil,
        region: String? = nil,
        varietal: String? = nil,
        imagePath: String? = nil,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.subType = subType
        self.producer = producer
        self.vintage = vintage
        self.region = region
        self.varietal = varietal
        self.imagePath = imagePath
        self.dateAdded = dateAdded
    }
}
