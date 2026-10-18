import SwiftUI

struct WineCellarQueryView: View {
    @Environment(WineStore.self) private var store
    @Environment(AISettings.self) private var aiSettings
    @State private var viewModel = WineCellarQueryViewModel()
    @FocusState private var isFocused: Bool

    /// Looked up live rather than captured with the result, so archiving, editing or deleting the
    /// wine from its detail screen is reflected here when the user comes back.
    private func matchedWine(for recommendation: WineRecommendation) -> Wine? {
        recommendation.wineID.flatMap(store.wine(id:))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if case .result(let recommendation) = viewModel.state {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header with wine glass icon
                        HStack {
                            Image(systemName: "wineglass.fill")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                            Text("Your Pairing Recommendation")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        // Recommended wine card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text("Recommended Wine")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                // Show navigation indicator if wine is in inventory
                                if matchedWine(for: recommendation) != nil {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Group {
                                if let matchedWine = matchedWine(for: recommendation) {
                                    NavigationLink(destination: WineDetailView(wineID: matchedWine.id)) {
                                        wineCardContent(recommendation: recommendation, matchedWine: matchedWine)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                } else {
                                    wineCardContent(recommendation: recommendation, matchedWine: nil)
                                }
                            }
                        }
                        
                        // Confidence indicator
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Confidence Level")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            HStack {
                                ProgressView(value: Double(recommendation.pairingConfidence), total: 10)
                                    .progressViewStyle(LinearProgressViewStyle(tint: recommendation.pairingConfidence >= 8 ? .green : recommendation.pairingConfidence >= 6 ? .orange : .red))
                                Text("\(recommendation.pairingConfidence)/10")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        // Reasons with better formatting
                        if !recommendation.whyThisPair.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Why This Pairing Works")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                ForEach(recommendation.whyThisPair, id: \.self) { reason in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                        Text(reason)
                                            .font(.body)
                                    }
                                }
                            }
                        }
                        
                        // Alternative suggestion
                        if let betterPairing = recommendation.betterPairingRecommendation {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Alternative Suggestion")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(betterPairing.wine)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(betterPairing.explanation)
                                        .font(.body)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding()
                }
                
                Button("New Pairing") {
                    viewModel.reset()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 32) {
                    // Hero section with better visual hierarchy
                    VStack(spacing: 16) {
                        Text("AI Wine Sommelier")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Get personalized recommendations from your cellar")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Pairing type selector as segmented control
                    VStack(alignment: .leading, spacing: 12) {
                        Text("I'm pairing for...")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Picker("Pairing Type", selection: $viewModel.pairingType) {
                            Text("Food & Meals").tag(PairingType.food)
                            Text("Special Occasions").tag(PairingType.occasion)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // Wine type as 2x3 grid with better visual design
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Preferred wine type")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            WineTypeCard(title: "Any", isSelected: viewModel.selectedWineColor == nil) {
                                viewModel.selectedWineColor = nil
                            }
                            
                            WineTypeCard(title: "Red", color: colorFor(.red), isSelected: viewModel.selectedWineColor == .red) {
                                viewModel.selectedWineColor = .red
                            }
                            
                            WineTypeCard(title: "White", color: colorFor(.white), isSelected: viewModel.selectedWineColor == .white) {
                                viewModel.selectedWineColor = .white
                            }
                            
                            WineTypeCard(title: "Rosé", color: colorFor(.rose), isSelected: viewModel.selectedWineColor == .rose) {
                                viewModel.selectedWineColor = .rose
                            }
                            
                            WineTypeCard(title: "Orange", color: colorFor(.orange), isSelected: viewModel.selectedWineColor == .orange) {
                                viewModel.selectedWineColor = .orange
                            }
                            
                            WineTypeCard(title: "Other", color: colorFor(.other), isSelected: viewModel.selectedWineColor == .other) {
                                viewModel.selectedWineColor = .other
                            }
                        }
                    }
                    
                    // Enhanced input with better visual design
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            
                            TextField(viewModel.pairingType == .food ? "Enter food or meal..." : "Enter occasion...", text: $viewModel.foodInput)
                                .font(.body)
                                .focused($isFocused)
                                .disabled(viewModel.isLoading)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .onTapGesture {
                            isFocused = true
                        }
                        
                        if case .failed(let message) = viewModel.state {
                            Label(message, systemImage: "exclamationmark.triangle")
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(action: {
                            Task {
                                await viewModel.getPairing(from: store.wines, settings: aiSettings)
                            }
                        }) {
                            HStack {
                                Text("Get Recommendation")
                                    .fontWeight(.medium)
                                Image(systemName: "sparkles")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.canRequestPairing ? Color.accentColor : Color.secondary)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!viewModel.canRequestPairing)
                    }
                    .id("inputSection")
                    
                }
                .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo("inputSection", anchor: .bottom)
                    }
                }
                }
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
    
    private func wineCardContent(recommendation: WineRecommendation, matchedWine: Wine?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(recommendation.recommendation)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            HStack {
                Text(recommendation.recommendedWine.producer)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let vintage = recommendation.recommendedWine.vintage {
                    Text(String(vintage))
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }
            }
            
            // Wine type and color badges
            if let wine = matchedWine {
                HStack(spacing: 8) {
                    Label(wine.color.rawValue, systemImage: "wineglass")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(colorFor(wine.color).opacity(0.15))
                        .foregroundColor(colorFor(wine.color))
                        .clipShape(Capsule())
                    
                    Text(wine.style.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(12)
    }
}
