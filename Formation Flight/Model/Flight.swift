//
//  Flight.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/17/23.
//

import Foundation
import SwiftData
import MapKit

/// Individual Planned Flight
@Model
final class Flight: Identifiable, Hashable {
    @Attribute(.unique) var id: UUID = UUID()
    var title: String = ""
    var missionDate: Date = Date.now
    var expectedWinds: Winds = Winds(velocity: 0, direction: 0)
    var checkPoints: [CheckPoint] = []
    var inflightCheckPoints: [CheckPoint] = []
    

    
    /// Initialize a Flight
    /// - Parameters:
    ///   - title: Title of the flight
    ///   - missionDate: Date of the mission
    ///   - expectedWinds: Expected Winds for calciulation
    ///   - checkPoints: A list of checkpoints.
    init(title: String, missionDate: Date, expectedWinds: Winds, checkPoints: [CheckPoint]) {
        self.title = title
        self.missionDate = missionDate
        self.expectedWinds = expectedWinds
        self.checkPoints = checkPoints
    }

}

extension Flight {
    static func == (lhs: Flight, rhs: Flight) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Flight {
    func mapPoints(currentLocation: CLLocationCoordinate2D?) -> [MKMapPoint] {
        var locations = inflightCheckPoints.map {
            MKMapPoint($0.getCLCoordinate())
        }
        if currentLocation != nil {
            locations.insert(MKMapPoint(currentLocation!), at: 0)
        }
        
        return locations
    }
    
    static func emptyFlight() -> Flight {
        return Flight(title: "", missionDate: Date.now, expectedWinds: Winds(velocity: 0, direction: 0), checkPoints: [])
    }
    
    func validFlight() -> Bool {
        var validStatus = true
        
        if checkPoints.isEmpty {
            validStatus = false
        }
        
        return validStatus
    }
    
    func getCLCoordinate2D() -> [CLLocationCoordinate2D] {
        return self.inflightCheckPoints.map { checkpoint in
            CLLocationCoordinate2D(latitude: checkpoint.latitude, longitude: checkpoint.longitude)
        }
    }
    
    func getCLLocations() -> [CLLocation] {
        return self.inflightCheckPoints.map { cp in
            CLLocation(latitude: cp.latitude, longitude: cp.longitude)
        }
    }
    
    func getCLCoordinate2D(userLocation startPoint: CLLocationCoordinate2D?) -> [CLLocationCoordinate2D] {
        guard let startPointSafe = startPoint else { return getCLCoordinate2D() }
        
        var locations = getCLCoordinate2D()
        
        //SAFE
        locations.insert(startPointSafe, at: 0)
        
        return locations
    }
    
    // FIXME: Add functionality to compute all CheckPoints
    // TODO: Move out of Flight
    // Given this method only uses the checkpoints (I think), then it's not really needed to be on the flight itself. Consider moving
    // to CLLocation or Checkpoints directly.
    func provideInstrumentPanelData(from currentLocation: CLLocation) -> InstrumentPanelData {
        let tot = Date.now.secondsUntil(time: missionDate).secondsMeasurement
        let distanceFinal: Measurement<UnitLength>? = currentLocation.distance(from: getCLLocations())?.metersMeasurement
        let distanceNext: Measurement<UnitLength>? = getCLLocations().first?.distance(from: currentLocation)
        
        var etaDelta: Double? = nil
        if let actualTOT = currentLocation.getTime(to: getCLLocations(), with: expectedWinds) {
            etaDelta = actualTOT.converted(to: .seconds).value - tot.converted(to: .seconds).value
        }
        
        let targetAirspeed: Measurement<UnitSpeed>? = currentLocation.getTargetAirspeed(tot: tot, destinations: getCLLocations(), winds: expectedWinds)
                
        let currentTrueAirSpeed = currentLocation.getTrueAirSpeed(with: expectedWinds)
        let bearingNext = currentLocation.getBearing(to: getCLLocations().first!)
        let bearingFinal = currentLocation.getBearing(to: getCLLocations().last!)
        let groundSpeed: Measurement<UnitSpeed>? = Measurement.init(value: currentLocation.speed, unit: .metersPerSecond)

        // TODO: Add Track
        
        return InstrumentPanelData(currentETA: tot.erasedType,
                                   ETADelta: etaDelta?.secondsMeasurement.erasedType,
                                   bearingNext: bearingNext?.erasedType,
                                   currentTrueAirSpeed: currentTrueAirSpeed?.erasedType,
                                   targetTrueAirSpeed: targetAirspeed?.erasedType,
                                   distanceToNext: distanceNext?.erasedType,
                                   distanceToFinal: distanceFinal?.erasedType,
                                   groundSpeed: groundSpeed?.erasedType,
                                   bearingFinal: bearingFinal?.erasedType)
    }
}

