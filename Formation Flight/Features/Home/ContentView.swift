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
    
    @State private var flightEditorConfig = FlightEditorConfig()
    @State private var settingsConfig = SettingsEditorConfig.from(userDefaults: UserDefaults.standard)
    @State private var isFlightViewPresented: Bool = false
    var locationProvider = LocationProvider()
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(flights, id: \.id) { flight in
                    withAnimation {
                        HStack {
                            Button {
                                flightEditorConfig.presentEditFlight(flight)
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
            }).onAppear() {
                locationProvider.startMonitoring()
            }
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
}
