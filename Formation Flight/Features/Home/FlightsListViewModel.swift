//
//  FlightsListViewModel.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/15/23.
//

import Foundation
import SwiftData

@MainActor
final class FlightsListViewModel: ObservableObject {
    // Centralized loggers
    private let logger = AppLogger.viewModel
    private let dataLog = AppLogger.data

    let locationProvider: LocationProviding
    
    // Validation feedback
    @Published var validationMessage: String?
    
    // UI presentation flags
    @Published var isPresentingSettings: Bool = false
    @Published var isPresentingEditFlight: Bool = false
    @Published var selectedFlight: Flight?
    
    @Published var settings: Settings = Settings.load(from: UserDefaults.standard)
    
    // Deletion coordination
    @Published var pendingDeleteFlight: Flight? {
        didSet { pendingDeleteFlightName = pendingDeleteFlight?.missionName }
    }
    /// Snapshot of the pending flight's name, captured when deletion is requested.
    ///
    /// The confirmation alert reads this instead of `pendingDeleteFlight.missionName`
    /// so the dismiss animation never touches a model that has already been deleted
    /// from the context.
    @Published private(set) var pendingDeleteFlightName: String?
    @Published var showDeleteConfirmation: Bool = false
    
    init(validationMessage: String? = nil,
         isPresentingSettings: Bool = false,
         isPresentingEditFlight: Bool = false,
         selectedFlight: Flight? = nil,
         settings: Settings = Settings.load(from: UserDefaults.standard),
         pendingDeleteFlight: Flight? = nil,
         showDeleteConfirmation: Bool = false,
         locationProvider: LocationProviding = LocationProvider.shared) {
        self.validationMessage = validationMessage
        self.isPresentingSettings = isPresentingSettings
        self.isPresentingEditFlight = isPresentingEditFlight
        self.selectedFlight = selectedFlight
        self.settings = settings
        self.pendingDeleteFlight = pendingDeleteFlight
        // Property observers do not run inside the initializer.
        self.pendingDeleteFlightName = pendingDeleteFlight?.missionName
        self.showDeleteConfirmation = showDeleteConfirmation
        self.locationProvider = locationProvider
    }
    
    // MARK: - Lifecycle
    func startMonitoring() {
        logger.debug("Starting location monitoring")
        locationProvider.startMonitoring()
    }
    
    func stopMonitoring() {
        logger.debug("Stopping location monitoring")
        locationProvider.stopMonitoring()
    }
    
    // MARK: - Editor Coordination
    func presentAddFlight() {
        logger.debug("Present add flight")
        selectedFlight = nil
        isPresentingEditFlight = true
    }
    
    func presentEditFlight(_ flight: Flight) {
        logger.debug("Present edit flight: \(flight.missionName, privacy: .private)")
        selectedFlight = flight
        isPresentingEditFlight = true
    }
    
    // MARK: - Editor Actions (Closures from Child)
    func saveNewFlight(from editorVM: FlightEditorViewModel, modelContext: ModelContext) {
        // `Flight.init` needs a target, so a draft without one is reported through the shared
        // rules before a model can be built; every other rule runs via `validFlight()` below.
        guard let location = editorVM.selectedTargetLocation else {
            validationMessage = editorVM.goFlyValidationMessage ?? FlightValidation.missingTargetMessage
            return
        }

        // B-14: only the field that belongs to the mission type is written; the other is nil.
        let flight = Flight(missionName: editorVM.missionName,
                            missionType: editorVM.missionType,
                            missionDate: editorVM.missionDateToSave,
                            target: Target(longitude: location.longitude, latitude: location.latitude),
                            hackTime: editorVM.hackTimeToSave)
        let validation = flight.validFlight()
        guard validation.valid else {
            validationMessage = validation.message
            return
        }

        validationMessage = nil
        modelContext.insert(flight)
        do {
            try modelContext.save()
            isPresentingEditFlight = false
            selectedFlight = nil
        } catch {
            dataLog.error("Failed to save new flight: \(String(describing: error), privacy: .public)")
            validationMessage = String(localized: "Failed to save flight. Please try again.",
                                       comment: "Shown when persisting a new flight fails")
        }
    }

    func updateFlight(_ flight: Flight, from editorVM: FlightEditorViewModel, modelContext: ModelContext) {
        dataLog.info("Updating existing flight: \(flight.missionName, privacy: .private)")
        guard let location = editorVM.selectedTargetLocation else {
            validationMessage = editorVM.goFlyValidationMessage ?? FlightValidation.missingTargetMessage
            return
        }

        // B-14: validate the draft BEFORE touching the model. `ModelContext.rollback()` does
        // not reliably revert values already cached on a fetched `@Model` instance, so a
        // rejected edit applied first would linger on screen as a phantom change.
        if let message = FlightValidation.message(missionName: editorVM.missionName,
                                                  missionType: editorVM.missionType,
                                                  missionDate: editorVM.missionDateToSave,
                                                  hackTime: editorVM.hackTimeToSave,
                                                  hasTarget: true) {
            validationMessage = message
            return
        }

        flight.target = Target(longitude: location.longitude, latitude: location.latitude)
        flight.missionName = editorVM.missionName
        flight.missionType = editorVM.missionType
        // Only the field that belongs to the mission type is kept; the other is cleared.
        flight.missionDate = editorVM.missionDateToSave
        flight.hackTime = editorVM.hackTimeToSave

        validationMessage = nil
        do {
            try modelContext.save()
            isPresentingEditFlight = false
            selectedFlight = nil
        } catch {
            dataLog.error("Failed to update flight: \(String(describing: error), privacy: .public)")
            validationMessage = String(localized: "Failed to update flight. Please try again.",
                                       comment: "Shown when persisting changes to an existing flight fails")
        }
    }

    /// The editor's Cancel action (B-21). Clearing `isPresentingEditFlight` pops the editor
    /// through the `navigationDestination(isPresented:)` binding in `FlightsListView`.
    func cancelEditor() {
        logger.debug("Editor canceled by user")
        selectedFlight = nil
        isPresentingEditFlight = false
    }
    
    // MARK: - Settings Coordination
    func presentSettings() {
        logger.debug("Present settings")
        isPresentingSettings = true
    }
    
    func dismissSettings() {
        logger.debug("Dismiss settings")
        self.settings = Settings.load(from: UserDefaults.standard)
        isPresentingSettings = false
    }
    
    // MARK: - Deletion Flow (Confirmation)
    func requestDelete(flight: Flight) {
        pendingDeleteFlight = flight
        showDeleteConfirmation = true
    }
    
    func confirmDelete(modelContext: ModelContext) {
        guard let flight = pendingDeleteFlight else {
            showDeleteConfirmation = false
            return
        }
        dataLog.info("Deleting flight (confirmed): \(flight.missionName, privacy: .private)")
        modelContext.delete(flight)
        do {
            try modelContext.save()
        } catch {
            dataLog.error("Failed to delete flight: \(String(describing: error), privacy: .public)")
            // Undo the staged deletion so the list keeps matching the store.
            modelContext.rollback()
            validationMessage = String(localized: "Failed to delete flight. Please try again.",
                                       comment: "Shown when persisting a flight deletion fails")
        }
        pendingDeleteFlight = nil
        showDeleteConfirmation = false
    }

    func cancelDelete() {
        pendingDeleteFlight = nil
        showDeleteConfirmation = false
    }
}
