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
final class Flight {
    var title: String = ""
    var missionDate: Date = Date.now
    var targetAltitude: Double = 0
    var targetSpeed: Double = 0.0
    var expectedWinds: Winds = Winds(velocity: 0, direction: 0)
    var checkPoints: [CheckPoint] = []
    var interceptTime: Date = Date.now
    

    
    /// Initialize a Flight
    /// - Parameters:
    ///   - title: Title of the flight
    ///   - missionDate: Date of the mission
    ///   - targetAltitude: Target Altitude
    ///   - targetSpeed: Target Ground Speed in Knots
    ///   - expectedWinds: Expected Winds for calciulation
    ///   - checkPoints: A list of checkpoints.
    ///   - interceptTime: DateTime of the intercept (To be deleted)
    init(title: String, missionDate: Date, targetAltitude: Double, targetSpeed: Double, expectedWinds: Winds, checkPoints: [CheckPoint], interceptTime: Date) {
        self.title = title
        self.missionDate = missionDate
        self.targetAltitude = targetAltitude // TODO: Remove
        self.targetSpeed = targetSpeed // TODO: Reconsider if this is needed
        self.expectedWinds = expectedWinds
        self.checkPoints = checkPoints
        self.interceptTime = interceptTime // TODO: Remove
    }

}

extension Flight {
    static func emptyFlight() -> Flight {
        return Flight(title: "", missionDate: Date.now, targetAltitude: 500, targetSpeed: 100.0, expectedWinds: Winds(velocity: 0, direction: 0), checkPoints: [], interceptTime: Date.now)
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
    func provideInstrumentPanelData(from currentLocation: CLLocation) -> InstrumentPanelData {
        let actualTOT = currentLocation.getTime(to: getCLLocation(), with: expectedWinds)?.converted(to: .seconds).value // Getting Actual ToT
        let tot = Date.now.secondsUntil(time: missionDate)
        let etaDelta = actualTOT! - tot // FIXME: This should handle Optionals
        
        let distance = currentLocation.distance(from: getCLLocation())
                
        let currentTrueAirSpeed = currentLocation.getTrueAirSpeed(with: expectedWinds)
        let course = currentLocation.getCourse(to: getCLLocation().first!)
        let heading = currentLocation.getHeading(airspeed: currentTrueAirSpeed!, winds: expectedWinds, course: course)
        
        let targetAirspeed = calculateTargetSpeed(actualETA: actualTOT!, targetETA: tot, distance: distance)
        
        return InstrumentPanelData(currentETA: Measurement(value: tot, unit: UnitDuration.seconds),
                                   ETADelta: Measurement(value: etaDelta, unit: UnitDuration.seconds),
                                   course: Measurement(value: heading.value, unit: heading.unit),
                                   currentTrueAirSpeed: Measurement(value: currentTrueAirSpeed!.value, unit: currentTrueAirSpeed!.unit),
                                   targetTrueAirSpeed: Measurement(value: (targetAirspeed), unit: UnitSpeed.metersPerSecond),
                                   distanceToNext: Measurement(value: distance, unit: UnitLength.meters),
                                   // FIXME: This should be the total distance.
                                   distanceToFinal: Measurement(value: distance, unit: UnitLength.meters))
    }

    // FIXME: This is still wrong... this isn't accounting for winds. It's also starting with a bunch of
    //       assumptions, and moving forward.
    func calculateTargetSpeed(actualETA: TimeInterval, targetETA: TimeInterval, distance: Double) -> Double {
        // We know the distance.
        
        // I need to know the new TAS.
        
        // I can calculate distance over the time to get the target ground speed.
        
        // Need to take the wind compoenent at the baring, get the wind component, then re-calculate the TAS.
        
        // Calculate the required speed to cover the remaining distance in the remaining time
        // Example:
        let requiredSpeed = distance / targetETA

        return requiredSpeed
    }
}



struct Winds: Codable, Hashable {
    var velocityAsMetersPerSecond: Double
    var directionAsDegrees: Double
    
    init(velocity: Double, direction: Double, velocityUnit: UnitSpeed = UnitSpeed.knots, directionUnit: UnitAngle = UnitAngle.degrees) {
        self.velocityAsMetersPerSecond = Measurement(value: velocity, unit: velocityUnit).converted(to: .metersPerSecond).value
        self.directionAsDegrees = Measurement(value: direction, unit: directionUnit).converted(to: .degrees).value
    }

    var windVelocityAsText: String {
        get { velocity.value == 0 ? "" : "\(velocity.value)" }
        set { velocity.value = Double(newValue) ?? 0 }
    }
    
    var windDirectionAsText: String {
        get { direction.value == 0 ? "" : "\(direction.value)"}
        set { direction.value = Double(newValue) ?? 0 }
    }
    
    @Transient var velocity: Measurement<UnitSpeed> {
        get {
            return Measurement<UnitSpeed>(value: velocityAsMetersPerSecond, unit: .metersPerSecond)
        }
        set {
            velocityAsMetersPerSecond = newValue.value
        }
    }
    @Transient var direction: Measurement<UnitAngle> {
        get {
            return Measurement(value: directionAsDegrees, unit: .degrees)
        }
        set {
            directionAsDegrees = newValue.converted(to: .degrees).value
        }
    }
    
    func windComponents(given bearing: Double) -> (windCorrectionAngle: Double, windEffectiveVelocity: Double) {
        let windEffectiveVelocity = (velocity.value * cos((direction.value - bearing).degreesToRadians)) * -1
        
        return (0, windEffectiveVelocity)
    }
}

struct CheckPoint: Codable, Hashable, Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var longitude: Double
    var latitude: Double
    
    func getCLCoordinate() -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    func getCLLocation() -> CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
    
    func mapPoint() -> MKMapPoint {
        MKMapPoint(getCLCoordinate())
    }
}

let HOME_LOCATION = CheckPoint(id: UUID(), name: "Home", longitude: -122.379581, latitude: 48.425643)
let TREE_FARM_LOCATION = CheckPoint(id: UUID(), name: "Tree Farm", longitude: -122.36519, latitude: 48.42076)
let BVS_LOCATION = CheckPoint(id: UUID(), name: "BVS Airport", longitude: -122.41299, latitude: 48.46915)
