//
//  CLLocation+Conversions.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/29/23.
//

import CoreLocation

extension CLLocation {
    
    func getBearing(to destination: CLLocation) -> Measurement<UnitAngle>? {
        // Return nil if coordinates are identical to avoid undefined bearing
        guard self.coordinate.latitude != destination.coordinate.latitude ||
                self.coordinate.longitude != destination.coordinate.longitude else { return nil }
        
        let lat1 = self.coordinate.latitude.degreesToRadians
        let lon1 = self.coordinate.longitude.degreesToRadians
        
        let lat2 = destination.coordinate.latitude.degreesToRadians
        let lon2 = destination.coordinate.longitude.degreesToRadians
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radiansBearing = atan2(y, x)
        
        var courseDegrees = Measurement(value: radiansBearing, unit: UnitAngle.radians).converted(to: .degrees).value
        if courseDegrees < 0 {
            courseDegrees = 360.0 + courseDegrees
        }
        return Measurement(value: courseDegrees, unit: UnitAngle.degrees)
    }
    
    func distance(from locations: [CLLocation]) -> CLLocationDistance? {
        guard !locations.isEmpty else { return nil }
        
        var distance = 0.0
        for i in locations.indices {
            if i == 0 {
                distance = self.distance(from: locations[i])
            } else {
                distance = distance + locations[i - 1].distance(from: locations[i])
            }
        }
        return distance
    }
    
    func distance(from location: CLLocation?) -> Measurement<UnitLength>? {
        guard location != nil else { return nil }
        
        return Measurement(value: distance(from: location!), unit: .meters)
    }
}

extension Measurement {
    var erasedType: Measurement<Dimension> {
        return Measurement<Dimension>(value: self.value, unit: self.unit as! Dimension)
    }
}
