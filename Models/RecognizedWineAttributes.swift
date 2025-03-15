import Foundation

struct RecognizedWineAttributes: Codable {
    let name: String
    let color: WineColor
    let style: WineStyle
    let sweetness: Set<WineSweetness>?
    let producer: String?
    let vintage: Int?
    let region: String?
    let varietal: String?
}