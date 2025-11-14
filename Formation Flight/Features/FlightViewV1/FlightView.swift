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
    var locationProvider = LocationProvider()
    @Binding var settingsConfig: SettingsEditorConfig
    @Binding var isFlightViewPresented: Bool
    @State private var currentLocation: CLLocationCoordinate2D?
    
    private let uiUpdateTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Map {
                UserAnnotation()
                MapPolyline(points: flight.mapPoints(currentLocation: currentLocation), contourStyle: .geodesic)
                    .stroke(.blue.opacity(0.5), lineWidth: 4.0)
                    

                ForEach(flight.inflightCheckPoints) { cp in
                    Marker(cp.name, coordinate: cp.getCLCoordinate())
                    MapCircle(center: cp.getCLCoordinate(),
                              radius: settingsConfig.getProximityToNextPointInMeters())
                        .foregroundStyle(.clear)
                        .stroke(.primary.opacity(0.6), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 6]))
                }
            }
            .mapStyle(.imagery(elevation: .realistic))
            .mapControls {
                VStack {
                    MapScaleView()
                    MapCompass()
                    MapUserLocationButton()
                }
            }
        }
        .onAppear {
            locationProvider.startMonitoring()
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            locationProvider.stopMonitoring()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onReceive(uiUpdateTimer) { _ in
            guard let location = locationProvider.locationManager.location else { return }
            currentLocation = location.coordinate
        }
    }

}

#Preview {
    let flightPreview = Flight.emptyFlight()
    let HOME_LOCATION = CheckPoint(id: UUID(), name: "Home", longitude: -122.379581, latitude: 48.425643)
    let TREE_FARM_LOCATION = CheckPoint(id: UUID(), name: "Tree Farm", longitude: -122.36519, latitude: 48.42076)
    let BVS_LOCATION = CheckPoint(id: UUID(), name: "BVS Airport", longitude: -122.41299, latitude: 48.46915)
    
    flightPreview.title = "Test Flight"
    flightPreview.checkPoints = [HOME_LOCATION, TREE_FARM_LOCATION, BVS_LOCATION]
    
    var config = SettingsEditorConfig.emptyConfig()
    config.speedUnit = .kts
    config.distanceUnit = .nm
    
    return FlightView(flight: flightPreview, 
                      settingsConfig: .constant(config),
                      isFlightViewPresented: .constant(true))
}
