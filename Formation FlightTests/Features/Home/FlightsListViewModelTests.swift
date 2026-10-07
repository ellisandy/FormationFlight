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

    /// Builds a view model that touches neither `UserDefaults.standard` nor
    /// `LocationProvider.shared`, so tests are hermetic and never start Core Location.
    ///
    /// `MockLocationProvider` is the shared, top-level mock declared in
    /// `FlightViewModelTests.swift` (same test module).
    private func makeSUT(locationProvider: MockLocationProvider = MockLocationProvider()) -> FlightsListViewModel {
        FlightsListViewModel(settings: .empty(), locationProvider: locationProvider)
    }

    // MARK: - Editor coordination
    @Test("presentAddFlight sets editor presented and resets flight")
    func presentAddFlight_setsPresented() async throws {
        let sut = makeSUT()

        sut.presentAddFlight()

        #expect(sut.isPresentingEditFlight)
    }

    // MARK: - Editor coordination (edit / cancel)
    @Test("presentEditFlight sets selectedFlight and presents editor")
    func presentEditFlight_setsState() async throws {
        let sut = makeSUT()
        let flight = Flight(missionName: "Test", missionType: .hackTime, missionDate: .now, target: Target(longitude: 1, latitude: 2))

        sut.presentEditFlight(flight)

        #expect(sut.selectedFlight?.id == flight.id)
        #expect(sut.isPresentingEditFlight)
    }

    @Test("cancelEditor resets selection and hides editor")
    func cancelEditor_resetsState() async throws {
        let sut = makeSUT()
        sut.isPresentingEditFlight = true
        sut.selectedFlight = Flight(missionName: "X", missionType: .hackTime, missionDate: .now, target: Target(longitude: 0, latitude: 0))

        sut.cancelEditor()

        #expect(sut.selectedFlight == nil)
        #expect(!sut.isPresentingEditFlight)
    }

    // MARK: - Settings coordination
    @Test("presentSettings toggles presentation flag")
    func presentSettings_setsFlag() async throws {
        let sut = makeSUT()
        sut.presentSettings()
        #expect(sut.isPresentingSettings)
    }

    @Test("dismissSettings reloads settings and hides sheet")
    func dismissSettings_hides() async throws {
        let sut = makeSUT()
        sut.isPresentingSettings = true
        sut.dismissSettings()
        #expect(!sut.isPresentingSettings)
    }

    // MARK: - Location monitoring
    @Test("start/stop monitoring forwards to provider")
    func monitoring_forwards() async throws {
        let mock = MockLocationProvider()
        let sut = makeSUT(locationProvider: mock)
        sut.startMonitoring()
        sut.stopMonitoring()
        #expect(mock.startMonitoringCallCount == 1)
        #expect(mock.stopMonitoringCallCount == 1)
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
        let sut = makeSUT()
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
        let sut = makeSUT()
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

        let sut = makeSUT()
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

        let sut = makeSUT()
        let editor = FlightEditorViewModel(flight: existing)
        editor.selectedTargetLocation = nil

        sut.updateFlight(existing, from: editor, modelContext: context)

        #expect(sut.validationMessage != nil)
    }

    // MARK: - Deletion flow
    @Test("requestDelete sets pending and shows confirmation")
    func requestDelete_setsState() async throws {
        let sut = makeSUT()
        let f = Flight(missionName: "ToDelete", missionType: .hackTime, missionDate: .now, target: Target(longitude: 0, latitude: 0))
        sut.requestDelete(flight: f)
        #expect(sut.pendingDeleteFlight?.id == f.id)
        #expect(sut.showDeleteConfirmation)
    }

    @Test("confirmDelete deletes pending flight and resets state when present")
    func confirmDelete_withPending_deletesAndResets() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let f = insertSampleFlight(into: context, name: "Pending")
        try context.save()

        let sut = makeSUT()
        sut.pendingDeleteFlight = f
        sut.showDeleteConfirmation = true

        sut.confirmDelete(modelContext: context)

        let flights = try context.fetch(FetchDescriptor<Flight>())
        #expect(!flights.contains { $0.id == f.id })
        #expect(sut.pendingDeleteFlight == nil)
        #expect(!sut.showDeleteConfirmation)
    }

    /// B-30: `confirmDelete` must persist the deletion, not just stage it in the caller's
    /// context. A plain `ModelContext` has autosave disabled, so a second context on the
    /// same container only observes the deletion once `save()` has been called.
    @Test("confirmDelete persists the deletion so a fresh context no longer sees the flight")
    func confirmDelete_persistsDeletion() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let f = insertSampleFlight(into: context, name: "Persisted")
        try context.save()

        let sut = makeSUT()
        sut.requestDelete(flight: f)

        sut.confirmDelete(modelContext: context)

        let freshContext = ModelContext(container)
        let flights = try freshContext.fetch(FetchDescriptor<Flight>())
        #expect(!flights.contains { $0.id == f.id })
        #expect(sut.validationMessage == nil)
    }

    @Test("confirmDelete with no pending hides confirmation and does nothing")
    func confirmDelete_withoutPending_doesNothing() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let f = insertSampleFlight(into: context, name: "Keep")
        try context.save()

        let sut = makeSUT()
        sut.pendingDeleteFlight = nil
        sut.showDeleteConfirmation = true

        sut.confirmDelete(modelContext: context)

        let flights = try context.fetch(FetchDescriptor<Flight>())
        #expect(flights.contains { $0.id == f.id })
        #expect(sut.pendingDeleteFlight == nil)
        #expect(!sut.showDeleteConfirmation)
    }

    @Test("cancelDelete resets state without deleting")
    func cancelDelete_resets() async throws {
        let sut = makeSUT()
        sut.pendingDeleteFlight = Flight(missionName: "X", missionType: .hackTime, missionDate: .now, target: Target(longitude: 0, latitude: 0))
        sut.showDeleteConfirmation = true

        sut.cancelDelete()

        #expect(sut.pendingDeleteFlight == nil)
        #expect(!sut.showDeleteConfirmation)
    }

    // MARK: - Deletion flow: name snapshot (B-30)
    @Test("requestDelete captures the pending flight's name for the alert")
    func requestDelete_capturesName() async throws {
        let sut = makeSUT()
        let f = Flight(missionName: "Bravo Two", missionType: .hackTime, missionDate: .now, target: Target(longitude: 0, latitude: 0))

        sut.requestDelete(flight: f)

        #expect(sut.pendingDeleteFlightName == "Bravo Two")
    }

    @Test("cancelDelete clears the captured name")
    func cancelDelete_clearsName() async throws {
        let sut = makeSUT()
        sut.requestDelete(flight: Flight(missionName: "Cancelled", missionType: .hackTime, missionDate: .now, target: Target(longitude: 0, latitude: 0)))

        sut.cancelDelete()

        #expect(sut.pendingDeleteFlightName == nil)
    }

    @Test("confirmDelete clears the captured name")
    func confirmDelete_clearsName() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let f = insertSampleFlight(into: context, name: "Confirmed")
        try context.save()
        let sut = makeSUT()
        sut.requestDelete(flight: f)

        sut.confirmDelete(modelContext: context)

        #expect(sut.pendingDeleteFlightName == nil)
    }
}
