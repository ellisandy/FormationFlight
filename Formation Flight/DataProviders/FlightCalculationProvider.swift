//
//  FlightCalculationProvider.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/30/23.
//

import CoreLocation

struct FlightCalculationProvider {}

extension FlightCalculationProvider {
    // TODO: Remove this and move the remaining code to Flight Extension file.
    static func calculateData(currentLocation: CLLocation, targetLocation: CLLocation, winds: Winds, groundSpeed: Double) -> (ETA: Double, course: Double) {
        let distance = currentLocation.distance(from: targetLocation)
        let bearing = currentLocation.getCourse(to: targetLocation)
        
        return (distance / groundSpeed, bearing)
    }
}

extension Flight {

    // FIXME: Add functionality to compute all CheckPoints
    func provideInstrumentPanelData(from currentLocation: CLLocation) -> InstrumentPanelData {
        let data = currentLocation.getTimeHeadingAndDistance(to: checkPoints.first!.getCLLocation(), with: expectedWinds)
        
        let actualTOT = currentLocation.getTime(to: checkPoints.first!.getCLLocation(), with: expectedWinds) //distance / currentLocation.speed // Getting Actual ToT
        let tot = Date.now.secondsUntil(time: missionDate)
        let etaDelta = actualTOT! - tot // FIXME: This should handle Optionals
                
        let currentTrueAirSpeed = currentLocation.getTrueAirSpeed(with: expectedWinds)
        let targetAirspeed = calculateTargetSpeed(actualETA: actualTOT!, targetETA: tot, distance: data.distance)
        
        return InstrumentPanelData(currentETA: tot,
                                   ETADelta: etaDelta,
                                   course: data.heading ?? 0.0,
                                   currentTrueAirSpeed: currentTrueAirSpeed ?? 0.0,
                                   targetTrueAirSpeed: targetAirspeed,
                                   distanceToNext: data.distance,
                                   // FIXME: This should be the total distance.
                                   distanceToFinal: data.distance)
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

