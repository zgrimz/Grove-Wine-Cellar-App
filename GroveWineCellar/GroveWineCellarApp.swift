//
//  GroveWineCellarApp.swift
//  GroveWineCellar
//
//  Created by Zachary W. Grimshaw on 12/9/24.
//

import SwiftUI

@main
struct GroveWineCellarApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
