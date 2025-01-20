// Views/ContentView.swift
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: WineListViewModel
    private let repository: WineRepository  // Add this
    
    init(repository: WineRepository) {
        self.repository = repository  // Store repository
        _viewModel = StateObject(wrappedValue: WineListViewModel(repository: repository))
    }
    
    var body: some View {
        NavigationView {
            WineListView(viewModel: viewModel)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: WineCellarQueryView(repository: repository)) {  // Use stored repository
                            Image(systemName: "message.circle")
                        }
                    }
                }
        }
    }
}
