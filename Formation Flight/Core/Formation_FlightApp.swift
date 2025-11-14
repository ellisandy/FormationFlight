//
//  Formation_FlightApp.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/15/23.
//

import SwiftUI
import SwiftData
import CoreLocation

@main
struct Formation_FlightApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Flight.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        return WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
