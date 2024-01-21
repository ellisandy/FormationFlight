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
    @State private var isFlightViewPresented: Bool = false
    
    var body: some View {
        NavigationSplitView {
            List(flights, id: \.self, selection: $selectedFlight) { flight in
                withAnimation {
                    HStack {
                        Button(flight.title) {
                            isFlightViewPresented.toggle()
                        }
                        .fullScreenCover(isPresented: $isFlightViewPresented) {
                            FlightView(flight: flight,
                                       settingsConfig: $settingsConfig,
                                       panelData: InstrumentPanelData.emptyPanel(),
                                       isFlightViewPresented: $isFlightViewPresented)
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
            .sheet(isPresented: $settingsConfig.isPresented, content: {
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
                           panelData: InstrumentPanelData.init(currentETA: Measurement(value: 0.0, unit: UnitDuration.seconds),
                                                               ETADelta: Measurement(value: 0.0, unit: UnitDuration.seconds),
                                                               course: Measurement(value: 0.0, unit: UnitAngle.degrees),
                                                               currentTrueAirSpeed: Measurement(value: 0.0, unit: UnitSpeed.metersPerSecond),
                                                               targetTrueAirSpeed: Measurement(value: 0.0, unit: UnitSpeed.metersPerSecond),
                                                               distanceToNext: Measurement(value: 0.0, unit: UnitLength.meters),
                                                               distanceToFinal: Measurement(value: 0.0, unit: UnitLength.meters)),
                isFlightViewPresented: $isFlightViewPresented)
            } else {
                Text("No Flight Selected").fontWeight(.bold)
            }
        }
    }
    
    private func didDismissEditor() {
        if flightEditorConfig.shouldSaveChanges {
            if flightEditorConfig.flight.title != "" {
                modelContext.insert(flightEditorConfig.flight)
            } else {
                // TODO: Add Error Messages when the flight is invalid
                flightEditorConfig.presentEditFlight(flightEditorConfig.flight)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Flight.self, inMemory: true)
}
