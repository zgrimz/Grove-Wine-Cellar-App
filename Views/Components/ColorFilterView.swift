import SwiftUI
import Foundation

struct ColorFilterView: View {
    @Binding var selectedColor: WineColor?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    text: "All",
                    isSelected: selectedColor == nil,
                    action: { selectedColor = nil }
                )
                
                ForEach([WineColor.red, WineColor.white, WineColor.rose], id: \.self) { color in
                    FilterChip(
                        text: color.rawValue,
                        isSelected: selectedColor == color,
                        action: { selectedColor = color }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}