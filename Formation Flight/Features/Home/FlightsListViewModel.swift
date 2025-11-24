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
    
    // TODO: Consider abstracting LocationProvider behind a protocol for testability.
    let locationProvider: LocationProviding
    
    // Validation feedback
    @Published var validationMessage: String?
    
    // UI presentation flags
    @Published var isPresentingSettings: Bool = false
    @Published var isPresentingEditFlight: Bool = false
    @Published var selectedFlight: Flight?
    
    @Published var settings: Settings = Settings.load(from: UserDefaults.standard)
    
    // Deletion coordination
    @Published var pendingDeleteFlight: Flight?
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
        logger.debug("Present edit flight: \(flight.missionName, privacy: .public)")
        selectedFlight = flight
        isPresentingEditFlight = true
    }
    
    // MARK: - Editor Actions (Closures from Child)
    func saveNewFlight(from editorVM: FlightEditorViewModel, modelContext: ModelContext) {
        guard !editorVM.missionName.isEmpty else {
            validationMessage = "Please enter a mission name."
            return
        }
        
        guard let location = editorVM.selectedTargetLocation else {
            validationMessage = "Please enter a valid target location."
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
            validationMessage = "Failed to save flight. Please try again."
        }
    }
    
    func updateFlight(_ flight: Flight, from editorVM: FlightEditorViewModel, modelContext: ModelContext) {
        dataLog.info("Updating existing flight: \(flight.missionName, privacy: .public)")
        guard !editorVM.missionName.isEmpty else {
            validationMessage = "Please enter a mission name."
            return
        }
        
        guard let location = editorVM.selectedTargetLocation else {
            validationMessage = "Please enter a valid target location."
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
            validationMessage = "Failed to update flight. Please try again."
            
        }
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
    
    // MARK: - Data Operations
    func delete(_ flight: Flight, modelContext: ModelContext) {
        dataLog.info("Deleting flight: \(flight.missionName, privacy: .public)")
        modelContext.delete(flight)
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
        dataLog.info("Deleting flight (confirmed): \(flight.missionName, privacy: .public)")
        modelContext.delete(flight)
        pendingDeleteFlight = nil
        showDeleteConfirmation = false
    }
    
    func cancelDelete() {
        pendingDeleteFlight = nil
        showDeleteConfirmation = false
    }
    
    func handleOnDelete(indexSet: IndexSet, flights: [Flight], modelContext: ModelContext) {
        let items = indexSet.map { flights[$0] }
        guard !items.isEmpty else { return }
        
        if items.count == 1, let first = items.first {
            // Single item: go through confirmation flow
            requestDelete(flight: first)
        } else {
            // Multiple selection: delete directly (or implement multi-confirmation if desired)
            dataLog.info("Deleting \(items.count, privacy: .public) flights via onDelete")
            items.forEach { modelContext.delete($0) }
        }
    }
}
