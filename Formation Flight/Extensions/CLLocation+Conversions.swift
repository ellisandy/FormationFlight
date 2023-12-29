//
//  CLLocation+Conversions.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/29/23.
//

import CoreLocation

extension CLLocation {
    var speedInKnots: Double {
        get {
            return self.speed * 1.94384
        }
    }
    
    var altitudeInFeet: Double {
        get {
            return self.altitude * 3.28084
        }
    }
    
}
