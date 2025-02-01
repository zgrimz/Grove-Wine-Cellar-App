import SwiftUI
import UIKit

struct WineDetailView: View {
    let wine: Wine
    let onUpdate: (Wine) async -> Void
    @State private var image: UIImage?
    @State private var showingEditSheet = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .frame(maxWidth: .infinity)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(wine.name)
                        .font(.title)
                        .bold()
                    
                    if let producer = wine.producer {
                        Text(producer)
                            .font(.title2)
                    }
                    
                    HStack {
                        Badge(text: wine.type.rawValue, color: typeColor(for: wine.type))
                        
                        // Display all subtypes
                        ForEach(Array(wine.subTypes), id: \.self) { subType in
                            Badge(text: subType.rawValue, color: .gray)
                        }
                    }
                }
                .padding(.horizontal)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    if let vintage = wine.vintage {
                        DetailRow(label: "Vintage", value: String(vintage))
                    }
                    DetailRow(label: "Region", value: wine.region)
                    DetailRow(label: "Varietal", value: wine.varietal)
                }
                .padding(.horizontal)
                
                if wine.isArchived {
                    HStack {
                        Image(systemName: "archivebox.fill")
                        Text("Archived")
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(wine.isArchived ? "Unarchive" : "Archive") {
                    Task {
                        var updatedWine = wine
                        updatedWine.isArchived.toggle()
                        await onUpdate(updatedWine)
                        dismiss()
                    }
                }
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationView {
                WineFormView(
                    onSave: { updatedWine in
                        Task {
                            await onUpdate(updatedWine)
                            showingEditSheet = false
                        }
                    },
                    wine: wine
                )
            }
        }
        .onAppear {
            if let imagePath = wine.imagePath {
                image = ImageStorageService.shared.loadImage(fromPath: imagePath)
            }
        }
    }
    
    private func typeColor(for type: WineType) -> Color {
        switch type {
        case .red:
            return .red
        case .white:
            return .yellow
        case .rose:
            return .pink
        case .other:
            return .gray
        }
    }
}
