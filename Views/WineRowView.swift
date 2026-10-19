import SwiftUI
import UIKit
import Foundation

struct WineRowView: View {
    let wine: Wine
    @Environment(\.displayScale) private var displayScale
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
                            .foregroundStyle(.secondary)
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
                            .foregroundStyle(.secondary)
                        Text(producer)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Enhanced badges with better spacing
                HStack(spacing: 8) {
                    // Color badge
                    Text(wine.color.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(wine.color.tint.opacity(0.15))
                        .foregroundStyle(wine.color.tint)
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
        // Keyed on the path: rows keep their state by wine id, so onAppear left a replaced photo stale.
        .task(id: wine.imagePath) {
            guard let imagePath = wine.imagePath else { image = nil; return }
            image = await ImageStorageService.shared.loadImage(fromPath: imagePath, maxPixelLength: 80 * displayScale)
        }
    }
}
