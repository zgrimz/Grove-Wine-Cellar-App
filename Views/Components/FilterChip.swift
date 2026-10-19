import SwiftUI

struct FilterChip: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor :
                              Color.secondary.opacity(0.2))
                )
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        // Selection is otherwise shown by color alone.
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
