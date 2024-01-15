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
        let tot = Date.now.secondsUntil(time: missionDate)
        let distance = currentLocation.distance(from: getCLLocation())

        var etaDelta: Double? = nil
        var targetAirspeed: Double? = nil

        if let actualTOT = currentLocation.getTime(to: getCLLocation(), with: expectedWinds)?.converted(to: .seconds).value { // Getting Actual ToT
            etaDelta = actualTOT - tot // FIXME: This should handle Optionals
            targetAirspeed = calculateTargetSpeed(actualETA: actualTOT, targetETA: tot, distance: distance)
        }
        
                
        let currentTrueAirSpeed = currentLocation.getTrueAirSpeed(with: expectedWinds)
        let course = currentLocation.getCourse(to: getCLLocation().first!)
        
        let heading = currentLocation.getHeading(airspeed: currentTrueAirSpeed, winds: expectedWinds, course: course)
        
        let eatDeltaMeasurement: Measurement<Dimension>? = {
            if etaDelta != nil {
                return Measurement(value: etaDelta!, unit: UnitDuration.seconds)
            }
            return nil
        }()
        let targetTASMeasurement: Measurement<Dimension>? = {
            if targetAirspeed != nil {
                return Measurement(value: targetAirspeed!, unit: UnitSpeed.metersPerSecond)
            }
            return nil
        }()
        
        let currentTASMeasurement: Measurement<Dimension>? = {
            if currentTrueAirSpeed != nil {
                return Measurement(value: currentTrueAirSpeed!.value, unit: currentTrueAirSpeed!.unit)
            }
            return nil
        }()
        let courseMeasurement: Measurement<Dimension>? = {
            if heading != nil {
                return Measurement(value: heading!.value, unit: heading!.unit)
            }
            return nil
        }()
        return InstrumentPanelData(currentETA: Measurement(value: tot, unit: UnitDuration.seconds),
                                   ETADelta: eatDeltaMeasurement,
                                   course: courseMeasurement,
                                   currentTrueAirSpeed: currentTASMeasurement,
                                   targetTrueAirSpeed: targetTASMeasurement,
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

