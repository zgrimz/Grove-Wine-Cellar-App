import SwiftUI

/// A selectable card for a wine color, or for "Any" when `wineColor` is nil.
struct WineTypeCard: View {
    let wineColor: WineColor?
    let isSelected: Bool
    let action: () -> Void

    private var title: String { wineColor?.rawValue ?? "Any" }
    private var tint: Color { wineColor?.tint ?? .accentColor }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: wineColor?.symbolName ?? "wineglass")
                    .font(.title2)
                    .foregroundStyle(tint)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundStyle(isSelected ? tint : Color.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? tint.opacity(0.15) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? tint : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        // Selection is otherwise shown by color alone.
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    HStack {
        WineTypeCard(wineColor: nil, isSelected: true) { }
        WineTypeCard(wineColor: .red, isSelected: false) { }
        WineTypeCard(wineColor: .white, isSelected: true) { }
    }
    .padding()
}
