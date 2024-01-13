//
//  InstrumentPanelData.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/30/23.
//

import Foundation

typealias Seconds = Double
typealias Heading = Double
typealias MetersPerSeconds = Double
typealias Meters = Double

/// Data Struct to contain the required information for the Instrument panel
@Observable
class InstrumentPanelData {
    var currentETA: Seconds
    var ETADelta: Seconds
    var course: Heading
    var currentTrueAirspeed: MetersPerSeconds
    var targetTrueAirspeed: MetersPerSeconds
    var distanceToNext: Meters
    var distanceToFinal: Meters

    
    /// Initializer for Data Structure which cosntains the telemetry for the Instrument Panel
    /// - Parameters:
    ///   - currentETA: Current ETA given the current True Airspeed
    ///   - ETADelta: Drift from expected ETA measured in seconds. May be positive or negative
    ///   - course: Ground course measured in degrees
    ///   - groundSpeed: Current Ground Speed measured in meters per second
    ///   - targetGroundSpeed: Adjusted Recommended adjusted ground speed to close the gap for ToT
    ///   - distanceToNext: Meters to the Next Check Point
    init(currentETA: Seconds, ETADelta: Seconds, course: Heading, currentTrueAirSpeed: MetersPerSeconds, targetTrueAirSpeed: MetersPerSeconds, distanceToNext: Meters, distanceToFinal: Meters) {
        self.currentETA = currentETA
        self.ETADelta = ETADelta
        self.course = course
        self.currentTrueAirspeed = currentTrueAirSpeed
        self.targetTrueAirspeed = targetTrueAirSpeed
        self.distanceToNext = distanceToNext
        self.distanceToFinal = distanceToFinal
    }
}

extension InstrumentPanelData {
    // TODO: Dear lord, this is hideous.
    static func formatSmallSeconds(seconds: Int) -> String {
        var secondsToConvert = seconds
        
        //Make sure it returns a positive value
        if secondsToConvert < 0 {
            secondsToConvert = seconds * -1
        }
        
        switch secondsToConvert {
        case _ where secondsToConvert == 0:
            return "00"
        case _ where secondsToConvert < 10:
            return "0\(secondsToConvert)"
        default:
            return String(secondsToConvert)
        }
    }
}

extension Double {
    func toTimeString() -> String {
        let totInt = Int(self)
        
        let minutes = (totInt % 3600) / 60
        let seconds = (totInt % 3600) % 60
        
        return "\(minutes):\(InstrumentPanelData.formatSmallSeconds(seconds: seconds))"
    }
    func toBearingString() -> String {
        return String(format: "%.0f°", self)
    }
    
    func toAirSpeedString() -> String {
        return String(format: "%.0f", self)
    }
}
