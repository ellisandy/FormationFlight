//
//  ContentView.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/15/23.
//

import SwiftUI
import SwiftData
import MapKit
import os

struct ContentView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FormationFlight", category: "ContentView")
    
    @Environment(\.modelContext) private var modelContext
    @Query var flights: [Flight]
    
    @State private var selectedFlight: Flight?
    @State private var flightEditorConfig = FlightEditorConfig()
    @State private var settingsConfig = SettingsEditorConfig.from(userDefaults: UserDefaults.standard)
    @State private var isFlightViewPresented: Bool = false
    @State private var currentLocation: CLLocationCoordinate2D?
    
    var body: some View {
        NavigationStack {
            List(selection: $selectedFlight) {
                ForEach(flights, id: \.id) { flight in
                    withAnimation {
                        HStack {
                            Button {
                                selectedFlight = flight
                                isFlightViewPresented = true
                            } label: {
                                Text(flight.title)
                                    .font(.title)
                                    .foregroundStyle(.primary)
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
                .onDelete(perform: { indexSet in
                    withAnimation {
                        for index in indexSet {
                            let flight = flights[index]
                            modelContext.delete(flight)
                        }
                    }
                })
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
                    .accessibilityIdentifier("addFlightButton")
                }
            }
            .navigationTitle("Flights")
            .fullScreenCover(isPresented: $isFlightViewPresented) {
                if let flight = selectedFlight {
                    ZStack {
                        flightContentView(for: flight)
                        SlidingSheetView() {
                                instrumentPanelView()
                        }.ignoresSafeArea(edges: .all)
                    }
                } else {
                    // Safety: dismiss if no selection
                    Color.clear.onAppear { isFlightViewPresented = false }
                }
            }
            .onDisappear() {
                selectedFlight = nil
            }
        }
        .accessibilityIdentifier("ContentViewRoot")
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
    
    @ViewBuilder
    private func flightContentView(for flight: Flight) -> some View {
        FlightView(
            flight: flight,
            settingsConfig: $settingsConfig,
            isFlightViewPresented: $isFlightViewPresented
        )
    }

    @ViewBuilder
    private func instrumentPanelView() -> some View {
        InstrumentPanel(
            settingsConfig: $settingsConfig,
            isFlightViewPresented: $isFlightViewPresented,
            flight: $selectedFlight
        )
    }
}
