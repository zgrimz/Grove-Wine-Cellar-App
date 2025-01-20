// Views/WineCellarQueryView.swift
import SwiftUI

struct WineCellarQueryView: View {
    @StateObject private var viewModel: WineCellarQueryViewModel
    @FocusState private var isFocused: Bool
    
    init(repository: WineRepository) {
        _viewModel = StateObject(wrappedValue: WineCellarQueryViewModel(repository: repository))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if let pairing = viewModel.currentPairing {
                ScrollView {
                    Text(pairing.content)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Button("New Pairing") {
                    viewModel.reset()
                }
                .buttonStyle(.bordered)
                
            } else {
                Text("Enter a dish or meal to find the perfect wine pairing from your cellar")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding()
                
                HStack {
                    TextField("Enter food or meal...", text: $viewModel.foodInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isFocused)
                        .disabled(viewModel.isLoading)
                    
                    Button(action: {
                        Task {
                            await viewModel.getPairing()
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .disabled(viewModel.foodInput.isEmpty || viewModel.isLoading)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Wine Pairing")
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .padding()
                    .background(Color.secondary.colorInvert())
                    .cornerRadius(8)
                    .shadow(radius: 4)
            }
        }
    }
}