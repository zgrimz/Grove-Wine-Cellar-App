import SwiftUI
import Foundation

struct WineListView: View {
    @ObservedObject var viewModel: WineListViewModel
    @State private var showingAddWine = false
    @State private var wineToDelete: Wine? = nil
    @State private var showingDeleteAlert = false
    @State private var showingFilterPanel = false
    
    var body: some View {
        List {
            SearchBarView(text: $viewModel.searchText)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            
            HStack {
                ColorFilterView(selectedColor: $viewModel.selectedColor)
                
                Spacer()
                
                Button(action: {
                    showingFilterPanel = true
                }) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
                .padding(.trailing)
            }
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
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        wineToDelete = wine
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    
                    Button {
                        viewModel.toggleArchived(wine)
                    } label: {
                        Label(wine.isArchived ? "Unarchive" : "Archive",
                              systemImage: wine.isArchived ? "archivebox.circle.fill" : "archivebox")
                    }
                    .tint(.orange)
                }
            }
            .onDelete { indexSet in
                if let index = indexSet.first {
                    wineToDelete = viewModel.filteredWines[index]
                    showingDeleteAlert = true
                }
            }
            
            // Add full-width button at bottom of list
            Button(action: {
                viewModel.showArchived.toggle()
                Task {
                    await viewModel.loadWines()
                }
            }) {
                HStack {
                    Image(systemName: viewModel.showArchived ? "archivebox.circle.fill" : "archivebox")
                    Text(viewModel.showArchived ? "View Current Inventory" : "View Archived Wines")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .padding(.vertical)
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
        .sheet(isPresented: $showingFilterPanel) {
            FilterPanelView(
                selectedColor: $viewModel.selectedColor,
                selectedStyle: $viewModel.selectedStyle,
                isPresented: $showingFilterPanel
            )
        }
        .refreshable {
            await viewModel.loadWines()
        }
        .onAppear {
            print("View appeared. Total wines: \(viewModel.filteredWines.count)")
        }
        .alert("Delete Wine", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let wine = wineToDelete {
                    viewModel.deleteWine(wine)
                    wineToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                wineToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this wine? This action cannot be undone.")
        }
    }
}
