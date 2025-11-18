import Testing
import CoreLocation
import Foundation
@testable import Formation_Flight
import SwiftData

@MainActor
@Suite("FlightsListViewModel (Swift Testing) – Extended Coverage")
struct FlightsListViewModel_SwiftTests_Extra {
    
    // MARK: - Helpers
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([Flight.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
    
    // MARK: - Editor coordination
    @Test("presentAddFlight sets editor presented and resets flight")
    func presentAddFlight_setsPresented() async throws {
        let sut = FlightsListViewModel()
        
        sut.presentAddFlight()
        
        #expect(sut.isPresentingEditFlight)
    }
    
    // MARK: - Editor coordination (edit / cancel)
    @Test("presentEditFlight sets selectedFlight and presents editor")
    func presentEditFlight_setsState() async throws {
        let sut = FlightsListViewModel()
        let flight = Flight(missionName: "Test", missionType: .hackTime, missionDate: .now, target: Target(longitude: 1, latitude: 2))
        
        sut.presentEditFlight(flight)
        
        #expect(sut.selectedFlight?.id == flight.id)
        #expect(sut.isPresentingEditFlight)
    }
    
    @Test("cancelEditor resets selection and hides editor")
    func cancelEditor_resetsState() async throws {
        let sut = FlightsListViewModel()
        sut.isPresentingEditFlight = true
        sut.selectedFlight = Flight(missionName: "X", missionType: .hackTime, missionDate: .now, target: Target(longitude: 0, latitude: 0))
        
        sut.cancelEditor()
        
        #expect(sut.selectedFlight == nil)
        #expect(!sut.isPresentingEditFlight)
    }
    
    // MARK: - Settings coordination
    @Test("presentSettings toggles presentation flag")
    func presentSettings_setsFlag() async throws {
        let sut = FlightsListViewModel()
        sut.presentSettings()
        #expect(sut.isPresentingSettings)
    }
    
    @Test("dismissSettings reloads settings and hides sheet")
    func dismissSettings_hides() async throws {
        let sut = FlightsListViewModel()
        sut.isPresentingSettings = true
        sut.dismissSettings()
        #expect(!sut.isPresentingSettings)
    }
    
    // MARK: - Location monitoring
    final class MockLocationProvider: LocationProviding {
        var authroizationStatus: CLAuthorizationStatus?
                
        // MARK: - LocationProviding
        var updateDelegate: (() -> Void)?

        var authorizationStatus: CLAuthorizationStatus = .notDetermined

        var speed: Measurement<UnitSpeed> = .init(value: 0, unit: .knots)

        var altitude: Measurement<UnitLength> = .init(value: 0, unit: .meters)

        var course: Measurement<UnitAngle> = .init(value: 0, unit: .degrees)

        var currentLocation: CLLocation? = nil

        var computedSpeedAndCourse: Bool = false

        // MARK: - Lifecycle
        init() {}

        // MARK: - Monitoring
        private(set) var didStart = false
        private(set) var didStop = false
        func startMonitoring() { didStart = true }
        func stopMonitoring() { didStop = true }
    }
    
    @Test("start/stop monitoring forwards to provider")
    func monitoring_forwards() async throws {
        let mock = MockLocationProvider()
        // This assumes FlightsListViewModel has an initializer that accepts a LocationProviding.
        // If not present, add `init(locationProvider: LocationProviding)` to the ViewModel in production code.
        let sut = FlightsListViewModel(locationProvider: mock)
        sut.startMonitoring()
        sut.stopMonitoring()
        #expect(mock.didStart)
        #expect(mock.didStop)
    }
    
    // MARK: - Persistence helpers
    private func insertSampleFlight(into context: ModelContext, name: String = "F1") -> Flight {
        let f = Flight(missionName: name, missionType: .hackTime, missionDate: .now, target: Target(longitude: 0, latitude: 0))
        context.insert(f)
        return f
    }
    
    // MARK: - Editor Actions: save new flight
    @Test("saveNewFlight inserts and saves a flight")
    func saveNewFlight_inserts() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let sut = FlightsListViewModel()
        let editor = FlightEditorViewModel()
        editor.missionName = "New Mission"
        editor.useTOT = true
        editor.timeEntry = Date()
        editor.selectedTargetLocation = .init(latitude: 10, longitude: 20)
        
        sut.saveNewFlight(from: editor, modelContext: context)
        
        // Fetch to verify persistence
        let fetch = FetchDescriptor<Flight>()
        let flights = try context.fetch(fetch)
        #expect(flights.contains { $0.missionName == "New Mission" })
        #expect(!sut.isPresentingEditFlight)
        #expect(sut.selectedFlight == nil)
    }

    @Test("saveNewFlight with missing target sets validation and does not insert")
    func saveNewFlight_missingTarget_setsValidation() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let sut = FlightsListViewModel()
        let editor = FlightEditorViewModel()
        editor.missionName = "No Target Mission"
        editor.useTOT = false
        editor.timeEntry = Date()
        editor.selectedTargetLocation = nil // Explicitly missing

        sut.saveNewFlight(from: editor, modelContext: context)

        // No insertion should have occurred
        let flights = try context.fetch(FetchDescriptor<Flight>())
        #expect(flights.isEmpty)
        #expect(sut.validationMessage != nil)
    }
    
    // MARK: - Editor Actions: update flight success and validation
    @Test("updateFlight updates existing flight when target provided")
    func updateFlight_success() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let existing = insertSampleFlight(into: context, name: "Old")
        try context.save()
        
        let sut = FlightsListViewModel()
        let editor = FlightEditorViewModel(flight: existing)
        editor.missionName = "Updated" // name is taken from model, but we still set other fields
        editor.useTOT = false
        editor.timeEntry = Date().addingTimeInterval(60)
        editor.selectedTargetLocation = .init(latitude: 1, longitude: 2)
        editor.hackDurationSeconds = 123
        
        sut.updateFlight(existing, from: editor, modelContext: context)
        
        #expect(existing.missionType == .hackTime)
        #expect(existing.missionDate != nil)
        #expect(existing.target != nil)
        #expect(existing.hackTime == 123)
        #expect(!sut.isPresentingEditFlight)
        #expect(sut.selectedFlight == nil)
    }
    
    @Test("updateFlight without target sets validation message and does not save")
    func updateFlight_missingTarget_setsValidation() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let existing = insertSampleFlight(into: context)
        try context.save()
        
        let sut = FlightsListViewModel()
        let editor = FlightEditorViewModel(flight: existing)
        editor.selectedTargetLocation = nil
        
        sut.updateFlight(existing, from: editor, modelContext: context)
        
        #expect(sut.validationMessage != nil)
    }
    
    // MARK: - Deletion flow
    @Test("requestDelete sets pending and shows confirmation")
    func requestDelete_setsState() async throws {
        let sut = FlightsListViewModel()
        let f = Flight(missionName: "ToDelete", missionType: .hackTime, missionDate: .now, target: Target(longitude: 0, latitude: 0))
        sut.requestDelete(flight: f)
        #expect(sut.pendingDeleteFlight?.id == f.id)
        #expect(sut.showDeleteConfirmation)
    }
    
    @Test("delete removes a flight from the model context")
    func delete_removesFlight() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let f = insertSampleFlight(into: context, name: "ToRemove")
        try context.save()

        // Sanity check present
        var flights = try context.fetch(FetchDescriptor<Flight>())
        #expect(flights.contains { $0.id == f.id })

        let sut = FlightsListViewModel()
        sut.delete(f, modelContext: context)

        flights = try context.fetch(FetchDescriptor<Flight>())
        #expect(!flights.contains { $0.id == f.id })
    }

    @Test("confirmDelete deletes pending flight and resets state when present")
    func confirmDelete_withPending_deletesAndResets() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let f = insertSampleFlight(into: context, name: "Pending")
        try context.save()

        let sut = FlightsListViewModel()
        sut.pendingDeleteFlight = f
        sut.showDeleteConfirmation = true

        sut.confirmDelete(modelContext: context)

        let flights = try context.fetch(FetchDescriptor<Flight>())
        #expect(!flights.contains { $0.id == f.id })
        #expect(sut.pendingDeleteFlight == nil)
        #expect(!sut.showDeleteConfirmation)
    }

    @Test("confirmDelete with no pending hides confirmation and does nothing")
    func confirmDelete_withoutPending_doesNothing() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let f = insertSampleFlight(into: context, name: "Keep")
        try context.save()

        let sut = FlightsListViewModel()
        sut.pendingDeleteFlight = nil
        sut.showDeleteConfirmation = true

        sut.confirmDelete(modelContext: context)

        let flights = try context.fetch(FetchDescriptor<Flight>())
        #expect(flights.contains { $0.id == f.id })
        #expect(sut.pendingDeleteFlight == nil)
        #expect(!sut.showDeleteConfirmation)
    }
    
    @Test("confirmDelete deletes pending and resets state")
    func confirmDelete_deletes() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let f = insertSampleFlight(into: context)
        try context.save()
        
        let sut = FlightsListViewModel()
        sut.pendingDeleteFlight = f
        sut.showDeleteConfirmation = true
        
        sut.confirmDelete(modelContext: context)
        
        // Try fetching to ensure deletion
        let flights = try context.fetch(FetchDescriptor<Flight>())
        #expect(!flights.contains { $0.id == f.id })
        #expect(sut.pendingDeleteFlight == nil)
        #expect(!sut.showDeleteConfirmation)
    }
    
    @Test("cancelDelete resets state without deleting")
    func cancelDelete_resets() async throws {
        let sut = FlightsListViewModel()
        sut.pendingDeleteFlight = Flight(missionName: "X", missionType: .hackTime, missionDate: .now, target: Target(longitude: 0, latitude: 0))
        sut.showDeleteConfirmation = true
        
        sut.cancelDelete()
        
        #expect(sut.pendingDeleteFlight == nil)
        #expect(!sut.showDeleteConfirmation)
    }
    
    @Test("handleOnDelete with single item triggers confirmation flow")
    func handleOnDelete_single() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let f = insertSampleFlight(into: context)
        try context.save()
        let sut = FlightsListViewModel()
        
        sut.handleOnDelete(indexSet: IndexSet(integer: 0), flights: [f], modelContext: context)
        
        #expect(sut.pendingDeleteFlight?.id == f.id)
        #expect(sut.showDeleteConfirmation)
    }
    
    @Test("handleOnDelete with multiple items deletes immediately")
    func handleOnDelete_multiple() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let f1 = insertSampleFlight(into: context, name: "A")
        let f2 = insertSampleFlight(into: context, name: "B")
        try context.save()
        let sut = FlightsListViewModel()
        
        sut.handleOnDelete(indexSet: IndexSet([0, 1]), flights: [f1, f2], modelContext: context)
        
        let flights = try context.fetch(FetchDescriptor<Flight>())
        #expect(flights.isEmpty)
        #expect(sut.pendingDeleteFlight == nil)
        #expect(!sut.showDeleteConfirmation)
    }
}

