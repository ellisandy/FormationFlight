//
//  FlightEditorCheckPoint.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/28/23.
//

import SwiftUI

struct FlightEditorCheckPoint: View {
    @State private var checkPointInput = false
    @State private var checkPointName = ""
    @State private var longitude = ""
    @State private var latitude = ""
    @Bindable var flight: Flight
    
    var body: some View {
        Button("New Check Point") {
            checkPointInput.toggle()
        }
        .alert("Check Point", isPresented: $checkPointInput) {
            TextField("Checkpoint Name", text: $checkPointName)

            TextField("Longitude", text: $longitude)
            TextField("Latitude", text: $latitude)
            Button("Add", action: {
                let doubleLong = Double(longitude) ?? 0.0
                let doubleLat = Double(latitude) ?? 0.0
                
                flight.checkPoints.append(CheckPoint(id: UUID(), name: checkPointName, longitude: doubleLong, latitude: doubleLat))
                checkPointInput = false
            })
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enter the Longitude and Latitude")
        }
    }
}

#Preview {
    FlightEditorCheckPoint(flight: Flight.emptyFlight())
}
