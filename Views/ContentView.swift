import SwiftUI

/// Every push destination in the app, registered once at the root of the stack.
enum Route: Hashable {
    case wine(UUID)
    case pairing
}

struct ContentView: View {
    @Environment(WineStore.self) private var store
    @State private var showingSettings = false
    
    var body: some View {
        NavigationStack {
            WineListView()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showingSettings = true } label: {
                            Label("Settings", systemImage: "gear")
                        }
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(value: Route.pairing) {
                            Label("Wine Pairing", systemImage: "message.circle")
                        }
                    }
                }
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .wine(let id): WineDetailView(wineID: id)
                    case .pairing: WineCellarQueryView()
                    }
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView()
                }
        }
        .task { store.load() }
    }
}
