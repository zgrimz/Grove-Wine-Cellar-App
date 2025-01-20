import SwiftUI

struct WineListView: View {
    @ObservedObject var viewModel: WineListViewModel
    @State private var showingAddWine = false
    
    var body: some View {
        List {
            SearchBarView(text: $viewModel.searchText)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            
            TypeFilterView(selectedType: $viewModel.selectedType)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            
            ForEach(viewModel.filteredWines) { wine in
                NavigationLink(
                    destination: WineDetailView(
                        wine: wine,
                        onUpdate: { updatedWine in
                            Task {
                                await viewModel.updateWine(updatedWine)
                            }
                        }
                    )
                ) {
                    WineRowView(wine: wine)
                }
            }
            .onDelete { indexSet in
                indexSet.forEach { index in
                    viewModel.deleteWine(viewModel.filteredWines[index])
                }
            }
        }
        .navigationTitle("Grove Wine Cellar")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddWine = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddWine) {
            NavigationView {
                WineFormView(
                    onSave: { newWine in
                        Task {
                            await viewModel.addWine(newWine)
                            showingAddWine = false
                        }
                    }
                )
            }
        }
        .refreshable {
            await viewModel.loadWines()
        }
    }
}
