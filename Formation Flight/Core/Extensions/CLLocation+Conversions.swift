//
//  CLLocation+Conversions.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/29/23.
//

import CoreLocation

extension CLLocationCoordinate2D {

    /// Initial bearing (forward azimuth) from this coordinate to `destination`, in degrees
    /// normalised to [0, 360). Returns `nil` when the coordinates are identical, because the
    /// bearing between a point and itself is undefined.
    ///
    /// This is the single forward-azimuth implementation in the app; `CLLocation.getBearing(to:)`
    /// and `LocationProvider`'s manual course estimate both delegate here (B-36).
    func initialBearing(to destination: CLLocationCoordinate2D) -> Measurement<UnitAngle>? {
        guard latitude != destination.latitude || longitude != destination.longitude else { return nil }

        let lat1 = latitude.degreesToRadians
        let lon1 = longitude.degreesToRadians

        let lat2 = destination.latitude.degreesToRadians
        let lon2 = destination.longitude.degreesToRadians

        let dLon = lon2 - lon1

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        var courseDegrees = atan2(y, x).radiansToDegrees
        if courseDegrees < 0 {
            courseDegrees += 360.0
        }
        return Measurement(value: courseDegrees, unit: UnitAngle.degrees)
    }
}

extension CLLocation {

    func getBearing(to destination: CLLocation) -> Measurement<UnitAngle>? {
        coordinate.initialBearing(to: destination.coordinate)
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
