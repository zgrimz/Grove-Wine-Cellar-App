import SwiftUI

extension Color {
    static func colorFor(_ wineColor: WineColor) -> Color {
        switch wineColor {
        case .red:
            return Color(red: 0.7, green: 0.2, blue: 0.2)
        case .white:
            return Color(red: 0.9, green: 0.9, blue: 0.7)
        case .rose:
            return Color(red: 0.9, green: 0.6, blue: 0.7)
        case .orange:
            return Color.orange
        case .other:
            return Color.secondary
        }
    }
}

func colorFor(_ wineColor: WineColor) -> Color {
    return Color.colorFor(wineColor)
}