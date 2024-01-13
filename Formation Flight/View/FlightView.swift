//
//  FlightView.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/28/23.
//

import SwiftUI
import MapKit

struct FlightView: View {
    @Bindable var flight: Flight
    @Bindable var locationProvider = LocationProvider()
    @Binding var settingsConfig: SettingsEditorConfig
    @Bindable var panelData: InstrumentPanelData
    
    lazy var updateData: () -> Void = {}

    var body: some View {
        ZStack {
            Map {
                UserAnnotation()
                if let location = locationProvider.locationManager.location {
                    MapPolyline(coordinates: flight.getCLCoordinate2D(userLocation: location.coordinate))
                    .stroke(.blue, lineWidth: 5.0)
                } else {
                    MapPolyline(coordinates: flight.getCLCoordinate2D()).stroke(.blue, lineWidth: 5.0)
                }
                ForEach(flight.checkPoints) { cp in
                    Marker(cp.name, coordinate: cp.getCLCoordinate())
                }
            }
            .mapStyle(.imagery(elevation: .realistic))
            .mapControls {
                MapScaleView()
                MapUserLocationButton()
            }
            
            InstrumentPanel(settingsConfig: $settingsConfig,
                            panelData: panelData)
        }
        .onAppear {
            locationProvider.updateDelegate = calculateTheStuff
            locationProvider.startMonitoring()
        }
        .onDisappear {
            locationProvider.stopMonitoring()
        }
    }
    
    // TODO: Clean this up?
    // The general idea... I think will be to pull the new data, then have some type of copy functino to move the core logic out
    // of the view file. 
    func calculateTheStuff() -> Void {
        print("Update fo shizzle")
        let temp = flight.provideInstrumentPanelData(from: locationProvider.locationManager.location!)
        
        panelData.currentETA = temp.currentETA
        panelData.ETADelta = temp.ETADelta
        panelData.course = temp.course
        panelData.currentTrueAirspeed = temp.currentTrueAirspeed
        panelData.targetTrueAirspeed = temp.targetTrueAirspeed
        panelData.distanceToNext = temp.targetTrueAirspeed
    }
}

#Preview {
    let flightPreview = Flight.emptyFlight()
    flightPreview.title = "Test Flight"
    
    return FlightView(flight: flightPreview, settingsConfig: .constant(.emptyConfig()), panelData: InstrumentPanelData.init(currentETA: 0, ETADelta: 0, course: 0, currentTrueAirSpeed: 0, targetTrueAirSpeed: 0, distanceToNext: 0, distanceToFinal: 0))
}
