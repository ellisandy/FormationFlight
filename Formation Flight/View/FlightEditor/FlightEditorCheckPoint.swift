//
//  FlightEditorCheckPoint.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/28/23.
//

import SwiftUI
import MapKit
import CoreLocation

struct FlightEditorCheckPoint: View {
    @State private var isPresentingMapPicker = false
    @Bindable var flight: Flight

    var body: some View {
        Button("New Check Point") {
            isPresentingMapPicker = true
        }
        .sheet(isPresented: $isPresentingMapPicker) {
            MapPickerView { name, coordinate in
                let doubleLong = coordinate.longitude
                let doubleLat = coordinate.latitude
                flight.checkPoints.append(
                    CheckPoint(id: UUID(), name: name, longitude: doubleLong, latitude: doubleLat)
                )
                isPresentingMapPicker = false
            } onCancel: {
                isPresentingMapPicker = false
            }
        }
    }
}

// Simple map picker with a draggable pin and text field for name
private struct MapPickerView: View {
    var onSave: (_ name: String, _ coordinate: CLLocationCoordinate2D) -> Void
    var onCancel: () -> Void

    @State private var name: String = ""
    @State private var pinCoordinate: CLLocationCoordinate2D

    init(
        onSave: @escaping (_ name: String, _ coordinate: CLLocationCoordinate2D) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onSave = onSave
        self.onCancel = onCancel
        let currentLocation = LocationProvider().location
        _pinCoordinate = State(initialValue: currentLocation)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Map with a centered overlay pin that stays fixed while the map moves
                ZStack {
                    Map(initialPosition: .region(MKCoordinateRegion(center: LocationProvider().location,
                                                                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))) {
                        Annotation("", coordinate: pinCoordinate, anchor: .bottom) {
                            Image(systemName: "mappin")
                                .font(.system(size: 42))
                                .foregroundStyle(.red)
                                .shadow(radius: 10)
                        }
                    }
                    .mapStyle(.hybrid)
                    .ignoresSafeArea(edges: .bottom)
                    .onMapCameraChange(frequency: .continuous) { context in
                        pinCoordinate = context.region.center
                    }
                }
                .frame(minHeight: 300)

                VStack(alignment: .leading, spacing: 8) {
                    TextField("Checkpoint Name", text: $name)
                        .textFieldStyle(.roundedBorder)

                    // Show live-updating lat/long
                    HStack {
                        Text("Latitude: \(pinCoordinate.latitude,format: .number.precision(.fractionLength(6)))")
                        Spacer()
                        Text("Longitude: \(pinCoordinate.longitude, format: .number.precision(.fractionLength(6)))")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .padding([.horizontal, .bottom])
            }
            .navigationTitle("Pick Checkpoint")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name, pinCoordinate)
                    }
                    .disabled(name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    FlightEditorCheckPoint(flight: Flight.emptyFlight())
}
