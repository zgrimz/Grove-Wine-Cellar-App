import SwiftUI
import UIKit

/// The app's one palette for wine colors. Before this, the list, the detail screen and the pairing
/// screen each had their own `colorFor`, and the detail screen's disagreed with the other two.
extension WineColor {
    /// Used as text and icon color on light tints of itself, so every value keeps a readable
    /// contrast in both appearances. The old White (pale straw) was about 1.3:1 against white.
    var tint: Color {
        switch self {
        case .red: Color(light: (0.70, 0.20, 0.20), dark: (0.90, 0.40, 0.40))
        case .white: Color(light: (0.55, 0.43, 0.08), dark: (0.92, 0.86, 0.60))
        case .rose: Color(light: (0.75, 0.30, 0.45), dark: (0.95, 0.65, 0.75))
        case .orange: .orange
        case .other: .secondary
        }
    }

    var symbolName: String {
        switch self {
        case .red, .rose, .orange: "wineglass.fill"
        case .white: "wineglass"
        case .other: "questionmark.circle"
        }
    }
}

private extension Color {
    init(light: (Double, Double, Double), dark: (Double, Double, Double)) {
        self.init(uiColor: UIColor { traits in
            let (r, g, b) = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: r, green: g, blue: b, alpha: 1)
        })
    }
}
