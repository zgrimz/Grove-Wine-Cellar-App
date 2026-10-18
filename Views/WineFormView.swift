import SwiftUI
import UIKit
import Foundation

struct WineFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AISettings.self) private var aiSettings
    @ObservedObject private var viewModel: WineFormViewModel
    @State private var showingImageOptions = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSweetnessSelection = false
    
    init(onSave: @escaping (Wine) async -> Void, wine: Wine? = nil) {
        self.viewModel = WineFormViewModel(onSave: onSave, wine: wine)
    }
    
    var body: some View {
        Form {
            Section(header: Text("Photo")) {
                HStack {
                    Spacer()
                    if let image = viewModel.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                    } else {
                        Image(systemName: "camera")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                            .frame(height: 200)
                    }
                    Spacer()
                }
                .onTapGesture {
                    showingImageOptions = true
                }
            }
            
            Section(header: Text("Wine Details")) {
                TextField("Name", text: $viewModel.name)
                Picker("Color", selection: $viewModel.color) {
                    ForEach(WineColor.allCases, id: \.self) { color in
                        Text(color.rawValue).tag(color)
                    }
                }
                Picker("Style", selection: $viewModel.style) {
                    ForEach(WineStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                
                Button(action: {
                    showingSweetnessSelection = true
                }) {
                    HStack {
                        Text("Sweetness")
                        Spacer()
                        Text(sweetnessDisplayText)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Section(header: Text("Additional Details")) {
                TextField("Producer", text: $viewModel.producer)
                TextField("Vintage", text: $viewModel.vintage)
                    .keyboardType(.numberPad)
                if !viewModel.isVintageValid {
                    Text("Enter a four-digit year, or leave it blank for non-vintage.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                TextField("Region", text: $viewModel.region)
                TextField("Varietal", text: $viewModel.varietal)
            }
            
            Section(header: Text("Notes")) {
                TextEditor(text: $viewModel.notes)
                    .frame(minHeight: 100)
            }
        }
        .navigationTitle(viewModel.isEditMode ? "Edit Wine" : "Add Wine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    save()
                }
                .disabled(!viewModel.canSave)
            }
        }
        .sheet(isPresented: $viewModel.showingCamera) {
            ImagePicker(sourceType: .camera, onPick: photoPicked)
        }
        .sheet(isPresented: $viewModel.showingImagePicker) {
            ImagePicker(sourceType: .photoLibrary, onPick: photoPicked)
        }
        .sheet(isPresented: $showingSweetnessSelection) {
            SweetnessSelectionView(selectedSweetness: $viewModel.sweetness)
        }
        .confirmationDialog("Add Photo", isPresented: $showingImageOptions) {
            if ImagePicker.isAvailable(.camera) {
                Button("Take Photo") { viewModel.showingCamera = true }
            }
            Button("Choose from Library") { viewModel.showingImagePicker = true }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .overlay {
            if viewModel.isProcessing {
                ProgressView("Processing image...")
                    .padding()
                    .background(Color.secondary.colorInvert())
                    .cornerRadius(8)
                    .shadow(radius: 4)
            }
        }
    }
    
    private var sweetnessDisplayText: String {
        if viewModel.sweetness.isEmpty {
            return "None"
        }
        return viewModel.sweetness
            .map { $0.rawValue }
            .sorted()
            .joined(separator: ", ")
    }
    
    /// Runs only for a newly picked photo. It used to hang off the picker's `onDisappear`, which
    /// also fires on Cancel — re-scanning the existing photo and overwriting the user's edits.
    private func photoPicked(_ image: UIImage) {
        viewModel.image = image
        // With AI off, a photo is just the wine's photo — no scan, and no error asking for a key.
        guard aiSettings.isEnabled else { return }
        Task {
            do {
                try await viewModel.scanLabel(image, settings: aiSettings)
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func save() {
        Task {
            do {
                try await viewModel.save()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}