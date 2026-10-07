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

            // coverage:ignore-start
            // Optional: seed data for UI tests when requested
            if useInMemory, args.contains("-uiTestsSeedFlights") {
                let context = ModelContext(container)
                let f1 = Flight(missionName: "UI F1", missionType: .hackTime, missionDate: .now, target: Target(longitude: 0, latitude: 0))
                let f2 = Flight(missionName: "UI F2", missionType: .hackTime, missionDate: .now, target: Target(longitude: 1, latitude: 1))
                context.insert(f1)
                context.insert(f2)
                try? context.save()
            }
            // coverage:ignore-end

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

/// Builds the SwiftData container that backs the app.
@MainActor
enum PersistenceController {
    /// Opens the flight store described by `schema`.
    ///
    /// - Parameters:
    ///   - schema: The schema to open the store with.
    ///   - url: Location of the store file. Pass `nil` to use SwiftData's default location.
    ///   - inMemory: When `true`, the store is kept in memory only (used by UI tests).
    /// - Returns: The container and whether the on-disk store had to be reset to produce it.
    static func makeContainer(schema: Schema, url: URL?, inMemory: Bool) throws -> (container: ModelContainer, recovered: Bool) {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else if let url {
            configuration = ModelConfiguration(schema: schema, url: url)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        }
        return (try ModelContainer(for: schema, configurations: [configuration]), false)
    }
}

