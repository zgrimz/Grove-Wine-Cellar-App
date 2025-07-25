import SwiftUI
import UIKit
import Foundation

struct WineRowView: View {
    let wine: Wine
    @State private var image: UIImage?
    
    var body: some View {
        HStack(spacing: 16) {
            // Larger, more prominent image
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "wineglass.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // Wine name with better typography
                Text(wine.name)
                    .font(.headline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                // Producer with icon
                if let producer = wine.producer {
                    HStack(spacing: 4) {
                        Image(systemName: "building.2")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(producer)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Enhanced badges with better spacing
                HStack(spacing: 8) {
                    // Color badge
                    Text(wine.color.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(colorFor(wine.color).opacity(0.15))
                        .foregroundColor(colorFor(wine.color))
                        .clipShape(Capsule())
                    
                    // Vintage with prominent display
                    if let vintage = wine.vintage {
                        Text(String(vintage))
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            if let imagePath = wine.imagePath {
                image = ImageStorageService.shared.loadImage(fromPath: imagePath)
            }
        }
    }
    
    private func colorFor(_ wineColor: WineColor) -> Color {
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