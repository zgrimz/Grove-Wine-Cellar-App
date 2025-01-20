import SwiftUI

struct TypeFilterView: View {
    @Binding var selectedType: WineType?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    text: "All",
                    isSelected: selectedType == nil,
                    action: { selectedType = nil }
                )
                
                ForEach(WineType.allCases, id: \.self) { type in
                    FilterChip(
                        text: type.rawValue,
                        isSelected: selectedType == type,
                        action: { selectedType = type }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}
