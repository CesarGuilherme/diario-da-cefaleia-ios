//
//  Diario_da_CefaleiaApp.swift
//  Diario da Cefaleia
//
//  Created by César Guilherme Lana Nonato on 11/08/26.
//

import SwiftUI
import SwiftData

@main
struct Diario_da_CefaleiaApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
