import SwiftUI

struct WineTypeCard: View {
    let title: String
    let color: Color?
    let isSelected: Bool
    let action: () -> Void
    
    init(title: String, color: Color? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.color = color
        self.isSelected = isSelected
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : (color ?? .secondary))
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? (color ?? Color.accentColor) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? (color ?? Color.accentColor) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var iconName: String {
        switch title.lowercased() {
        case "any":
            return "wineglass"
        case "red":
            return "wineglass.fill"
        case "white":
            return "wineglass"
        case "rosé", "rose":
            return "wineglass.fill"
        case "orange":
            return "wineglass.fill"
        case "other":
            return "questionmark.circle"
        default:
            return "wineglass"
        }
    }
}

#Preview {
    HStack {
        WineTypeCard(title: "Any", isSelected: true) { }
        WineTypeCard(title: "Red", color: .red, isSelected: false) { }
    }
    .padding()
}