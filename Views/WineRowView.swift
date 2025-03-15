import SwiftUI
import UIKit
import Foundation

struct WineRowView: View {
    let wine: Wine
    @State private var image: UIImage?
    
    var body: some View {
        HStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "wine.bottle")
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(wine.name)
                    .font(.headline)
                
                if let producer = wine.producer {
                    Text(producer)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(wine.color.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(colorFor(wine.color).opacity(0.2))
                        )
                        .foregroundColor(colorFor(wine.color))
                    
                    Text(wine.style.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                        )
                        .foregroundColor(.gray)
                    
                    if let vintage = wine.vintage {
                        Text(String(vintage))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .onAppear {
            if let imagePath = wine.imagePath {
                image = ImageStorageService.shared.loadImage(fromPath: imagePath)
            }
        }
    }
    
    private func colorFor(_ color: WineColor) -> Color {
        switch color {
        case .red:
            return .red
        case .white:
            return .yellow
        case .rose:
            return .pink
        case .orange:
            return .orange
        case .other:
            return .gray
        }
    }
}