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
                VStack(alignment: .leading, spacing: 20) {
                    // Pairing Type Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pairing for...")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 8) {
                            FilterChip(
                                text: "Food",
                                isSelected: viewModel.pairingType == .food,
                                action: { viewModel.pairingType = .food }
                            )
                            
                            FilterChip(
                                text: "Occasion",
                                isSelected: viewModel.pairingType == .occasion,
                                action: { viewModel.pairingType = .occasion }
                            )
                        }
                    }
                    
                    // Wine Type Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type:")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                            FilterChip(
                                text: "Any",
                                isSelected: viewModel.selectedWineColor == nil,
                                action: { viewModel.selectedWineColor = nil }
                            )
                            
                            ForEach([WineColor.red, WineColor.white, WineColor.rose, WineColor.orange, WineColor.other], id: \.self) { color in
                                FilterChip(
                                    text: color.rawValue,
                                    isSelected: viewModel.selectedWineColor == color,
                                    action: { viewModel.selectedWineColor = color }
                                )
                            }
                        }
                    }
                    
                    // Input Section
                    HStack {
                        TextField(viewModel.pairingType == .food ? "Enter food or meal..." : "Enter occasion...", text: $viewModel.foodInput)
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