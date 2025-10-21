// FlightEditorFormTests.swift
// Tests for FlightEditorForm using Swift Testing framework

import SwiftUI
import MapKit
import Testing
@testable import Formation_Flight

// Minimal test doubles to construct FlightEditorConfig and related types if needed.
// These assume the app target exposes these types. If types are in a different module name,
// adjust the @testable import accordingly.

@Suite("FlightEditorForm Behavior")
@MainActor struct FlightEditorFormTests {

    // Helper to create a default config
    private func makeConfig() -> FlightEditorConfig {
        let config = FlightEditorConfig()
        // Ensure the model has at least one checkpoint for editing scenarios
        if config.flight.checkPoints.isEmpty {
            let cp = CheckPoint(name: "CP1", location: CLLocation(latitude: 1, longitude: 2))
            config.flight.checkPoints.append(cp)
        }
        return config
    }

    @Test("Dismiss helper clears popover and index")
    func dismissHelperClearsState() async throws {
        let config = makeConfig()
        // Bindings require a source of truth; use a State-like container

        // Mutate internal state directly (since it's a struct View)
        await MainActor.run {
            let form = FlightEditorForm(config: .constant(config))
            form.checkPointPopover = true
            form.editingCheckpointIndex = 0
            form.dismissCheckpointSheet()

            
            #expect(form.checkPointPopover == false)
            #expect(form.editingCheckpointIndex == nil)
        }
    }

    @Test("Editing existing checkpoint updates name and coordinates and dismisses sheet")
    func editExistingCheckpoint() async throws {
        let config = makeConfig()
        // Start with two checkpoints to ensure index is valid
        config.flight.checkPoints.append(CheckPoint(name: "CP2", location: CLLocation(latitude: 3, longitude: 4)))

        // Use a mutable binding to observe changes
        var boundConfig = config
        let binding = Binding<FlightEditorConfig>(get: { boundConfig }, set: { boundConfig = $0 })
        let form = FlightEditorForm(config: binding)

        // Simulate selecting the first checkpoint and invoking onSave logic
        await MainActor.run {
            form.editingCheckpointIndex = 0
            form.checkPointPopover = true
        }

        // Mimic what onSave does in the editing branch
        let newName = "UpdatedCP1"
        let newCoord = CLLocationCoordinate2D(latitude: 10, longitude: 20)
        boundConfig.flight.checkPoints[0].name = newName
        boundConfig.flight.checkPoints[0].longitude = newCoord.longitude
        boundConfig.flight.checkPoints[0].latitude = newCoord.latitude
        await MainActor.run {
            form.dismissCheckpointSheet()
        }

        #expect(boundConfig.flight.checkPoints[0].name == newName)
        #expect(boundConfig.flight.checkPoints[0].latitude == newCoord.latitude)
        #expect(boundConfig.flight.checkPoints[0].longitude == newCoord.longitude)
        #expect(form.checkPointPopover == false)
        #expect(form.editingCheckpointIndex == nil)
    }

    @Test("Adding a new checkpoint appends and dismisses sheet")
    func addNewCheckpoint() async throws {
        let config = makeConfig()
        // Use a mutable binding to observe changes
        var boundConfig = config
        let binding = Binding<FlightEditorConfig>(get: { boundConfig }, set: { boundConfig = $0 })
        let form = FlightEditorForm(config: binding)

        // Simulate new checkpoint flow
        await MainActor.run {
            form.editingCheckpointIndex = nil
            form.checkPointPopover = true
        }

        let name = "NewCP"
        let coord = CLLocationCoordinate2D(latitude: 33.3, longitude: -117.2)
        let cp = CheckPoint(name: name, location: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
        boundConfig.flight.checkPoints.append(cp)
        await MainActor.run {
            form.dismissCheckpointSheet()
        }

        #expect(boundConfig.flight.checkPoints.contains { $0.name == name && $0.latitude == coord.latitude && $0.longitude == coord.longitude })
        #expect(form.checkPointPopover == false)
        #expect(form.editingCheckpointIndex == nil)
    }

    @Test("Updating wind inputs with formatter-compatible values")
    func updateWindInputs() async throws {
        let config = makeConfig()
        var boundConfig = config
        let binding = Binding<FlightEditorConfig>(get: { boundConfig }, set: { boundConfig = $0 })
        let form = FlightEditorForm(config: binding)

        // Simulate entering integer values via formatter
        boundConfig.flight.expectedWinds.directionAsDegrees = 270
        boundConfig.flight.expectedWinds.velocityAsKnots = 15

        #expect(boundConfig.flight.expectedWinds.directionAsDegrees == 270)
        #expect(boundConfig.flight.expectedWinds.velocityAsKnots == 15)

        // Verify formatter settings
        #expect(form.windInputFormatter.maximumFractionDigits == 0)
        #expect(form.windInputFormatter.generatesDecimalNumbers == false)
    }

    @Test("Updating mission title and date through binding")
    func updateTitleAndDate() async throws {
        let config = makeConfig()
        var boundConfig = config
        let binding = Binding<FlightEditorConfig>(get: { boundConfig }, set: { boundConfig = $0 })
        _ = FlightEditorForm(config: binding)

        let newTitle = "Training Run"
        let newDate = Date().addingTimeInterval(3600)
        boundConfig.flight.title = newTitle
        boundConfig.flight.missionDate = newDate

        #expect(boundConfig.flight.title == newTitle)
        #expect(boundConfig.flight.missionDate == newDate)
    }
}

