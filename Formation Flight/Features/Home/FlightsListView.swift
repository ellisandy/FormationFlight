//
//  FlightsListView.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/15/23.
//

import os
import SwiftData
import SwiftUI
import FormationFlightCore

private struct FlightsListRowView: View {
    let flight: Flight
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var shareFile: FlightShareFile? {
        try? FlightShareFile(flight: flight)
    }
    
    var body: some View {
        HStack {
            Button(action: onEdit) {
                Text(flight.missionName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("flightRowButton_\(flight.id.uuidString)")
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if let shareFile {
                ShareLink(
                    item: shareFile,
                    preview: SharePreview(flight.missionName)
                ) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .tint(.blue)
                .accessibilityIdentifier("flightRowShare_\(flight.id.uuidString)")
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
            .accessibilityIdentifier("flightRowDelete_\(flight.id.uuidString)")
        }
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            if let shareFile {
                ShareLink(
                    item: shareFile,
                    preview: SharePreview(flight.missionName)
                ) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityIdentifier("flightRow_\(flight.id.uuidString)")
    }
}

private struct FlightsEmptyStateView: View {
    let onCreateFirstFlight: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "airplane")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.secondary)
            Text("No Flights Yet")
                .font(.title2)
                .bold()
            Text("Create your first flight to get started.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Button(action: onCreateFirstFlight) {
                Label(
                    "Create your first flight",
                    systemImage: "plus.circle.fill"
                )
                .font(.headline)
            }
            .buttonStyle(.glassProminent)

            .accessibilityIdentifier("emptyStateCreateFirstFlightButton")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // A plain VStack is not an accessibility element, so its identifier is
        // invisible to UI tests unless it is made a container.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("emptyStateView")
    }
}

struct FlightsListView: View {
    // Centralized loggers
    private let uiLog = AppLogger.ui
    
    @Environment(\.modelContext) private var modelContext
    // B-31: a stable order so rows do not shuffle between launches or after edits.
    @Query(sort: [SortDescriptor(\Flight.missionDate), SortDescriptor(\Flight.missionName)])
    var flights: [Flight]
    
    @StateObject private var viewModel = FlightsListViewModel()

    // R-07: the safety disclaimer is shown once, on first launch, and must be
    // acknowledged before the app can be used.
    private let safetyDisclaimerStore = SafetyDisclaimerStore()
    @State private var showsSafetyDisclaimer = false
    @State private var pendingFlightImport: FlightTransferPayload?
    @State private var pendingPreferencesImport: PreferencesTransferPayload?
    @State private var transferMessage: String?

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
            .navigationDestination(isPresented: $viewModel.isPresentingEditFlight) {
                FlightEditorView(
                    flight: viewModel.selectedFlight,
                    onSave: { editorVM in
                        if let editing = viewModel.selectedFlight {
                            viewModel.updateFlight(editing, from: editorVM, modelContext: modelContext)
                        } else {
                            viewModel.saveNewFlight(from: editorVM, modelContext: modelContext)
                        }
                    },
                    onCancel: {
                        viewModel.cancelEditor()
                    }
                )
                .navigationBarTitleDisplayMode(.inline)
            }
            .navigationTitle("Flights")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        uiLog.debug("Presenting settings")
                        viewModel.presentSettings()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityHint("Open settings")
                }
                ToolbarItem {
                    Button {
                        uiLog.debug("Presenting add flight")
                        viewModel.presentAddFlight()
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                    .accessibilityIdentifier("addFlightButton")
                    .accessibilityLabel("Add Flight")
                    .accessibilityHint("Create a new flight")
                }
            }
        }
        .sheet(isPresented: $viewModel.isPresentingSettings, onDismiss: {
            viewModel.dismissSettings()
        }, content: {
            SettingsEditorView(viewModel: SettingsEditorViewModel(settings: viewModel.settings))
                // D-07: the default iPad page size cut the form off at "Final Bearing".
                .presentationSizing(.form)
        })
        .fullScreenCover(isPresented: $showsSafetyDisclaimer) {
            SafetyDisclaimerView {
                uiLog.debug("Safety disclaimer acknowledged")
                safetyDisclaimerStore.acknowledge()
                showsSafetyDisclaimer = false
            }
            // The only way out is the acknowledgement button.
            .interactiveDismissDisabled()
        }
        .onAppear {
            uiLog.debug("FlightsListView appeared")
            viewModel.startMonitoring()
            if !safetyDisclaimerStore.hasAcknowledged {
                uiLog.debug("Presenting safety disclaimer (first launch)")
                showsSafetyDisclaimer = true
            }
        }
        .onOpenURL(perform: prepareImport)
        .alert(
            "Import Flight?",
            isPresented: Binding(
                get: { pendingFlightImport != nil },
                set: { isPresented in
                    if !isPresented {
                        Task { @MainActor in pendingFlightImport = nil }
                    }
                }
            )
        ) {
            Button("Import") {
                importPendingFlight()
            }
            Button("Cancel", role: .cancel) {
                pendingFlightImport = nil
            }
        } message: {
            Text("This adds “\(pendingFlightImport?.missionName ?? "")” as a new, independent flight. Existing flights will not change.")
        }
        .alert(
            "Replace Your Preferences?",
            isPresented: Binding(
                get: { pendingPreferencesImport != nil },
                set: { isPresented in
                    if !isPresented {
                        Task { @MainActor in pendingPreferencesImport = nil }
                    }
                }
            )
        ) {
            Button("Replace") {
                importPendingPreferences()
            }
            Button("Cancel", role: .cancel) {
                pendingPreferencesImport = nil
            }
        } message: {
            Text("This replaces your units, tolerances, callouts, and instrument layout. Flights will not be affected.")
        }
        .alert(
            "Formation Flight",
            isPresented: Binding(
                get: { transferMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        Task { @MainActor in transferMessage = nil }
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(transferMessage ?? "")
        }
        .alert(
            "Validation",
            isPresented: Binding(
                get: { viewModel.validationMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        Task { @MainActor in
                            viewModel.validationMessage = nil
                        }
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.validationMessage ?? "")
        }
        // Deletion confirmation, driven by view model state. The message reads the
        // captured name string rather than the model so the dismiss animation never
        // touches a `Flight` that has already been deleted from the context.
        .alert(
            "Delete Flight?",
            isPresented: Binding(
                get: { viewModel.showDeleteConfirmation },
                set: { isPresented in
                    if !isPresented {
                        Task { @MainActor in
                            viewModel.showDeleteConfirmation = false
                        }
                    }
                }
            )
        ) {
            Button("Delete", role: .destructive) {
                Task { @MainActor in
                    withAnimation {
                        viewModel.confirmDelete(modelContext: modelContext)
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                Task { @MainActor in
                    viewModel.cancelDelete()
                }
            }
        } message: {
            Text("Are you sure you want to delete \(viewModel.pendingDeleteFlightName ?? "")? This action cannot be undone.")
        }
        .accessibilityIdentifier("FlightsListViewRoot")
    }
    
    private func prepareImport(from url: URL) {
        do {
            switch try ImportedTransferFile.read(from: url) {
            case .flight(let payload):
                _ = try payload.makeFlight()
                pendingFlightImport = payload
            case .preferences(let payload):
                _ = try payload.importedSettings()
                pendingPreferencesImport = payload
            }
        } catch {
            transferMessage = error.localizedDescription
        }
    }

    private func importPendingFlight() {
        guard let payload = pendingFlightImport else { return }
        pendingFlightImport = nil
        do {
            let flight = try payload.makeFlight()
            modelContext.insert(flight)
            try modelContext.save()
            transferMessage = String(
                localized: "Imported “\(flight.missionName)”.",
                comment: "Success message after importing a shared flight"
            )
        } catch {
            modelContext.rollback()
            transferMessage = error.localizedDescription
        }
    }

    private func importPendingPreferences() {
        guard let payload = pendingPreferencesImport else { return }
        pendingPreferencesImport = nil
        do {
            let settings = try payload.importedSettings()
            settings.save(to: UserDefaults.standard)
            viewModel.settings = settings
            transferMessage = String(
                localized: "Preferences imported.",
                comment: "Success message after importing shared preferences"
            )
        } catch {
            transferMessage = error.localizedDescription
        }
    }

    private var listContent: some View {
        List {
            ForEach(flights, id: \.id) { flight in
                FlightsListRowView(
                    flight: flight,
                    onEdit: {
                        uiLog.debug(
                            "Editing flight: \(flight.missionName, privacy: .private)"
                        )
                        viewModel.presentEditFlight(flight)
                    },
                    onDelete: {
                        // Ask the view model to start the confirmation flow
                        viewModel.requestDelete(flight: flight)
                    }
                )
            }
        }
        .readableScrollContent()
    }
}

#Preview {
    @MainActor
    func makeInMemoryContainer() -> ModelContainer {
        let schema = Schema([Flight.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        let container = try! ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        
        // Seed data
        let context = ModelContext(container)
        let f1 = Flight(missionName: "F1", missionType: .hackTime, missionDate: .now, target: Target(longitude: 0.0, latitude: 0.0))
        let f2 = Flight(missionName: "F2", missionType: .hackTime, missionDate: .now, target: Target(longitude: 0.0, latitude: 0.0))
        context.insert(f1)
        context.insert(f2)
        // An unsaved context leaves the container empty, so the preview showed the empty state.
        try? context.save()
        
        return container
    }
    
    let container = makeInMemoryContainer()
    return FlightsListView()
        .modelContainer(container)
}

#Preview("Empty State") {
    @MainActor
    func makeEmptyInMemoryContainer() -> ModelContainer {
        let schema = Schema([Flight.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        let container = try! ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        return container
    }

    let emptyContainer = makeEmptyInMemoryContainer()
    return FlightsListView()
        .modelContainer(emptyContainer)
}
