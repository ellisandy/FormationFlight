//
//  UserLocation.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/28/23.
//

import SwiftUI
import CoreLocation
import FormationFlightCore

/// Every consumer (`FlightViewModel`, `FlightsListViewModel`) is MainActor-isolated and the
/// `updateDelegate` callback drives UI state, so the protocol itself is MainActor. Conforming
/// mocks in the test target inherit that isolation.
@MainActor
public protocol LocationProviding: AnyObject {
    // State
    var updateDelegate: (() -> Void)? { get set }
    /// Current Core Location authorization, `.notDetermined` until the system reports one.
    /// Updated for every status, so denied and restricted are visible to the UI (B-16).
    var authorizationStatus: CLAuthorizationStatus { get }
    /// Whether the user granted precise location; reduced accuracy is useless for timing.
    var accuracyAuthorization: CLAccuracyAuthorization { get }
    /// `true` for `.denied` and `.restricted`: the app cannot obtain a fix and should offer a
    /// route to Settings rather than waiting.
    var isLocationDenied: Bool { get }
    @available(*, deprecated, renamed: "authorizationStatus")
    var authroizationStatus: CLAuthorizationStatus? { get }
    var speed: Measurement<UnitSpeed> { get }
    var altitude: Measurement<UnitLength> { get }
    var course: Measurement<UnitAngle> { get }
    var currentLocation: CLLocation? { get }
    var computedSpeedAndCourse: Bool { get }
    /// The newest fix's own Core Location `timestamp` (when it was measured, not delivered).
    /// `nil` until the first fix arrives.
    var lastFixTimestamp: Date? { get }

    // Control
    func startMonitoring()
    func stopMonitoring()
    /// Asks the system for When-In-Use permission; a no-op once the status is determined.
    func requestWhenInUseAuthorization()
}

extension LocationProviding {
    var isLocationDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }
}

/// MainActor-isolated location source (B-27).
///
/// `CLLocationManagerDelegate` is a nonisolated Objective-C protocol, so the conformance is
/// declared `@preconcurrency`. That lets the delegate methods below stay MainActor-isolated
/// (they mutate observed state) while satisfying the protocol; Swift inserts a runtime
/// isolation check in each Objective-C thunk instead of a compile-time error. The check holds
/// because Core Location delivers delegate callbacks on the run loop of the thread that
/// created the `CLLocationManager`, and every manager handed to this class is created on the
/// main thread (`shared`, SwiftUI view models, and the unit tests).
@Observable
@MainActor
final class LocationProvider: NSObject, @preconcurrency CLLocationManagerDelegate, LocationProviding {
    static let shared = LocationProvider()
    var updateDelegate: (() -> Void)?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var accuracyAuthorization: CLAccuracyAuthorization = .fullAccuracy
    /// Pre-B-16 spelling, kept for one release. It was `nil` until authorization was granted,
    /// so `.notDetermined` maps back to `nil` to preserve that contract for existing callers.
    @available(*, deprecated, renamed: "authorizationStatus")
    var authroizationStatus: CLAuthorizationStatus? {
        authorizationStatus == .notDetermined ? nil : authorizationStatus
    }
    var speed: Measurement<UnitSpeed> = Measurement(value: -1.0, unit: UnitSpeed.metersPerSecond)
    var altitude: Measurement<UnitLength> = Measurement(value: -1.0, unit: UnitLength.meters)
    var course: Measurement<UnitAngle> = Measurement(value: -1.0, unit: UnitAngle.degrees)
    var currentLocation: CLLocation?
    var computedSpeedAndCourse: Bool = false
    var lastFixTimestamp: Date?

    /// The most recent fixes, oldest first, each carrying its own Core Location `timestamp`
    /// (B-22). Capped at `maxBufferedFixes`.
    private var previousLocations: [CLLocation] = []
    private static let maxBufferedFixes = 10
    /// Segments between consecutive buffered fixes longer than this are left out of the manual
    /// estimate: averaging across a GPS dropout would describe the gap, not the current motion.
    private static let maxSegmentInterval: TimeInterval = 30
    /// Assigned once in `init`; no second manager is allocated when one is injected (T-07).
    private let locationManager: CLLocationManager

    init(clManager: CLLocationManager = CLLocationManager()) {
        self.locationManager = clManager
        super.init()
        self.locationManager.delegate = self
    }
    
    func startMonitoring() {
        AppLogger.location.debug("LocationProvider: Start monitoring")
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }
    
    func stopMonitoring() {
        AppLogger.location.debug("LocationProvider: Stop monitoring")
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }

    func requestWhenInUseAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    // MARK: Core Location Delegates
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Publish every status, not just the granted one, so the UI can react to denied,
        // restricted and reduced-accuracy states (B-16).
        authorizationStatus = manager.authorizationStatus
        accuracyAuthorization = manager.accuracyAuthorization

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()

        case .restricted, .denied:
            AppLogger.location.warning("LocationProvider: Status \(manager.authorizationStatus.rawValue)")

        case .notDetermined:
            manager.requestWhenInUseAuthorization()

        @unknown default:
            AppLogger.location.warning("LocationProvider: Unknown status \(manager.authorizationStatus.rawValue)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        AppLogger.location.error("LocationProvider error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        AppLogger.location.debug("LocationProvider: location updated")
        
        if let _lastLocation = locations.last {
            currentLocation = _lastLocation
            lastFixTimestamp = _lastLocation.timestamp

            // Buffer the incoming fixes with their own timestamps (B-22). Stamping them with
            // the receipt time collapsed every fix in a batch onto one instant (dt == 0) and
            // folded delivery latency into cross-batch segments.
            previousLocations.append(contentsOf: locations)
            if previousLocations.count > Self.maxBufferedFixes {
                previousLocations = Array(previousLocations.suffix(Self.maxBufferedFixes))
            }
            
            // Core Location reports "no altitude" with a negative verticalAccuracy; the
            // altitude value itself may legitimately be negative (below sea level).
            if _lastLocation.verticalAccuracy >= 0 {
                altitude = Measurement(value: _lastLocation.altitude, unit: UnitLength.meters)
            }

            // Speed and course are valid when >= 0 (0 is "stopped" / "due north") and the
            // sentinel when < 0 (B-07). An invalid value falls back to the manual estimate
            // from the buffer; if that is unavailable too, the published value is reset to
            // the -1 sentinel so a stopped aircraft or a lost fix never shows a stale reading.
            let hasValidSpeed = _lastLocation.speed >= 0
            let hasValidCourse = _lastLocation.course >= 0
            let estimate = (hasValidSpeed && hasValidCourse) ? nil : computeManualSpeedAndCourse()

            if hasValidSpeed {
                speed = Measurement(value: _lastLocation.speed, unit: UnitSpeed.metersPerSecond)
            } else {
                speed = estimate?.speed ?? Measurement(value: -1, unit: UnitSpeed.metersPerSecond)
            }

            if hasValidCourse {
                course = Measurement(value: _lastLocation.course, unit: UnitAngle.degrees)
            } else {
                course = estimate?.course ?? Measurement(value: -1, unit: UnitAngle.degrees)
            }

            computedSpeedAndCourse = estimate != nil
        }
        
        (updateDelegate ?? { AppLogger.location.debug("LocationProvider: No update delegate") })()
    }
    
    /// Computes manual ground speed and course using the buffered previous locations.
    /// - Returns: A tuple of speed (m/s) and course (degrees) if computable, otherwise nil.
    private func computeManualSpeedAndCourse() -> (speed: Measurement<UnitSpeed>, course: Measurement<UnitAngle>)? {
        // Need at least two samples
        guard previousLocations.count >= 2 else { return nil }

        let samples = previousLocations

        var validSegmentCount = 0
        var speedSumMps: Double = 0

        // For circular mean of angles
        var sumSin: Double = 0
        var sumCos: Double = 0

        for i in 1..<samples.count {
            let a = samples[i - 1]
            let b = samples[i]

            // Each fix carries the time it was measured (B-22). Skip zero/negative gaps
            // (duplicate or out-of-order fixes) and gaps longer than `maxSegmentInterval`.
            let dt = b.timestamp.timeIntervalSince(a.timestamp)
            guard dt > 0, dt <= Self.maxSegmentInterval else { continue }

            let dMeters = haversineDistanceMeters(from: a.coordinate, to: b.coordinate)
            let segSpeed = dMeters / dt // m/s

            speedSumMps += segSpeed
            validSegmentCount += 1

            // A stationary segment has no defined bearing; it still counts toward the speed
            // average but contributes nothing to the circular mean of the course.
            if let bearing = a.coordinate.initialBearing(to: b.coordinate) {
                let bearingRad = bearing.value.degreesToRadians
                sumSin += sin(bearingRad)
                sumCos += cos(bearingRad)
            }
        }

        guard validSegmentCount > 0 else { return nil }

        let avgSpeedMps = speedSumMps / Double(validSegmentCount)
        let avgBearingRad = atan2(sumSin / Double(validSegmentCount), sumCos / Double(validSegmentCount))
        var avgBearingDeg = avgBearingRad.radiansToDegrees
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
}
