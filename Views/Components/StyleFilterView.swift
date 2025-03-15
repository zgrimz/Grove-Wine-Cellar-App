import SwiftUI
import Foundation

struct StyleFilterView: View {
    @Binding var selectedStyle: WineStyle?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    text: "All",
                    isSelected: selectedStyle == nil,
                    action: { selectedStyle = nil }
                )
                
                ForEach(WineStyle.allCases, id: \.self) { style in
                    FilterChip(
                        text: style.rawValue,
                        isSelected: selectedStyle == style,
                        action: { selectedStyle = style }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}