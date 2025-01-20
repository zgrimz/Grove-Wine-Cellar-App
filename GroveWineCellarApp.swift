import SwiftUI
import CoreData
import Foundation

@main
struct GroveWineCellarApp: App {
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView(
                repository: WineRepository(
                    context: persistenceController.container.viewContext
                )
            )
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
