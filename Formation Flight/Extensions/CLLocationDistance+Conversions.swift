//
//  CLLocationDistance+Conversions.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/29/23.
//

import CoreLocation

extension CLLocationDistance {
    func inNauticalMiles() -> Double {
        return self * 0.00053996
    }
}
