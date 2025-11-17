import Testing
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
        
        #expect(sut.flightEditorConfig.isPresented)
        #expect(sut.flightEditorConfig.shouldSaveChanges == false)
        #expect(sut.flightEditorConfig.flight.title == "")
    }
    
    @Test("presentAddFlight called twice keeps a fresh empty flight")
    func presentAddFlight_idempotent() async throws {
        let sut = FlightsListViewModel()
        
        sut.presentAddFlight()
        sut.flightEditorConfig.flight.title = "Temp"
        sut.presentAddFlight()
        
        #expect(sut.flightEditorConfig.isPresented)
        #expect(sut.flightEditorConfig.flight.title == "") // reset to empty flight
    }
    
    @Test("presentEditFlight loads flight and presents editor")
    func presentEditFlight_loadsFlight() async throws {
        let sut = FlightsListViewModel()
        let flight = Flight.emptyFlight()
        flight.title = "Edit Me"
        
        sut.presentEditFlight(flight)
        
        #expect(sut.flightEditorConfig.isPresented)
        #expect(sut.flightEditorConfig.shouldSaveChanges == false)
        #expect(sut.flightEditorConfig.flight.title == "Edit Me")
    }
    
    // MARK: - Save flow
    @Test("didDismissEditor no-op when shouldSaveChanges is false")
    func didDismissEditor_noop_whenNotSaving() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let sut = FlightsListViewModel()
        
        sut.flightEditorConfig.presentAddFlight()
        sut.flightEditorConfig.flight.title = "Won't Save"
        sut.flightEditorConfig.shouldSaveChanges = false
        sut.flightEditorConfig.isPresented = false
        
        sut.didDismissEditor(modelContext: context)
        
        let flights = try context.fetch(FetchDescriptor<Flight>())
        #expect(flights.isEmpty)
        #expect(sut.validationMessage == nil)
    }
    
    @Test("didDismissEditor rejects whitespace-only title")
    func didDismissEditor_rejectsWhitespaceOnlyTitle() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let sut = FlightsListViewModel()
        
        sut.flightEditorConfig.presentAddFlight()
        sut.flightEditorConfig.flight.title = "   \n\t  "
        sut.flightEditorConfig.shouldSaveChanges = true
        sut.flightEditorConfig.isPresented = false
        
        sut.didDismissEditor(modelContext: context)
        
        #expect(sut.validationMessage != nil)
        #expect(sut.flightEditorConfig.isPresented) // re-present editor
        let flights = try context.fetch(FetchDescriptor<Flight>())
        #expect(flights.isEmpty)
    }
    
    @Test("didDismissEditor with valid title inserts flight")
    func didDismissEditor_validTitle_inserts() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let sut = FlightsListViewModel()
        
        sut.flightEditorConfig.presentAddFlight()
        sut.flightEditorConfig.flight.title = "Valid Flight"
        sut.flightEditorConfig.shouldSaveChanges = true
        sut.flightEditorConfig.isPresented = false
        
        sut.didDismissEditor(modelContext: context)
        
        let flights = try context.fetch(FetchDescriptor<Flight>())
        #expect(flights.count == 1)
        #expect(flights.first?.title == "Valid Flight")
    }
    
    // MARK: - Settings
    @Test("presentSettings sets isPresented on settingsConfig")
    func presentSettings_setsPresented() async throws {
        let sut = FlightsListViewModel()
        #expect(sut.settingsConfig.isPresented == false)
        
        sut.presentSettings()
        
        #expect(sut.settingsConfig.isPresented == true)
    }
    
    // MARK: - Deletion flow
    @Test("requestDelete sets pending flight and shows confirmation")
    func requestDelete_setsState() async throws {
        let sut = FlightsListViewModel()
        let flight = Flight.emptyFlight()
        flight.title = "Delete Me"
        
        sut.requestDelete(flight: flight)
        
        #expect(sut.pendingDeleteFlight?.id == flight.id)
        #expect(sut.showDeleteConfirmation)
    }
    
    @Test("confirmDelete without pending flight is a no-op")
    func confirmDelete_noPending_noop() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let sut = FlightsListViewModel()
        
        // No pendingDeleteFlight set
        sut.confirmDelete(modelContext: context)
        
        #expect(sut.pendingDeleteFlight == nil)
        #expect(sut.showDeleteConfirmation == false)
        let remaining = try context.fetch(FetchDescriptor<Flight>())
        #expect(remaining.isEmpty)
    }
    
    @Test("confirmDelete deletes and clears state")
    func confirmDelete_deletes() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        
        let flight = Flight(title: "Seed", missionDate: .now, expectedWinds: Winds(velocity: 0, direction: 0), checkPoints: [])
        context.insert(flight)
        
        var all = try context.fetch(FetchDescriptor<Flight>())
        #expect(all.count == 1)
        
        let sut = FlightsListViewModel()
        sut.requestDelete(flight: flight)
        sut.confirmDelete(modelContext: context)
        
        #expect(sut.pendingDeleteFlight == nil)
        #expect(sut.showDeleteConfirmation == false)
        
        all = try context.fetch(FetchDescriptor<Flight>())
        #expect(all.isEmpty)
    }
    
    @Test("cancelDelete clears state")
    func cancelDelete_clears() async throws {
        let sut = FlightsListViewModel()
        sut.requestDelete(flight: Flight.emptyFlight())
        
        sut.cancelDelete()
        
        #expect(sut.pendingDeleteFlight == nil)
        #expect(sut.showDeleteConfirmation == false)
    }
    
    @Test("handleOnDelete with empty index set is a no-op")
    func handleOnDelete_emptyIndexSet_noop() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        
        let f1 = Flight(title: "One", missionDate: .now, expectedWinds: Winds(velocity: 0, direction: 0), checkPoints: [])
        let f2 = Flight(title: "Two", missionDate: .now, expectedWinds: Winds(velocity: 0, direction: 0), checkPoints: [])
        context.insert(f1); context.insert(f2)
        
        let sut = FlightsListViewModel()
        sut.handleOnDelete(indexSet: IndexSet(), flights: [f1, f2], modelContext: context)
        
        let remaining = try context.fetch(FetchDescriptor<Flight>())
        #expect(remaining.count == 2)
        #expect(sut.pendingDeleteFlight == nil)
        #expect(sut.showDeleteConfirmation == false)
    }
    
    @Test("handleOnDelete single index routes to confirmation")
    func handleOnDelete_single() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        
        let f1 = Flight(title: "One", missionDate: .now, expectedWinds: Winds(velocity: 0, direction: 0), checkPoints: [])
        let f2 = Flight(title: "Two", missionDate: .now, expectedWinds: Winds(velocity: 0, direction: 0), checkPoints: [])
        context.insert(f1); context.insert(f2)
        
        let sut = FlightsListViewModel()
        sut.handleOnDelete(indexSet: IndexSet(integer: 1), flights: [f1, f2], modelContext: context)
        
        #expect(sut.pendingDeleteFlight?.id == f2.id)
        #expect(sut.showDeleteConfirmation)
    }
    
    @Test("handleOnDelete multiple indices deletes directly")
    func handleOnDelete_multiple() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        
        let f1 = Flight(title: "One", missionDate: .now, expectedWinds: Winds(velocity: 0, direction: 0), checkPoints: [])
        let f2 = Flight(title: "Two", missionDate: .now, expectedWinds: Winds(velocity: 0, direction: 0), checkPoints: [])
        let f3 = Flight(title: "Three", missionDate: .now, expectedWinds: Winds(velocity: 0, direction: 0), checkPoints: [])
        context.insert(f1); context.insert(f2); context.insert(f3)
        
        let sut = FlightsListViewModel()
        sut.handleOnDelete(indexSet: IndexSet([0, 2]), flights: [f1, f2, f3], modelContext: context)
        
        let remaining = try context.fetch(FetchDescriptor<Flight>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.id == f2.id)
        
        #expect(sut.pendingDeleteFlight == nil)
        #expect(sut.showDeleteConfirmation == false)
    }
    
    // MARK: - Direct delete API
    @Test("delete removes flight immediately")
    func delete_removesImmediately() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        
        let f = Flight(title: "Direct", missionDate: .now, expectedWinds: Winds(velocity: 0, direction: 0), checkPoints: [])
        context.insert(f)
        
        let sut = FlightsListViewModel()
        sut.delete(f, modelContext: context)
        
        let remaining = try context.fetch(FetchDescriptor<Flight>())
        #expect(remaining.isEmpty)
    }
    
    // MARK: - Lifecycle smoke tests
    @Test("start/stop monitoring are callable without crashing")
    func lifecycle_smoke() async throws {
        let sut = FlightsListViewModel()
        sut.startMonitoring()
        sut.stopMonitoring()
        // No expectations; just ensure no crash and main-actor reentrancy is fine.
        #expect(true)
    }
}
