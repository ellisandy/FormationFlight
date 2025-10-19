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
        var locations = checkPoints.map {
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
        return self.checkPoints.map { checkpoint in
            CLLocationCoordinate2D(latitude: checkpoint.latitude, longitude: checkpoint.longitude)
        }
    }
    
    func getCLLocation() -> [CLLocation] {
        return self.checkPoints.map { cp in
            CLLocation(latitude: cp.latitude, longitude: cp.longitude)
        }
    }
    
    func getCLCoordinate2D(userLocation startPoint: CLLocationCoordinate2D?) -> [CLLocationCoordinate2D] {
        if startPoint == nil { return getCLCoordinate2D() }
        
        var locations = getCLCoordinate2D()
        //SAFE
        locations.insert(startPoint!, at: 0)
        
        return locations
    }
    
    // FIXME: Add functionality to compute all CheckPoints
    // TODO: Move out of Flight
    // Given this method only uses the checkpoints (I think), then it's not really needed to be on the flight itself. Consider moving
    // to CLLocation or Checkpoints directly.
    func provideInstrumentPanelData(from currentLocation: CLLocation) -> InstrumentPanelData {
        let tot = Date.now.secondsUntil(time: missionDate).secondsMeasurement
        let distanceFinal = currentLocation.distance(from: getCLLocation())
        let distanceNext: Measurement<UnitLength>? = getCLLocation().first?.distance(from: currentLocation)
        
        var etaDelta: Double? = nil
        if let actualTOT = currentLocation.getTime(to: getCLLocation(), with: expectedWinds) {
            etaDelta = actualTOT.converted(to: .seconds).value - tot.converted(to: .seconds).value
        }
        
        let targetAirspeed: Measurement<UnitSpeed>? = currentLocation.getTargetAirspeed(tot: tot, destinations: getCLLocation(), winds: expectedWinds)
                
        let currentTrueAirSpeed = currentLocation.getTrueAirSpeed(with: expectedWinds)
        let course = currentLocation.getCourse(to: getCLLocation().first!)
        
        let heading = currentLocation.getHeading(airspeed: currentTrueAirSpeed, winds: expectedWinds, course: course)
        
        return InstrumentPanelData(currentETA: tot.erasedType,
                                   ETADelta: etaDelta?.secondsMeasurement.erasedType,
                                   course: heading?.erasedType,
                                   currentTrueAirSpeed: currentTrueAirSpeed?.erasedType,
                                   targetTrueAirSpeed: targetAirspeed?.erasedType,
                                   distanceToNext: distanceNext?.erasedType,
                                   distanceToFinal: distanceFinal?.metersMeasurement.erasedType)
    }
}

