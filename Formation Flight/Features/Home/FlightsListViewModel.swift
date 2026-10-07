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
        guard !editorVM.missionName.isEmpty else {
            validationMessage = Self.missingNameMessage
            return
        }

        guard let location = editorVM.selectedTargetLocation else {
            validationMessage = Self.missingTargetMessage
            return
        }
        
        validationMessage = nil
        let missionType: MissionType = editorVM.useTOT ? .tot : .hackTime
        let missionDate: Date? = editorVM.timeEntry
        let hackDuration: Double? = Double(editorVM.hackDurationSeconds)
        let flight = Flight(missionName: editorVM.missionName,
                            missionType: missionType,
                            missionDate: missionDate,
                            target: Target(longitude: location.longitude, latitude: location.latitude),
                            hackTime: hackDuration)
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
        guard !editorVM.missionName.isEmpty else {
            validationMessage = Self.missingNameMessage
            return
        }

        guard let location = editorVM.selectedTargetLocation else {
            validationMessage = Self.missingTargetMessage
            return
        }
        
        flight.target = Target(longitude: location.longitude, latitude: location.latitude)
        flight.missionName = editorVM.missionName
        flight.missionType = editorVM.useTOT ? .tot : .hackTime
        flight.missionDate = editorVM.timeEntry
        flight.hackTime = Double(editorVM.hackDurationSeconds)
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

    // MARK: - Validation Messages
    private static var missingNameMessage: String {
        String(localized: "Please enter a mission name.",
               comment: "Validation message when a flight has no mission name")
    }

    private static var missingTargetMessage: String {
        String(localized: "Please enter a valid target location.",
               comment: "Validation message when a flight has no target selected")
    }
    
    func cancelEditor() {
        logger.debug("Editor canceled by user")
        // Reset any selection and close the editor
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
