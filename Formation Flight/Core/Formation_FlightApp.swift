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

        let args = ProcessInfo.processInfo.arguments
        let useInMemory = args.contains("-uiTestsResetStore")

        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: useInMemory)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])

            // Optional: seed data for UI tests when requested
            if useInMemory, args.contains("-uiTestsSeedFlights") {
                let context = ModelContext(container)
                let f1 = Flight(missionName: "UI F1", missionType: .hackTime, missionDate: .now, target: Target(longitude: 0, latitude: 0))
                let f2 = Flight(missionName: "UI F2", missionType: .hackTime, missionDate: .now, target: Target(longitude: 1, latitude: 1))
                context.insert(f1)
                context.insert(f2)
                try? context.save()
            }

            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        return WindowGroup {
            FlightsListView()
        }
        .modelContainer(sharedModelContainer)
    }
}

