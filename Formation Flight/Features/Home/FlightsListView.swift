//
//  FlightsListView.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/15/23.
//

import SwiftUI
import SwiftData

private struct FlightsListRowView: View {
    let flight: Flight
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Button(action: onEdit) {
                Text(flight.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("flightRowButton_\(flight.id.uuidString)")
        }
        .contentShape(Rectangle())
        .swipeActions {
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .accessibilityIdentifier("flightRowDelete_\(flight.id.uuidString)")
        }
        .accessibilityIdentifier("flightRow_\(flight.id.uuidString)")
    }
}

private struct FlightsEmptyStateView: View {
    let onCreateFirstFlight: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "airplane")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Flights Yet")
                .font(.title2)
                .bold()
            Text("Create your first flight to get started.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Button(action: onCreateFirstFlight) {
                Label("Create your first flight", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("emptyStateCreateFirstFlightButton")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("emptyStateView")
    }
}

struct FlightsListView: View {
    // Centralized loggers
    private let uiLog = AppLogger.ui
    
    @Environment(\.modelContext) private var modelContext
    @Query var flights: [Flight]

    @StateObject private var viewModel = FlightsListViewModel()
    
    var body: some View {
        NavigationStack {
            Group {
                if flights.isEmpty {
                    FlightsEmptyStateView {
                        uiLog.debug("Empty state: present add flight")
                        viewModel.presentAddFlight()
                    }
                } else {
                    listContent
                }
            }
            .navigationTitle("Flights")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        uiLog.debug("Presenting settings")
                        viewModel.presentSettings()
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityHint("Open settings")
                }
                ToolbarItem {
                    Button {
                        withAnimation {
                            uiLog.debug("Presenting add flight")
                            viewModel.presentAddFlight()
                        }
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                    .accessibilityIdentifier("addFlightButton")
                    .accessibilityLabel("Add Flight")
                    .accessibilityHint("Create a new flight")
                }
            }
        }
        .sheet(isPresented: $viewModel.flightEditorConfig.isPresented,
               onDismiss: { viewModel.didDismissEditor(modelContext: modelContext) }) {
            FlightEditor(config: $viewModel.flightEditorConfig)
        }
        .sheet(isPresented: $viewModel.settingsConfig.isPresented) {
            SettingsEditor(settingsEditorConfig: $viewModel.settingsConfig)
        }
        .onAppear {
            uiLog.debug("FlightsListView appeared")
            viewModel.startMonitoring()
        }
        .alert("Validation", isPresented: .constant(viewModel.validationMessage != nil)) {
            Button("OK") { viewModel.validationMessage = nil }
        } message: {
            Text(viewModel.validationMessage ?? "")
        }
        // Deletion confirmation, driven by view model state
        .alert("Delete Flight?", isPresented: $viewModel.showDeleteConfirmation, presenting: viewModel.pendingDeleteFlight) { _ in
            Button("Delete", role: .destructive) {
                withAnimation {
                    viewModel.confirmDelete(modelContext: modelContext)
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelDelete()
            }
        } message: { flight in
            Text("Are you sure you want to delete “\(flight.title)”? This action cannot be undone.")
        }
        .accessibilityIdentifier("FlightsListViewRoot")
        .animation(.default, value: flights)
    }

    private var listContent: some View {
        List {
            ForEach(flights, id: \.id) { flight in
                FlightsListRowView(
                    flight: flight,
                    onEdit: {
                        uiLog.debug("Editing flight: \(flight.title, privacy: .public)")
                        viewModel.presentEditFlight(flight)
                    },
                    onDelete: {
                        // Ask the view model to start the confirmation flow
                        viewModel.requestDelete(flight: flight)
                    }
                )
            }
            .onDelete { indexSet in
                viewModel.handleOnDelete(indexSet: indexSet, flights: flights, modelContext: modelContext)
            }
        }
    }
}

#Preview {
    // In-memory SwiftData container with sample flights for preview
    do {
        let schema = Schema([Flight.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])

        // Seed data
        let context = ModelContext(container)
        let f1 = Flight(title: "Training Run", missionDate: .now, expectedWinds: Winds(velocity: 0, direction: 0), checkPoints: [])
        let f2 = Flight(title: "Formation Practice", missionDate: .now, expectedWinds: Winds(velocity: 0, direction: 0), checkPoints: [])
        context.insert(f1)
        context.insert(f2)

        return FlightsListView()
            .modelContainer(container)
    } catch {
        return Text("Preview failed: \(error.localizedDescription)")
    }
}
