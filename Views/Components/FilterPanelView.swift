import SwiftUI

struct FilterPanelView: View {
    @Binding var selectedColor: WineColor?
    @Binding var selectedStyle: WineStyle?
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Wine Color")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        FilterChip(
                            text: "All",
                            isSelected: selectedColor == nil,
                            action: { selectedColor = nil }
                        )
                        
                        ForEach(WineColor.allCases, id: \.self) { color in
                            FilterChip(
                                text: color.rawValue,
                                isSelected: selectedColor == color,
                                action: { selectedColor = color }
                            )
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Wine Style")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
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
                }
                
                Spacer()
                
                HStack {
                    Button("Clear All") {
                        selectedColor = nil
                        selectedStyle = nil
                    }
                    .foregroundColor(.red)
                    
                    Spacer()
                    
                    Button("Done") {
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
                .padding(.bottom)
            }
            .padding()
            .navigationTitle("Filter Options")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                isPresented = false
            })
        }
    }
}

#Preview {
    FilterPanelView(
        selectedColor: .constant(nil),
        selectedStyle: .constant(nil),
        isPresented: .constant(true)
    )
}