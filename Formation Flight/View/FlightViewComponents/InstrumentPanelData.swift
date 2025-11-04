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
    var currentETA: Measurement<Dimension>?
    var bearingNext: Measurement<Dimension>?
    var bearingFinal: Measurement<Dimension>?
    var ETADelta: Measurement<Dimension>?
    var currentTrueAirspeed: Measurement<Dimension>?
    var targetTrueAirspeed: Measurement<Dimension>?
    var distanceToNext: Measurement<Dimension>?
    var distanceToFinal: Measurement<Dimension>?
    var groundSpeed: Measurement<Dimension>?

    
    /// Initializer for Data Structure which cosntains the telemetry for the Instrument Panel
    /// - Parameters:
    ///   - currentETA: Current ETA given the current True Airspeed
    ///   - ETADelta: Drift from expected ETA measured in seconds. May be positive or negative
    ///   - course: Ground course measured in degrees
    ///   - groundSpeed: Current Ground Speed measured in meters per second
    ///   - targetGroundSpeed: Adjusted Recommended adjusted ground speed to close the gap for ToT
    ///   - distanceToNext: Meters to the Next Check Point
    init(currentETA: Measurement<Dimension>?,
         ETADelta: Measurement<Dimension>?,
         bearingNext: Measurement<Dimension>?,
         currentTrueAirSpeed: Measurement<Dimension>?,
         targetTrueAirSpeed: Measurement<Dimension>?,
         distanceToNext: Measurement<Dimension>?,
         distanceToFinal: Measurement<Dimension>?,
         groundSpeed: Measurement<Dimension>?,
         bearingFinal: Measurement<Dimension>?
    ) {
        self.currentETA = currentETA
        self.ETADelta = ETADelta
        self.bearingNext = bearingNext
        self.currentTrueAirspeed = currentTrueAirSpeed
        self.targetTrueAirspeed = targetTrueAirSpeed
        self.distanceToNext = distanceToNext
        self.distanceToFinal = distanceToFinal
        self.groundSpeed = groundSpeed
        self.bearingFinal = bearingFinal
    }
    
    static func emptyPanel() -> InstrumentPanelData {
        return InstrumentPanelData(currentETA: nil,
                                   ETADelta: nil,
                                   bearingNext: nil,
                                   currentTrueAirSpeed: nil,
                                   targetTrueAirSpeed: nil,
                                   distanceToNext: nil,
                                   distanceToFinal: nil,
                                   groundSpeed: nil,
                                   bearingFinal: nil
        )
    }
}

