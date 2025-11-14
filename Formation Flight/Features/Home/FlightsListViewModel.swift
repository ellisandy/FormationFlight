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
    let locationProvider: LocationProvider = LocationProvider()

    // Editor / settings coordination
    @Published var flightEditorConfig: FlightEditorConfig = FlightEditorConfig()
    @Published var settingsConfig: SettingsEditorConfig = SettingsEditorConfig.from(userDefaults: UserDefaults.standard)

    // Validation feedback
    @Published var validationMessage: String?

    // Deletion coordination
    @Published var pendingDeleteFlight: Flight?
    @Published var showDeleteConfirmation: Bool = false

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
        flightEditorConfig.presentAddFlight()
    }

    func presentEditFlight(_ flight: Flight) {
        logger.debug("Present edit flight: \(flight.title, privacy: .public)")
        flightEditorConfig.presentEditFlight(flight)
    }

    func didDismissEditor(modelContext: ModelContext) {
        guard flightEditorConfig.shouldSaveChanges else {
            logger.debug("Editor dismissed without save")
            return
        }

        let title = flightEditorConfig.flight.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty {
            logger.error("Validation failed: empty title")
            validationMessage = "Please enter a flight title."
            flightEditorConfig.presentEditFlight(flightEditorConfig.flight)
            return
        }

        dataLog.info("Inserting/updating flight: \(title, privacy: .public)")
        modelContext.insert(flightEditorConfig.flight)
    }

    // MARK: - Settings Coordination
    func presentSettings() {
        logger.debug("Present settings")
        settingsConfig.present()
    }

    // MARK: - Data Operations
    func delete(_ flight: Flight, modelContext: ModelContext) {
        dataLog.info("Deleting flight: \(flight.title, privacy: .public)")
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
        dataLog.info("Deleting flight (confirmed): \(flight.title, privacy: .public)")
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

