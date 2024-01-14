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
        
        let distanceToDestination = distance(from: destinations)

        // FIXME: Calculate Multiple Destinations
        let course = getCourse(to: destinations.first!)

        let groundSpeed = calculateGroundSpeed(tas: tas, winds: winds, course: course)

        return Measurement(value: (distanceToDestination / groundSpeed), unit: .seconds)
    }
    
    func getTime(to destination: CLLocation, with winds: Winds) -> Measurement<UnitDuration>? {
        return getTime(to: [destination], with: winds)
    }
    
    // TODO: Add Documenetation
//    func getTimeHeadingAndDistance(to destination: CLLocation, with winds: Winds) -> (time: Measurement<UnitDuration>?, heading: Measurement<UnitAngle>?, distance: Measurement<UnitLength>, targetAirspeed: Measurement<UnitSpeed>?) {
//        let distanceToDestination: Measurement<UnitLength> = distance(from: destination)  //FIXME: Distance to Final
//        let expectedCourse = getCourse(to: destination)
//
//        // Bail out if there's not a valid speed
//        if speed < 0 { return (nil, nil, distanceToDestination, nil) }
//        
//        // Bail out if there's not a valid course
//        if course < 0 { return (nil, nil, distanceToDestination, nil) }
//        
//        guard let tas = getTrueAirSpeed(with: winds) else {
//            return (nil, nil, distanceToDestination, nil)
//        }
//        
//        let combinedVector = combineDirectionAndVelocity(airspeed: tas, winds: winds, course: expectedCourse)
//        
//        let heading = atan2(combinedVector.y, combinedVector.x).radiansToDegrees
//
//        let airspeed = calculateGroundSpeed(tas: tas, winds: winds, course: expectedCourse)
//        
//        let time = distanceToDestination.converted(to: .meters).value / airspeed
//
//        return (Measurement(value: time, unit: .seconds),
//                Measurement(value: heading, unit: .degrees),
//                distanceToDestination,
//                Measurement(value: airspeed, unit: .metersPerSecond))
//    }
//    
    
    func getHeading(airspeed: Measurement<UnitSpeed>, winds: Winds, course: Measurement<UnitAngle>) -> Measurement<UnitAngle> {
        let tasMetersPerSecond: Double = airspeed.converted(to: .metersPerSecond).value
        let windVelocityMetersPerSecond: Double = winds.velocity.converted(to: .metersPerSecond).value
        let bearingNextRadians: Double = course.converted(to: .radians).value
        let windDirectionRadian: Double = winds.direction.converted(to: .radians).value
        
        let wca = calculateWindCorrectionAngle(tas: airspeed, winds: winds, course: course)
        
        let airComponent = SIMD2(x: tasMetersPerSecond * cos(bearingNextRadians),
                                 y: tasMetersPerSecond * sin(bearingNextRadians))
        let windComponent = SIMD2(x: windVelocityMetersPerSecond * cos(windDirectionRadian + wca),
                                  y: windVelocityMetersPerSecond * sin(windDirectionRadian + wca))
        
        let combinedVector = airComponent + windComponent
        let heading = atan2(combinedVector.y, combinedVector.x).radiansToDegrees

        return Measurement(value: heading, unit: UnitAngle.degrees)
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
    
    func distance(from location: CLLocation) -> Measurement<UnitLength> {
        return Measurement(value: distance(from: location), unit: .meters)
    }
    
    fileprivate func calculateWindCorrectionAngle(tas: Measurement<UnitSpeed>, winds: Winds, course: Measurement<UnitAngle>) -> Double {

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
