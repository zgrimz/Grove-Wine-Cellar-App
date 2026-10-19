import SwiftUI

@main
struct GroveWineCellarApp: App {
    @State private var store = WineStore(
        repository: WineRepository(context: PersistenceController.shared.container.viewContext))
    @State private var aiSettings = AISettings()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(aiSettings)
        }
    }
}
