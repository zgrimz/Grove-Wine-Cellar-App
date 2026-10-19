import SwiftUI

struct WineListView: View {
    @Environment(WineStore.self) private var store
    @State private var searchText = ""
    @State private var selectedColor: WineColor?
    @State private var selectedStyle: WineStyle?
    @State private var showArchived = false
    @State private var showingAddWine = false
    @State private var wineToDelete: Wine? = nil
    @State private var showingDeleteAlert = false
    @State private var showingFilterPanel = false
    @State private var errorMessage: String?

    private var filteredWines: [Wine] {
        store.wines.filter { wine in
            let matchesSearch = searchText.isEmpty ||
                wine.name.localizedCaseInsensitiveContains(searchText) ||
                wine.producer?.localizedCaseInsensitiveContains(searchText) == true ||
                wine.region?.localizedCaseInsensitiveContains(searchText) == true ||
                wine.varietal?.localizedCaseInsensitiveContains(searchText) == true ||
                wine.notes?.localizedCaseInsensitiveContains(searchText) == true ||
                wine.vintage.map { String($0).contains(searchText) } == true
            let matchesColor = selectedColor == nil || wine.color == selectedColor
            let matchesStyle = selectedStyle == nil || wine.style == selectedStyle
            let matchesArchiveState = wine.isArchived == showArchived
            return matchesSearch && matchesColor && matchesStyle && matchesArchiveState
        }
    }

    var body: some View {
        List {
            HStack {
                ColorFilterView(selectedColor: $selectedColor)

                Spacer()

                Button {
                    showingFilterPanel = true
                } label: {
                    Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                }
                .padding(.trailing)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            ForEach(filteredWines) { wine in
                NavigationLink(value: Route.wine(wine.id)) {
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
                        perform { try store.setArchived(!wine.isArchived, for: wine) }
                    } label: {
                        Label(wine.isArchived ? "Unarchive" : "Archive",
                              systemImage: wine.isArchived ? "archivebox.circle.fill" : "archivebox")
                    }
                    .tint(.orange)
                }
            }

            // Add full-width button at bottom of list
            Button(action: {
                showArchived.toggle()
            }) {
                HStack {
                    Image(systemName: showArchived ? "archivebox.circle.fill" : "archivebox")
                    Text(showArchived ? "View Current Inventory" : "View Archived Wines")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .clipShape(.rect(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .padding(.vertical)
        }
        .navigationTitle("Grove Wine Cellar")
        .searchable(text: $searchText, prompt: "Search wines")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAddWine = true } label: {
                    Label("Add Wine", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddWine) {
            NavigationStack {
                WineFormView { try store.add($0) }
            }
        }
        .sheet(isPresented: $showingFilterPanel) {
            FilterPanelView(
                selectedColor: $selectedColor,
                selectedStyle: $selectedStyle,
                isPresented: $showingFilterPanel
            )
        }
        .refreshable {
            store.load()
        }
        .alert("Delete Wine", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let wine = wineToDelete {
                    perform { try store.delete(wine) }
                    wineToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                wineToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this wine? This action cannot be undone.")
        }
        .errorAlert(message: $errorMessage)
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
