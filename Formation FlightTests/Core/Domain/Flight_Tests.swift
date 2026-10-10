import Foundation
import SwiftData
import Testing
@testable import Formation_Flight
import FormationFlightCore

@Suite
struct FlightTests {
  var sampleTarget: Target {

      Target(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, longitude: 0.0, latitude: 1.0)
  }

  var sampleDate: Date {
    Date(timeIntervalSince1970: 1_000_000) // deterministic date
  }

  var sampleHackTime: TimeInterval { // seconds
    2_000 // deterministic hack time
  }

  @Test
  func testValidFlight() throws {
    let flight = Flight(
      missionName: "Valid Mission",
      missionType: .hackTime,
      missionDate: nil,
      target: sampleTarget,
      hackTime: sampleHackTime
    )
    let validation = flight.validFlight()
    #expect(validation.valid)
    #expect(validation.message == nil)
  }

  @Test
  func testEmptyMissionName() throws {
    // Use a configuration that doesn't trip other validations
    let flight = Flight(
      missionName: "",
      missionType: .tot,
      missionDate: sampleDate,
      target: sampleTarget,
      hackTime: nil
    )
    let validation = flight.validFlight()
    #expect(!validation.valid)
    #expect(validation.message != nil)
    #expect(validation.message!.localizedCaseInsensitiveContains("name"))
  }

  @Test
  func testHackTimeNil() throws {
    let flight = Flight(
      missionName: "HackTime Mission",
      missionType: .hackTime,
      missionDate: nil,
      target: sampleTarget,
      hackTime: nil
    )
    let validation = flight.validFlight()
    #expect(!validation.valid)
    #expect(validation.message != nil)
    #expect(validation.message!.localizedCaseInsensitiveContains("hack time"))
  }

  // B-14: a hack-time mission with a 0 s hack is as unusable as one with no hack at all
  // (pressing Hack would make TOT = now and the readout instantly red).
  @Test
  func testHackTimeZeroIsRejected() throws {
    let flight = Flight(
      missionName: "Zero Hack",
      missionType: .hackTime,
      missionDate: nil,
      target: sampleTarget,
      hackTime: 0
    )
    let validation = flight.validFlight()
    #expect(!validation.valid)
    #expect(validation.message?.localizedCaseInsensitiveContains("hack") == true)
  }

  @Test
  func testNegativeHackTimeIsRejected() throws {
    let flight = Flight(
      missionName: "Negative Hack",
      missionType: .hackTime,
      missionDate: nil,
      target: sampleTarget,
      hackTime: -5
    )
    #expect(!flight.validFlight().valid)
  }

  // B-14: a TOT more than a minute in the past cannot be flown. The clock is injected so
  // the boundary is exact.
  @Test
  func testPastTOTIsRejected() throws {
    let now = Date(timeIntervalSince1970: 2_000_000)
    let flight = Flight(
      missionName: "Late",
      missionType: .tot,
      missionDate: now.addingTimeInterval(-61),
      target: sampleTarget,
      hackTime: nil
    )
    let validation = flight.validFlight(now: now)
    #expect(!validation.valid)
    #expect(validation.message?.localizedCaseInsensitiveContains("past") == true)
  }

  @Test
  func testTOTWithinOneMinuteGraceIsAccepted() throws {
    let now = Date(timeIntervalSince1970: 2_000_000)
    let flight = Flight(
      missionName: "Just now",
      missionType: .tot,
      missionDate: now.addingTimeInterval(-60),
      target: sampleTarget,
      hackTime: nil
    )
    let validation = flight.validFlight(now: now)
    #expect(validation.valid)
    #expect(validation.message == nil)
  }

  @Test
  func testFutureTOTIsAccepted() throws {
    let now = Date(timeIntervalSince1970: 2_000_000)
    let flight = Flight(
      missionName: "Later",
      missionType: .tot,
      missionDate: now.addingTimeInterval(3_600),
      target: sampleTarget,
      hackTime: nil
    )
    #expect(flight.validFlight(now: now).valid)
  }

  @Test
  func testTotNilDate() throws {
    let flight = Flight(
      missionName: "TOT Mission",
      missionType: .tot,
      missionDate: nil,
      target: sampleTarget,
      hackTime: nil
    )
    let validation = flight.validFlight()
    #expect(!validation.valid)
    #expect(validation.message != nil)
    #expect(validation.message!.localizedCaseInsensitiveContains("date"))
  }

  @Test
  func testNilTarget() throws {
    let flight = Flight(
      missionName: "No Target Mission",
      missionType: .tot,
      missionDate: sampleDate,
      target: sampleTarget,
      hackTime: nil
    )
    // Set target to nil after initialization to simulate missing target
    flight.target = nil

    let validation = flight.validFlight()
    #expect(!validation.valid)
    #expect(validation.message != nil)
    #expect(validation.message!.localizedCaseInsensitiveContains("target"))
  }

  @Test
  func testEqualityAndHashing() throws {
    let id = UUID()
    let flight1 = Flight(
      missionName: "Mission 1",
      missionType: .tot,
      missionDate: sampleDate,
      target: sampleTarget,
      hackTime: nil
    )
    flight1.id = id

    let flight2 = Flight(
      missionName: "Mission 1",
      missionType: .tot,
      missionDate: sampleDate,
      target: sampleTarget,
      hackTime: nil
    )
    flight2.id = id

    let flight3 = Flight(
      missionName: "Mission 3",
      missionType: .tot,
      missionDate: sampleDate,
      target: sampleTarget,
      hackTime: nil
    )

    // Same id, equal
    #expect(flight1 == flight2)
    // Different id, not equal
    #expect(flight1 != flight3)

    // Set uniqueness by id
    var set = Set<Flight>()
    set.insert(flight1)
    set.insert(flight2)
    set.insert(flight3)
    #expect(set.count == 2)
    #expect(set.contains(flight1))
    #expect(set.contains(flight3))
  }
}

// MARK: - On-disk contract

/// `MissionType` is stored by SwiftData as its raw string on every `Flight` row, so these
/// values are an on-disk contract: changing one makes existing rows undecodable. Pin them.
@Suite("MissionType raw values")
struct MissionTypeRawValueTests {
    @Test("MissionType raw values are stable (on-disk contract)")
    func testMissionTypeRawValuesArePinned() {
        #expect(MissionType.hackTime.rawValue == "hack_time")
        #expect(MissionType.tot.rawValue == "tot")
        // Adding a case needs a migration story; this forces the list above to be revisited.
        #expect(MissionType.allCases.count == 2)
    }
}

// MARK: - Persistence fixtures

/// Mimics the `Flight` model that shipped before the current schema
/// (`git show 0c9ddcb:"Formation Flight/Core/Domain/Flight.swift"`).
///
/// SwiftData derives the on-disk entity name from the class name, so nesting a `@Model` class
/// named `Flight` inside this enum reproduces a real store written by that older build.
enum LegacyFlightSchemaFixture: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(0, 1, 0) }
    static var models: [any PersistentModel.Type] { [Flight.self] }

    struct Winds: Codable, Hashable {
        var velocity: Double
        var direction: Double
    }

    struct CheckPoint: Codable, Hashable {
        var name: String
        var longitude: Double
        var latitude: Double
    }

    @Model
    final class Flight {
        @Attribute(.unique) var id: UUID = UUID()
        var title: String = ""
        var missionDate: Date = Date.now
        var expectedWinds: Winds = Winds(velocity: 0, direction: 0)
        var checkPoints: [CheckPoint] = []
        var inflightCheckPoints: [CheckPoint] = []
        var markTimeInSeconds: Double? = nil

        init(title: String, missionDate: Date) {
            self.title = title
            self.missionDate = missionDate
        }
    }
}

/// Mimics the `Flight` model of the currently shipped build (no default on `missionType`).
///
/// Stores written by this schema belong to real users and must open without being reset.
enum ShippedFlightSchemaFixture: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(0, 2, 0) }
    static var models: [any PersistentModel.Type] { [Flight.self] }

    @Model
    final class Flight {
        @Attribute(.unique) var id: UUID = UUID()
        var missionName: String = ""
        var missionType: MissionType
        var missionDate: Date?
        var target: Target?
        var hackTime: TimeInterval?

        init(missionName: String, missionType: MissionType, target: Target, hackTime: TimeInterval?) {
            self.missionName = missionName
            self.missionType = missionType
            self.target = target
            self.hackTime = hackTime
        }
    }
}

// MARK: - Persistence tests

@MainActor
@Suite("Flight persistence")
struct FlightPersistenceTests {
    private struct TemporaryStore {
        let directory: URL
        let url: URL

        func cleanUp() {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private var sampleTarget: Target {
        Target(longitude: 0.0, latitude: 1.0)
    }

    private func makeTemporaryStore() throws -> TemporaryStore {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "FlightPersistenceTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return TemporaryStore(directory: directory, url: directory.appending(path: "store.sqlite"))
    }

    private func writeLegacyStore(at url: URL) throws {
        let schema = Schema(versionedSchema: LegacyFlightSchemaFixture.self)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
        let context = ModelContext(container)
        let legacy = LegacyFlightSchemaFixture.Flight(title: "Legacy mission", missionDate: Date(timeIntervalSince1970: 1_000_000))
        legacy.checkPoints = [LegacyFlightSchemaFixture.CheckPoint(name: "IP", longitude: 1, latitude: 2)]
        context.insert(legacy)
        try context.save()
    }

    private func writeShippedStore(at url: URL) throws {
        let schema = Schema(versionedSchema: ShippedFlightSchemaFixture.self)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
        let context = ModelContext(container)
        context.insert(ShippedFlightSchemaFixture.Flight(missionName: "Shipped mission", missionType: .hackTime, target: sampleTarget, hackTime: 30))
        try context.save()
    }

    private func writeCorruptStore(at url: URL) throws {
        try Data("this is not a SQLite database".utf8).write(to: url)
        try Data("neither is this".utf8).write(to: URL(filePath: url.path(percentEncoded: false) + "-wal"))
    }

    private func fetchFlights(named missionName: String, in context: ModelContext) throws -> [Flight] {
        try context.fetch(FetchDescriptor<Flight>(predicate: #Predicate { $0.missionName == missionName }))
    }

    // Bug demonstration (B-06): the schema carries no default for `missionType`.
    @Test("Flight.missionType declares a default value in the schema")
    func missionTypeHasSchemaDefault() throws {
        let entity = try #require(Schema([Flight.self]).entities.first { $0.name == "Flight" })
        let attribute = try #require(entity.attributesByName["missionType"])

        #expect(attribute.defaultValue as? MissionType == .tot)
    }

    // Bug demonstration (B-06): a store from the pre-versioning schema is silently lightweight-migrated,
    // leaving rows whose `missionType` column is NULL. Reading `Flight.missionType` on such a row traps
    // ("Could not cast value of type 'Swift.Optional<Any>' to 'MissionType'"), so this test never reads a
    // legacy row; it requires the store to be reset instead.
    @Test("A store written by the pre-versioning Flight schema is reset instead of migrated into unreadable rows")
    func legacyStoreIsReset() throws {
        let store = try makeTemporaryStore()
        defer { store.cleanUp() }
        try writeLegacyStore(at: store.url)

        let result = try PersistenceController.makeContainer(schema: Schema([Flight.self]), url: store.url, inMemory: false)

        #expect(result.recovered)
        let context = ModelContext(result.container)
        #expect(try context.fetchCount(FetchDescriptor<Flight>()) == 0)

        context.insert(Flight(missionName: "Fresh", missionType: .tot, missionDate: .now, target: sampleTarget))
        try context.save()
        let fresh = try fetchFlights(named: "Fresh", in: context)
        #expect(fresh.count == 1)
        #expect(fresh.first?.missionType == .tot)
    }

    // Documents the crash path the app wraps in `fatalError`: an unreadable store makes `ModelContainer` throw.
    @Test("ModelContainer throws when the store file is not a SQLite database")
    func corruptStoreMakesModelContainerThrow() throws {
        let store = try makeTemporaryStore()
        defer { store.cleanUp() }
        try writeCorruptStore(at: store.url)
        let schema = Schema([Flight.self])

        #expect(throws: (any Error).self) {
            try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: store.url)])
        }
    }

    // Bug demonstration (B-06): the factory must recover from the store above instead of propagating the error.
    @Test("The container factory recovers from an unreadable store")
    func factoryRecoversFromCorruptStore() throws {
        let store = try makeTemporaryStore()
        defer { store.cleanUp() }
        try writeCorruptStore(at: store.url)

        let result = try PersistenceController.makeContainer(schema: Schema([Flight.self]), url: store.url, inMemory: false)

        #expect(result.recovered)
        let context = ModelContext(result.container)
        context.insert(Flight(missionName: "Recovered", missionType: .hackTime, target: sampleTarget, hackTime: 10))
        try context.save()
        #expect(try fetchFlights(named: "Recovered", in: context).count == 1)

        let reopened = try PersistenceController.makeContainer(schema: Schema([Flight.self]), url: store.url, inMemory: false)
        #expect(!reopened.recovered)
        #expect(try ModelContext(reopened.container).fetchCount(FetchDescriptor<Flight>()) == 1)
    }

    // Coverage: data written by the currently shipped build must survive the fix.
    @Test("A store written by the shipped Flight schema opens without being reset")
    func shippedStoreIsPreserved() throws {
        let store = try makeTemporaryStore()
        defer { store.cleanUp() }
        try writeShippedStore(at: store.url)

        let result = try PersistenceController.makeContainer(schema: Schema([Flight.self]), url: store.url, inMemory: false)

        #expect(!result.recovered)
        let flights = try fetchFlights(named: "Shipped mission", in: ModelContext(result.container))
        #expect(flights.count == 1)
        #expect(flights.first?.missionType == .hackTime)
        #expect(flights.first?.hackTime == 30)
    }

    // Coverage: a store the factory itself created reopens untouched.
    @Test("A store created by the factory reopens without being reset")
    func factoryStoreReopens() throws {
        let store = try makeTemporaryStore()
        defer { store.cleanUp() }

        let first = try PersistenceController.makeContainer(schema: Schema([Flight.self]), url: store.url, inMemory: false)
        #expect(!first.recovered)
        let context = ModelContext(first.container)
        context.insert(Flight(missionName: "Round trip", missionType: .tot, missionDate: .now, target: sampleTarget))
        try context.save()

        let second = try PersistenceController.makeContainer(schema: Schema([Flight.self]), url: store.url, inMemory: false)
        #expect(!second.recovered)
        #expect(try fetchFlights(named: "Round trip", in: ModelContext(second.container)).count == 1)
    }

    // Coverage: the schema is versioned and the migration plan starts at V1.
    @Test("FlightMigrationPlan starts at FlightSchemaV1 and opens a fresh store")
    func migrationPlanStartsAtV1() throws {
        #expect(FlightMigrationPlan.schemas.count == 1)
        #expect(FlightMigrationPlan.schemas.contains { $0 == FlightSchemaV1.self })
        #expect(FlightMigrationPlan.stages.isEmpty)
        #expect(FlightSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(FlightSchemaV1.models.contains { $0 == Flight.self })

        let store = try makeTemporaryStore()
        defer { store.cleanUp() }
        let schema = Schema(versionedSchema: FlightSchemaV1.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FlightMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, url: store.url)]
        )
        let context = ModelContext(container)
        context.insert(Flight(missionName: "Versioned", missionType: .hackTime, target: sampleTarget, hackTime: 5))
        try context.save()
        #expect(try fetchFlights(named: "Versioned", in: context).count == 1)
    }

    // Coverage: the UI-test launch argument path keeps the store in memory.
    @Test("An in-memory container is never reported as recovered")
    func inMemoryContainer() throws {
        let result = try PersistenceController.makeContainer(schema: Schema([Flight.self]), url: nil, inMemory: true)

        #expect(!result.recovered)
        let context = ModelContext(result.container)
        context.insert(Flight(missionName: "Memory", missionType: .tot, missionDate: .now, target: sampleTarget))
        try context.save()
        #expect(try fetchFlights(named: "Memory", in: context).count == 1)
    }
}

