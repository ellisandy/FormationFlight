//
//  Double+Extensions.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/31/23.
//

import Foundation

extension Double {
    var degreesToRadians: Double {
        return self * .pi / 180.0
    }
    
    var radiansToDegrees: Double {
        let degrees = self * 180 / .pi
        
        if degrees < 0 {
            return degrees + 360
        }
        return degrees
    }
    
    var secondsMeasurement: Measurement<UnitDuration> {
        return Measurement(value: self, unit: .seconds)
    }   
    
    var metersPerSecondsMeasurement: Measurement<UnitSpeed> {
        return Measurement(value: self, unit: .metersPerSecond)
    }
    
    var degreesMeasurement: Measurement<UnitAngle> {
        return Measurement(value: self, unit: .degrees)
    }
    
    var metersMeasurement: Measurement<UnitLength> {
        return Measurement(value: self, unit: .meters)
    }
}
