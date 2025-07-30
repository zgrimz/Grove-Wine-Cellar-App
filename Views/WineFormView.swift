import SwiftUI
import UIKit
import Foundation

struct WineFormView: View {
    @Environment(\.dismiss) private var dismiss
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
                .disabled(viewModel.name.isEmpty)
            }
        }
        .sheet(isPresented: $viewModel.showingCamera) {
            ImagePicker(image: $viewModel.image, sourceType: .camera)
                .onDisappear {
                    processImageIfNeeded()
                }
        }
        .sheet(isPresented: $viewModel.showingImagePicker) {
            ImagePicker(image: $viewModel.image, sourceType: .photoLibrary)
                .onDisappear {
                    processImageIfNeeded()
                }
        }
        .sheet(isPresented: $showingSweetnessSelection) {
            SweetnessSelectionView(selectedSweetness: $viewModel.sweetness)
        }
        .actionSheet(isPresented: $showingImageOptions) {
            ActionSheet(
                title: Text("Add Photo"),
                buttons: [
                    .default(Text("Take Photo")) {
                        viewModel.showingCamera = true
                    },
                    .default(Text("Choose from Library")) {
                        viewModel.showingImagePicker = true
                    },
                    .cancel()
                ]
            )
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
    
    private func processImageIfNeeded() {
        if let image = viewModel.image {
            Task {
                do {
                    let attributes = try await viewModel.processImage(image)
                    await MainActor.run {
                        viewModel.name = attributes.name
                        viewModel.color = attributes.color
                        viewModel.style = attributes.style
                        viewModel.sweetness = attributes.sweetness ?? []
                        viewModel.producer = attributes.producer ?? ""
                        viewModel.vintage = attributes.vintage.map(String.init) ?? ""
                        viewModel.region = attributes.region ?? ""
                        viewModel.varietal = attributes.varietal ?? ""
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
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