import SwiftUI

struct ContentView: View {
    @Environment(WineStore.self) private var store
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            WineListView()
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gear")
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: WineCellarQueryView()) {
                            Image(systemName: "message.circle")
                        }
                    }
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView()
                }
        }
        .task { store.load() }
    }
}
