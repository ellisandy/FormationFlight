//
//  ContentView.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/15/23.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query var flights: [Flight]
    
    @State private var selectedFlight: Flight?
    @State private var flightEditorConfig = FlightEditorConfig()
    @State private var settingsConfig = SettingsEditorConfig.from(userDefaults: UserDefaults.standard)
    
    var body: some View {
        NavigationSplitView {
            List(flights, id: \.self, selection: $selectedFlight) { flight in
                withAnimation {
                    HStack {
                        NavigationLink(value: flight) {
                            if flight.validFlight() {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                            }
                            Text(flight.title).font(.headline)
                        }
                    }
                }
                .swipeActions() {
                    Button(role: .destructive) {
                        withAnimation {
                            modelContext.delete(flight)
                        }
                    } label: {
                        Image(systemName: "trash")
                    }
                    Button {
                        flightEditorConfig.presentEditFlight(flight)
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .tint(.orange)
                }
            }
            .sheet(isPresented: $flightEditorConfig.isPresented, onDismiss: didDismissEditor, content: {
                FlightEditor(config: $flightEditorConfig)
            })
            .sheet(isPresented: $settingsConfig.isPresented, onDismiss: didDismissSettingsEditor, content: {
                SettingsEditor(settingsEditorConfig: $settingsConfig)
            })
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        settingsConfig.present()
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }

                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button {
                        withAnimation {
                            flightEditorConfig.presentAddFlight()
                        }
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Flights")
        } detail: {
            if selectedFlight != nil {
                FlightView(flight: selectedFlight!,
                           settingsConfig: $settingsConfig,
                           panelData: InstrumentPanelData.init(currentETA: 0, ETADelta: 0, course: 0, currentTrueAirSpeed: 0, targetTrueAirSpeed: 0, distanceToNext: 0, distanceToFinal: 0))
            } else {
                Text("No Flight Selected").fontWeight(.bold)
            }
        }
    }

    private func didDismissSettingsEditor() {
        
    }
    private func didDismissEditor() {
        if flightEditorConfig.shouldSaveChanges {
            if flightEditorConfig.flight.title != "" {
                modelContext.insert(flightEditorConfig.flight)
            } else {
                // TODO: Update the shouldSaveChanges to be protected if the title is not valid.
                assertionFailure("Shouldn't get here...")
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Flight.self, inMemory: true)
}
