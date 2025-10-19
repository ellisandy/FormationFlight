//
//  CLLocation+Conversions.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/29/23.
//

import CoreLocation

extension CLLocation {

    func getTrueAirSpeed(with winds: Winds) -> Measurement<UnitSpeed>? {
        if speed < 0 { return nil } // TODO: Test
        
        if course < 0 { return nil } // TODO: Test
        
        let airComponent = SIMD2(x: speed * cos(course.degreesToRadians),
                                 y: speed * sin(course.degreesToRadians))
        let windComponent = SIMD2(x: winds.velocity.converted(to: .metersPerSecond).value * cos(winds.direction.converted(to: .radians).value),
                                  y: winds.velocity.converted(to: .metersPerSecond).value * sin(winds.direction.converted(to: .radians).value))
        
        let combinedVector = airComponent + windComponent
        
        let airspeed = (combinedVector * combinedVector).sum().squareRoot()
        
        return Measurement(value: airspeed, unit: UnitSpeed.metersPerSecond)
    }
    
    func getCourse(to destination: CLLocation) -> Measurement<UnitAngle> {
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

    func getTime(to destinations: [CLLocation], with winds: Winds) -> Measurement<UnitDuration>? {
        // Bail out if there's not a valid speed
        if speed < 0 { return nil }
        
        // Bail out if there's not a valid course
        if course < 0 { return nil }
        
        // Bail out if destinations is empty
        if destinations.isEmpty { return nil }
        
        guard let tas = getTrueAirSpeed(with: winds) else {
            return nil
        }
        
        var previousLocation = self
        return destinations.map { location in
            let distanceToNext = previousLocation.distance(from: location)
            let course = previousLocation.getCourse(to: location)
            
            let groundSpeed = calculateGroundSpeed(tas: tas, winds: winds, course: course)
            previousLocation = location
            
            return distanceToNext / groundSpeed
        }.reduce(0.0) { partialResult, time in
            return partialResult + time
        }.secondsMeasurement
}
    
    func getTime(to destination: CLLocation, with winds: Winds) -> Measurement<UnitDuration>? {
        return getTime(to: [destination], with: winds)
    }
        
    func getHeading(airspeed: Measurement<UnitSpeed>?, winds: Winds, course: Measurement<UnitAngle>) -> Measurement<UnitAngle>? {
        guard let unwrappedAirspeed = airspeed else { return nil }
        
        let tasMetersPerSecond: Double = unwrappedAirspeed.converted(to: .metersPerSecond).value
        let windVelocityMetersPerSecond: Double = winds.velocity.converted(to: .metersPerSecond).value
        let bearingNextRadians: Double = course.converted(to: .radians).value
        let windDirectionRadian: Double = winds.direction.converted(to: .radians).value
        
        let wca = calculateWindCorrectionAngle(tas: unwrappedAirspeed, winds: winds, course: course)
        
        let airComponent = SIMD2(x: tasMetersPerSecond * cos(bearingNextRadians),
                                 y: tasMetersPerSecond * sin(bearingNextRadians))
        let windComponent = SIMD2(x: windVelocityMetersPerSecond * cos(windDirectionRadian + wca),
                                  y: windVelocityMetersPerSecond * sin(windDirectionRadian + wca))
        
        let combinedVector = airComponent + windComponent
        let heading = atan2(combinedVector.y, combinedVector.x).radiansToDegrees

        return Measurement(value: heading, unit: UnitAngle.degrees)
    }
    
    func getTargetAirspeed(tot: Measurement<UnitDuration>, destinations: [CLLocation], winds: Winds) -> Measurement<UnitSpeed>? {
        guard let currentArrivalTime = getTime(to: destinations, with: winds) else { return nil }
        guard let currentTAS = getTrueAirSpeed(with: winds) else { return nil }
        guard let totalDistance = distance(from: destinations) else { return nil }

        let roughCurrentGS = totalDistance / currentArrivalTime.value
        let roughWantedGS = totalDistance / tot.value
        
        let adjustedTAS = currentTAS.value + (roughWantedGS - roughCurrentGS)
        
        return adjustedTAS.metersPerSecondsMeasurement
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
    
    fileprivate func calculateWindCorrectionAngle(tas: Measurement<UnitSpeed>,
                                                  winds: Winds,
                                                  course: Measurement<UnitAngle>) -> Double {
        let tasMetersPerSecond: Double = tas.converted(to: .metersPerSecond).value
        let windVelocityMetersPerSecond: Double = winds.velocity.converted(to: .metersPerSecond).value
        let bearingNextRadians: Double = course.converted(to: .radians).value
        let windDirectionRadian: Double = winds.direction.converted(to: .radians).value

        return asin(windVelocityMetersPerSecond /
                    tasMetersPerSecond *
                    sin(bearingNextRadians - (180.0.degreesToRadians - windDirectionRadian)))
    }
    
    fileprivate func calculateGroundSpeed(tas: Measurement<UnitSpeed>,
                                          winds: Winds,
                                          course: Measurement<UnitAngle>) -> Double {
        let tasMetersPerSecond: Double = tas.converted(to: .metersPerSecond).value
        let windVelocityMetersPerSecond: Double = winds.velocity.converted(to: .metersPerSecond).value
        let bearingNextRadians: Double = course.converted(to: .radians).value
        let windDirectionRadian: Double = winds.direction.converted(to: .radians).value
        
        let wca = calculateWindCorrectionAngle(tas: tas, winds: winds, course: course)
        
        return sqrt(pow(tasMetersPerSecond, 2) +
                    pow(windVelocityMetersPerSecond, 2) -
                    (2 *
                     tasMetersPerSecond *
                     windVelocityMetersPerSecond *
                     cos(bearingNextRadians - windDirectionRadian + wca)))
    }

}

extension Measurement {
    var erasedType: Measurement<Dimension> {
        return Measurement<Dimension>(value: self.value, unit: self.unit as! Dimension)
    }
}
