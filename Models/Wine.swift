import Foundation

struct Wine: Identifiable, Codable {
    let id: UUID
    var name: String
    var color: WineColor
    var style: WineStyle
    var sweetness: Set<WineSweetness>
    var producer: String?
    var vintage: Int?
    var region: String?
    var varietal: String?
    var notes: String?
    var imagePath: String?
    var dateAdded: Date
    var isArchived: Bool 
    var markedForDeletion: Bool = false
    
    init(
        id: UUID = UUID(),
        name: String,
        color: WineColor,
        style: WineStyle,
        sweetness: Set<WineSweetness> = [],
        producer: String? = nil,
        vintage: Int? = nil,
        region: String? = nil,
        varietal: String? = nil,
        notes: String? = nil,
        imagePath: String? = nil,
        dateAdded: Date = Date(),
        isArchived: Bool = false,
        markedForDeletion: Bool = false
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.style = style
        self.sweetness = sweetness
        self.producer = producer
        self.vintage = vintage
        self.region = region
        self.varietal = varietal
        self.notes = notes
        self.imagePath = imagePath
        self.dateAdded = dateAdded
        self.isArchived = isArchived
        self.markedForDeletion = markedForDeletion
    }
}

extension Wine {
    func deleteFlag() -> Wine {
        var copy = self
        copy.isArchived = true
        copy.markedForDeletion = true
        return copy
    }
}