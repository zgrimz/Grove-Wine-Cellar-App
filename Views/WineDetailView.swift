import SwiftUI
import UIKit

struct WineDetailView: View {
    let wine: Wine
    let onUpdate: (Wine) async -> Void
    @State private var image: UIImage?
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
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
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button(action: {
                        Task {
                            var updatedWine = wine
                            updatedWine.isArchived.toggle()
                            await onUpdate(updatedWine)
                            dismiss()
                        }
                    }) {
                        HStack {
                            Image(systemName: wine.isArchived ? "archivebox.circle.fill" : "archivebox")
                            Text(wine.isArchived ? "Unarchive Wine" : "Archive Wine")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .cornerRadius(10)
                    }
                    
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Wine")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
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
        .alert("Delete Wine", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task {
                    // Call delete function from parent view
                    await onUpdate(wine.deleteFlag())
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this wine? This action cannot be undone.")
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
