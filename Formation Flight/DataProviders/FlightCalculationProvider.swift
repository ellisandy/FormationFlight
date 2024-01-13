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
    static func calculateData(currentLocation: CLLocation, targetLocation: CLLocation, winds: Winds, groundSpeed: Double) -> (ETA: Measurement<UnitDuration>, course: Measurement<UnitAngle>) {
        
        let distance: Double = currentLocation.distance(from: targetLocation)
        let bearing = currentLocation.getCourse(to: targetLocation)
        
        return (Measurement(value: distance / groundSpeed, unit: UnitDuration.seconds), bearing)
    }
}

extension Flight {

    // FIXME: Add functionality to compute all CheckPoints
    func provideInstrumentPanelData(from currentLocation: CLLocation) -> InstrumentPanelData {
        let data = currentLocation.getTimeHeadingAndDistance(to: checkPoints.first!.getCLLocation(), with: expectedWinds)
        
        let actualTOT = currentLocation.getTime(to: checkPoints.first!.getCLLocation(), with: expectedWinds)?.converted(to: .seconds).value // Getting Actual ToT
        let tot = Date.now.secondsUntil(time: missionDate)
        let etaDelta = actualTOT! - tot // FIXME: This should handle Optionals
                
        let currentTrueAirSpeed = currentLocation.getTrueAirSpeed(with: expectedWinds)!
        let targetAirspeed = calculateTargetSpeed(actualETA: actualTOT!, targetETA: tot, distance: data.distance.value)
        
        return InstrumentPanelData(currentETA: Measurement(value: tot, unit: UnitDuration.seconds),
                                   ETADelta: Measurement(value: etaDelta, unit: UnitDuration.seconds),
                                   course: Measurement(value: data.heading?.value ?? 0.0, unit: data.heading?.unit ?? .degrees),
                                   // TODO: Ugly type erasure
                                   currentTrueAirSpeed: Measurement(value: currentTrueAirSpeed.value, unit: currentTrueAirSpeed.unit),
                                   targetTrueAirSpeed: Measurement(value: (targetAirspeed), unit: UnitSpeed.metersPerSecond),
                                   distanceToNext: Measurement(value: data.distance.value, unit: data.distance.unit),
                                   // FIXME: This should be the total distance.
                                   distanceToFinal: Measurement(value: data.distance.value, unit: data.distance.unit))
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

