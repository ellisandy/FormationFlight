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
    
    func getTrueAirSpeed(with winds: Winds) -> Double? {
        if speed < 0 { return nil } // TODO: Test
        
        if course < 0 { return nil } // TODO: Test
        
        let airComponent = SIMD2(x: speed * cos(course.degreesToRadians),
                                 y: speed * sin(course.degreesToRadians))
        let windComponent = SIMD2(x: winds.velocity * cos(winds.direction.degreesToRadians),
                                  y: winds.velocity * sin(winds.direction.degreesToRadians ))
        
        let combinedVector = airComponent + windComponent
        
        let airspeed = (combinedVector * combinedVector).sum().squareRoot()
        
        return airspeed
    }
    
    func getCourse(to destination: CLLocation) -> Heading {
        let lat1 = self.coordinate.latitude.degreesToRadians
        let lon1 = self.coordinate.longitude.degreesToRadians
        
        let lat2 = destination.coordinate.latitude.degreesToRadians
        let lon2 = destination.coordinate.longitude.degreesToRadians
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radiansBearing = atan2(y, x)
        
        return radiansBearing.radiansToDegrees
    }
    
    func getTime(to destination: CLLocation, with winds: Winds) -> Seconds? {
        
        // Bail out if there's not a valid speed
        if speed < 0 { return nil }
        
        // Bail out if there's not a valid course
        if course < 0 { return nil }
        
        let distanceToDestination = distance(from: destination)
        guard let tas = getTrueAirSpeed(with: winds) else {
            return nil
        }
        
        let bearing = getCourse(to: destination)
        let wca = asin(winds.velocity / tas * sin(bearing.degreesToRadians - (180.0.degreesToRadians - winds.direction.degreesToRadians)))
                        
        let airspeed = sqrt(pow(tas, 2) + pow(winds.velocity, 2) -
                            (2 * tas * winds.velocity * cos(bearing.degreesToRadians - winds.direction.degreesToRadians + wca)))
        
        return distanceToDestination / airspeed
    }

    func getTime(to destinations: [CLLocation], with winds: Winds) -> Seconds? {
        
        // Bail out if there's not a valid speed
        if speed < 0 { return nil }
        
        // Bail out if there's not a valid course
        if course < 0 { return nil }
        
        // Bail out if destinations is empty
        if destinations.isEmpty { return nil }
        
        let distanceToDestination = distance(from: destinations)
        guard let tas = getTrueAirSpeed(with: winds) else {
            return nil
        }
        
        let bearing = getCourse(to: destinations.first!)
        let wca = asin(winds.velocity / tas * sin(bearing.degreesToRadians - (180.0.degreesToRadians - winds.direction.degreesToRadians)))
                        
        let airspeed = sqrt(pow(tas, 2) + pow(winds.velocity, 2) -
                            (2 * tas * winds.velocity * cos(bearing.degreesToRadians - winds.direction.degreesToRadians + wca)))
        
        return distanceToDestination / airspeed
    }
    
    // TODO: Add Documenetation
    func getTimeHeadingAndDistance(to destination: CLLocation, with winds: Winds) -> (time: Seconds?, heading: Heading?, distance: Double, targetAirspeed: Double?) {
        let distanceToDestination = distance(from: destination)
        let bearing = getCourse(to: destination)

        // Bail out if there's not a valid speed
        if speed < 0 { return (nil, nil, distanceToDestination, nil) }
        
        // Bail out if there's not a valid course
        if course < 0 { return (nil, nil, distanceToDestination, nil) }
        
        guard let tas = getTrueAirSpeed(with: winds) else {
            return (nil, nil, distanceToDestination, nil)
        }
        
        let wca = asin(winds.velocity / tas * sin(bearing.degreesToRadians - (180.0.degreesToRadians - winds.direction.degreesToRadians)))
        
        let airComponent = SIMD2(x: tas * cos(bearing.degreesToRadians),
                                 y: tas * sin(bearing.degreesToRadians))
        let windComponent = SIMD2(x: winds.velocity * cos(winds.direction.degreesToRadians + wca),
                                  y: winds.velocity * sin(winds.direction.degreesToRadians + wca))
        
        let combinedVector = airComponent + windComponent
        
        let heading = atan2(combinedVector.y, combinedVector.x).radiansToDegrees
        let airspeed = sqrt(pow(tas, 2) + pow(winds.velocity, 2) - 
                            (2 * tas * winds.velocity * cos(bearing.degreesToRadians - winds.direction.degreesToRadians + wca)))
        

        return (distanceToDestination / airspeed,
                heading,
                distanceToDestination,
                airspeed)
    }
    
    func distance(from locations: [CLLocation]) -> CLLocationDistance {
        var distance = 0.0
        for i in locations.indices {
            if i == 0 {
                distance = self.distance(from: locations[i])
            } else {
                distance = locations[i - 1].distance(from: locations[i])
            }
        }
        return distance
    }
}
