import SwiftUI
import UIKit

/// Looks its wine up in the store by id rather than holding a copy, so an edit made anywhere shows
/// up here at once — and a wine deleted elsewhere can't be edited back into existence.
struct WineDetailView: View {
    let wineID: UUID
    @Environment(WineStore.self) private var store
    @State private var image: UIImage?
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    
    var body: some View {
        if let wine = store.wine(id: wineID) {
            details(for: wine)
        } else {
            ContentUnavailableView("Wine Not Found", systemImage: "wineglass",
                                   description: Text("This wine has been deleted."))
        }
    }

    private func details(for wine: Wine) -> some View {
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
                        Badge(text: wine.color.rawValue, color: colorFor(wine.color))
                        Badge(text: wine.style.rawValue, color: .gray)
                    }
                    
                    if !wine.sweetness.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sweetness:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                ForEach(Array(wine.sweetness).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { sweetness in
                                    Badge(text: sweetness.rawValue, color: .blue)
                                }
                            }
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
                
                if let notes = wine.notes, !notes.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                        
                        Text(notes)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button(action: {
                        perform {
                            try store.setArchived(!wine.isArchived, for: wine)
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
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                WineFormView(wine: wine) { try store.update($0) }
            }
        }
        .alert("Delete Wine", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                perform {
                    try store.delete(wine)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this wine? This action cannot be undone.")
        }
        .errorAlert(message: $errorMessage)
        // Keyed on the path so a photo changed in the edit sheet shows up; onAppear ran only once.
        .task(id: wine.imagePath) {
            guard let imagePath = wine.imagePath else { image = nil; return }
            image = await ImageStorageService.shared.loadImage(fromPath: imagePath, maxPixelLength: 600 * displayScale)
        }
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            errorMessage = error.localizedDescription
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