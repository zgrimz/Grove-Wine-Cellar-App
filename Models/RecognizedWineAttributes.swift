import Foundation

struct RecognizedWineAttributes: Codable {
    let name: String
    let type: WineType
    let subTypes: Set<WineSubType>?
    let producer: String?
    let vintage: Int?
    let region: String?
    let varietal: String?
}
