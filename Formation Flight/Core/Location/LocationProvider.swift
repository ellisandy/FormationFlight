//
//  UserLocation.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/28/23.
//

import SwiftUI
import CoreLocation

private struct TimedLocation {
    let location: CLLocation
    let timestamp: Date
}

@Observable
class LocationProvider: NSObject, CLLocationManagerDelegate, ObservableObject {
    var locationManager: CLLocationManager = CLLocationManager()
    var updateDelegate: (() -> Void)?
    var authroizationStatus: CLAuthorizationStatus?
    var speed: Measurement<UnitSpeed> = Measurement(value: -1.0, unit: UnitSpeed.metersPerSecond)
    var altitude: Measurement<UnitLength> = Measurement(value: -1.0, unit: UnitLength.meters)
    var course: Measurement<UnitAngle> = Measurement(value: -1.0, unit: UnitAngle.degrees)
    var currentLocation: CLLocation?
    var computedSpeedAndCourse: Bool = false
    
    private var previousLocations: [TimedLocation] = []
    
    init(clManager: CLLocationManager = CLLocationManager()) {
        
        super.init()
        self.locationManager = clManager
        self.locationManager.delegate = self
    }
    
    func startMonitoring() {
        print("LocationProvider: Start monitoring")
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }
    
    func stopMonitoring() {
        print("LocationProvider: Stop monitoring")
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }
    
    // MARK: Core Location Delegates
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse:  // Location services are available.
            // Insert code here of what should happen when Location services are authorized
            authroizationStatus = .authorizedWhenInUse
            manager.requestLocation()
            break
            
        case .restricted, .denied: // Location services currently unavailable.
            // Insert code here of what should happen when Location services are NOT authorized
            print("LocationProvider: Status \(manager.authorizationStatus)")
            break
            
        case .notDetermined: // Authorization not determined yet.
            manager.requestWhenInUseAuthorization()
            break
            
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationProvider: ERROR \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("LocationProvider: location Updated")
        
        if let _lastLocation = locations.last {
            currentLocation = _lastLocation
            
            // Append incoming locations with timestamps and keep only the last 10
            let now = Date()
            let newTimed = locations.map { TimedLocation(location: $0, timestamp: now) }
            previousLocations.append(contentsOf: newTimed)
            if previousLocations.count > 10 {
                previousLocations = Array(previousLocations.suffix(10))
            }
            
            if _lastLocation.speed < 0 {
                speed = Measurement(value: _lastLocation.speed, unit: UnitSpeed.metersPerSecond)
            }
            
            if _lastLocation.altitude < 0 {
                altitude = Measurement(value: _lastLocation.altitude, unit: UnitLength.meters)
            }
            
            if _lastLocation.course < 0 {
                course = Measurement(value: _lastLocation.course, unit: UnitAngle.degrees)
            }
            
            if course.value < 0 || speed.value < 0 {
                if let computed = computeManualSpeedAndCourse() {
                    speed = computed.speed
                    course = computed.course
                    
                    computedSpeedAndCourse = true
                }
            } else {
                computedSpeedAndCourse = false
            }
        }
        
        (updateDelegate ?? {print("No Update Delegate")})()
    }
    
    /// Computes manual ground speed and course using the buffered previous locations.
    /// - Returns: A tuple of speed (m/s) and course (degrees) if computable, otherwise nil.
    private func computeManualSpeedAndCourse() -> (speed: Measurement<UnitSpeed>, course: Measurement<UnitAngle>)? {
        // Need at least two samples
        guard previousLocations.count >= 2 else { return nil }
        
        // Work with up to the last 10 samples
        let samples = Array(previousLocations.suffix(10))
        
        var validSegmentCount = 0
        var speedSumMps: Double = 0
        
        // For circular mean of angles
        var sumSin: Double = 0
        var sumCos: Double = 0
        
        for i in 1..<samples.count {
            let a = samples[i - 1]
            let b = samples[i]
            
            let dt = b.timestamp.timeIntervalSince(a.timestamp)
            // Only include segments with dt > 0 and <= 5 seconds
            guard dt > 0, dt <= 5 else { continue }
            
            let dMeters = haversineDistanceMeters(from: a.location.coordinate, to: b.location.coordinate)
            let segSpeed = dMeters / dt // m/s
            
            let bearingDeg = initialBearingDegrees(from: a.location.coordinate, to: b.location.coordinate)
            let bearingRad = bearingDeg * .pi / 180
            
            speedSumMps += segSpeed
            sumSin += sin(bearingRad)
            sumCos += cos(bearingRad)
            validSegmentCount += 1
        }
        
        guard validSegmentCount > 0 else { return nil }
        
        let avgSpeedMps = speedSumMps / Double(validSegmentCount)
        let avgBearingRad = atan2(sumSin / Double(validSegmentCount), sumCos / Double(validSegmentCount))
        var avgBearingDeg = avgBearingRad * 180 / .pi
        if avgBearingDeg < 0 { avgBearingDeg += 360 }
        
        let speed = Measurement(value: avgSpeedMps, unit: UnitSpeed.metersPerSecond)
        let course = Measurement(value: avgBearingDeg, unit: UnitAngle.degrees)
        return (speed, course)
    }
    
    /// Great-circle distance using the haversine formula (in meters)
    private func haversineDistanceMeters(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let R = 6_371_000.0 // Earth radius in meters
        
        let φ1 = from.latitude * .pi / 180
        let φ2 = to.latitude * .pi / 180
        let Δφ = (to.latitude - from.latitude) * .pi / 180
        let Δλ = (to.longitude - from.longitude) * .pi / 180
        
        let a = sin(Δφ/2) * sin(Δφ/2) + cos(φ1) * cos(φ2) * sin(Δλ/2) * sin(Δλ/2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }
    
    /// Initial bearing (forward azimuth) from point A to B in degrees [0, 360)
    private func initialBearingDegrees(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let φ1 = from.latitude * .pi / 180
        let φ2 = to.latitude * .pi / 180
        let λ1 = from.longitude * .pi / 180
        let λ2 = to.longitude * .pi / 180
        
        let y = sin(λ2 - λ1) * cos(φ2)
        let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(λ2 - λ1)
        var θ = atan2(y, x) * 180 / .pi
        if θ < 0 { θ += 360 }
        return θ
    }
}
