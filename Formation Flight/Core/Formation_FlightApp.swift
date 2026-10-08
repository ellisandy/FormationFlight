//
//  Formation_FlightApp.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/15/23.
//

import SwiftUI
import SwiftData
import CoreData
import CoreLocation

@main
struct Formation_FlightApp: App {
    /// The app's flight store, or `nil` if not even an in-memory container could be created.
    private let sharedModelContainer: ModelContainer?
    /// Whether saved flights had to be discarded to open the store.
    private let didResetStore: Bool
    @State private var hasDismissedStoreResetNotice = false

    init() {
        let args = ProcessInfo.processInfo.arguments
        let useInMemory = args.contains("-uiTestsResetStore")

        do {
            let result = try PersistenceController.makeContainer(inMemory: useInMemory)
            sharedModelContainer = result.container
            didResetStore = result.recovered

            // coverage:ignore-start
            // Optional: seed data for UI tests when requested
            if useInMemory, args.contains("-uiTestsSeedFlights") {
                let context = ModelContext(result.container)
                let f1 = Flight(missionName: "UI F1", missionType: .hackTime, missionDate: .now, target: Target(longitude: 0, latitude: 0))
                let f2 = Flight(missionName: "UI F2", missionType: .hackTime, missionDate: .now, target: Target(longitude: 1, latitude: 1))
                context.insert(f1)
                context.insert(f2)
                try? context.save()
            }

            // Optional: realistic missions for App Store screenshots
            if useInMemory, args.contains("-screenshotSeedFlights") {
                ScreenshotSeed.insertFlights(into: ModelContext(result.container))
            }
            // coverage:ignore-end
        } catch {
            AppLogger.data.fault("Could not create any ModelContainer: \(error.localizedDescription, privacy: .public)")
            sharedModelContainer = nil
            didResetStore = false
        }
    }

    var body: some Scene {
        return WindowGroup {
            if let sharedModelContainer {
                FlightsListView()
                    .modelContainer(sharedModelContainer)
                    .alert("Saved Flights Reset", isPresented: storeResetNoticeBinding) {
                        Button("OK") { hasDismissedStoreResetNotice = true }
                    } message: {
                        Text("Saved flights could not be read and were reset.")
                    }
            } else {
                ContentUnavailableView(
                    "Storage Unavailable",
                    systemImage: "externaldrive.badge.exclamationmark",
                    description: Text("Formation Flight could not open its flight store. Please reinstall the app.")
                )
            }
        }
    }

    private var storeResetNoticeBinding: Binding<Bool> {
        Binding(
            get: { didResetStore && !hasDismissedStoreResetNotice },
            set: { isPresented in
                if !isPresented {
                    hasDismissedStoreResetNotice = true
                }
            }
        )
    }
}

// coverage:ignore-start
/// Sample missions used when capturing App Store screenshots (`-uiTestsResetStore -screenshotSeedFlights`).
///
/// The headline mission's TOT is timed against a simulated route that starts at `routeStart` and
/// flies straight at `routeSpeed`, so the flight screen reads on time when driven with:
/// `xcrun simctl location booted start --speed=72 34.2000,-118.4200 34.1613,-118.1676`
@MainActor
enum ScreenshotSeed {
    static let routeStart = CLLocation(latitude: 34.2000, longitude: -118.4200)
    static let routeSpeed: CLLocationSpeed = 72 // m/s, about 140 kt

    static func insertFlights(into context: ModelContext) {
        let roseBowl = Target(longitude: -118.1676, latitude: 34.1613)
        let timeToTarget = routeStart.distance(from: CLLocation(latitude: roseBowl.latitude, longitude: roseBowl.longitude)) / routeSpeed
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: .now) ?? .now
        let nextWeek = calendar.date(byAdding: .day, value: 6, to: .now) ?? .now

        let flights = [
            Flight(missionName: "Rose Bowl Flyover", missionType: .tot,
                   missionDate: Date.now.addingTimeInterval(timeToTarget + 2), target: roseBowl),
            Flight(missionName: "Golden Gate Formation", missionType: .tot,
                   missionDate: calendar.date(bySettingHour: 10, minute: 30, second: 0, of: tomorrow),
                   target: Target(longitude: -122.4783, latitude: 37.8199)),
            Flight(missionName: "Lake Mead Checkpoint", missionType: .hackTime,
                   missionDate: calendar.date(bySettingHour: 7, minute: 45, second: 0, of: tomorrow),
                   target: Target(longitude: -114.7377, latitude: 36.0161), hackTime: 270),
            Flight(missionName: "Sun 'n Fun Arrival", missionType: .hackTime,
                   missionDate: calendar.date(bySettingHour: 13, minute: 0, second: 0, of: nextWeek),
                   target: Target(longitude: -82.0186, latitude: 27.9889), hackTime: 180),
            Flight(missionName: "Oshkosh Fisk Arrival", missionType: .tot,
                   missionDate: calendar.date(bySettingHour: 9, minute: 15, second: 0, of: nextWeek),
                   target: Target(longitude: -88.9534, latitude: 43.9136)),
        ]
        flights.forEach(context.insert)
        try? context.save()
    }
}
// coverage:ignore-end

/// Builds the SwiftData container that backs the app, recovering from stores that cannot be opened.
@MainActor
enum PersistenceController {
    private static let log = AppLogger.data

    /// Opens the flight store, resetting it if it was written by a schema the migration plan does not
    /// know or if it cannot be read at all.
    ///
    /// Recovery order: open normally; if the store is incompatible or unreadable, destroy its files and
    /// open a fresh store; if even that fails, fall back to an in-memory store so the app can launch.
    ///
    /// - Parameters:
    ///   - schema: The schema to open the store with. Defaults to the current versioned schema.
    ///   - migrationPlan: Every known schema version and how to migrate between them.
    ///   - url: Location of the store file. Pass `nil` to use SwiftData's default location.
    ///   - inMemory: When `true`, the store is kept in memory only (used by UI tests).
    /// - Returns: The container and whether saved flights were discarded to produce it.
    /// - Throws: Only if not even an in-memory container can be created for `schema`.
    static func makeContainer(
        schema: Schema = Schema(versionedSchema: FlightSchemaV1.self),
        migrationPlan: any SchemaMigrationPlan.Type = FlightMigrationPlan.self,
        url: URL? = nil,
        inMemory: Bool = false
    ) throws -> (container: ModelContainer, recovered: Bool) {
        if inMemory {
            return (try makeInMemoryContainer(schema: schema, migrationPlan: migrationPlan), false)
        }

        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration(schema: schema, url: url)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        }
        let storeURL = configuration.url

        var recovered = false
        if storeExists(at: storeURL), !storeIsCompatible(at: storeURL, withAnyOf: migrationPlan.schemas) {
            log.error("Flight store \(storeURL.lastPathComponent, privacy: .public) was written by an unknown schema version; resetting it.")
            destroyStore(at: storeURL)
            recovered = true
        }

        do {
            return (try ModelContainer(for: schema, migrationPlan: migrationPlan, configurations: [configuration]), recovered)
        } catch {
            log.error("Could not open flight store: \(error.localizedDescription, privacy: .public). Resetting it.")
        }

        destroyStore(at: storeURL)
        do {
            return (try ModelContainer(for: schema, migrationPlan: migrationPlan, configurations: [configuration]), true)
        } catch {
            log.fault("Could not open a fresh flight store: \(error.localizedDescription, privacy: .public). Falling back to an in-memory store.")
        }

        return (try makeInMemoryContainer(schema: schema, migrationPlan: migrationPlan), true)
    }

    private static func makeInMemoryContainer(schema: Schema, migrationPlan: any SchemaMigrationPlan.Type) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, migrationPlan: migrationPlan, configurations: [configuration])
    }

    private static func storeExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    /// Whether the store at `url` was written by one of `schemas`, judged by the model version hashes
    /// Core Data records in the store metadata.
    ///
    /// SwiftData lightweight-migrates any store it can, even one from a schema outside the migration
    /// plan; for the pre-versioning `Flight` model that leaves rows whose `missionType` is NULL and
    /// traps on read. Checking compatibility first lets such stores be reset instead.
    private static func storeIsCompatible(at url: URL, withAnyOf schemas: [any VersionedSchema.Type]) -> Bool {
        let metadata: [String: Any]
        do {
            metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(type: .sqlite, at: url)
        } catch {
            log.error("Could not read flight store metadata: \(error.localizedDescription, privacy: .public)")
            return false
        }

        return schemas.contains { versionedSchema in
            guard let model = NSManagedObjectModel.makeManagedObjectModel(for: versionedSchema.models) else {
                return false
            }
            return model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        }
    }

    /// Removes the store file and its SQLite `-wal`/`-shm` sidecars.
    private static func destroyStore(at url: URL) {
        let fileManager = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let fileURL = URL(filePath: url.path(percentEncoded: false) + suffix)
            guard fileManager.fileExists(atPath: fileURL.path(percentEncoded: false)) else { continue }
            do {
                try fileManager.removeItem(at: fileURL)
            } catch {
                log.error("Could not remove \(fileURL.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
