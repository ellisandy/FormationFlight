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
    
    var body: some View {
        NavigationSplitView {
            List(flights, id: \.self, selection: $selectedFlight) { flight in
                withAnimation {
                    HStack {
                        NavigationLink(value: flight) {
                            Text(flight.title)
                        }
                        Spacer()
                        if flight.validFlight() {
                            Image(systemName: "checkmark.seal.fill").tint(.green)
                        } else {
                            Image(systemName: "exclamationmark.triangle.fill").tint(.red)
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
            .toolbar {
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
            .navigationTitle("Big Boy Flights")
        } detail: {
            if selectedFlight != nil {
                FlightView(flight: selectedFlight!)
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
                // TODO: Need to fix the update logic for Swift Data Here...
                assertionFailure("Shouldn't get here...")
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Flight.self, inMemory: true)
}
