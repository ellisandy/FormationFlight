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
    
    init(flight: Flight) {
        self.flight = flight
    }
    
    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 0) {
                    Map {
                        UserAnnotation()
                        
                        MapPolyline(coordinates: flight.getCLCoordinate2D()).stroke(.blue, lineWidth: 5.0)
                        ForEach(flight.checkPoints) { cp in
                            Marker(cp.name, coordinate: cp.getCLCoordinate())
                        }
                    }
                    .mapControls {
                        MapScaleView()
                        MapUserLocationButton()
                    }
                    Text("Current Altitude: \(locationProvider.altitudeInFeet)")
                    Text("Current Heading: \(locationProvider.course)")
                    Text("Current Velocity: \(locationProvider.speedInKnots)")
                    // Content of your view
                }
                .navigationBarTitle(flight.title)
                .onAppear {
                    locationProvider.startMonitoring()
                }
                .onDisappear {
                    locationProvider.stopMonitoring()
                }
            }
        }
    }
}

#Preview {
    let flightPreview = Flight.emptyFlight()
    flightPreview.title = "Test Flight"
    
    return FlightView(flight: flightPreview)
}
