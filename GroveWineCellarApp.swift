import SwiftUI
import CoreData
import Foundation

@main
struct GroveWineCellarApp: App {
    let persistenceController = PersistenceController.shared
    @State private var aiSettings = AISettings()
    
    var body: some Scene {
        WindowGroup {
            ContentView(
                repository: WineRepository(
                    context: persistenceController.container.viewContext
                )
            )
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
            .environment(aiSettings)
        }
    }
}
