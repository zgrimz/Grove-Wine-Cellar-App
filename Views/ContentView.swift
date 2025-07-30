// Views/ContentView.swift
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: WineListViewModel
    private let repository: WineRepository  // Add this
    @State private var showingSettings = false
    
    init(repository: WineRepository) {
        self.repository = repository  // Store repository
        _viewModel = StateObject(wrappedValue: WineListViewModel(repository: repository))
    }
    
    var body: some View {
        NavigationView {
            WineListView(viewModel: viewModel)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gear")
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: WineCellarQueryView(repository: repository)) {  // Use stored repository
                            Image(systemName: "message.circle")
                        }
                    }
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView()
                }
        }
    }
}
