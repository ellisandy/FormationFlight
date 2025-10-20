//
//  UserLocation.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/28/23.
//

import SwiftUI
import CoreLocation

@Observable
class LocationProvider: NSObject, CLLocationManagerDelegate {
    var locationManager: CLLocationManager = CLLocationManager()
    var updateDelegate: (() -> Void)?
    var authroizationStatus: CLAuthorizationStatus?
    var speed: Measurement<Dimension> = Measurement(value: -1.0, unit: UnitSpeed.metersPerSecond)
    var altitude: Measurement<Dimension> = Measurement(value: -1.0, unit: UnitLength.meters)
    var course: Measurement<Dimension> = Measurement(value: -1.0, unit: UnitAngle.degrees)
    var location: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)
    
    init(clManager: CLLocationManager = CLLocationManager()) {
        super.init()
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
            
        case .restricted, .denied:  // Location services currently unavailable.
            // Insert code here of what should happen when Location services are NOT authorized
            print("LocationProvider: Status \(manager.authorizationStatus)")
            break
            
        case .notDetermined:        // Authorization not determined yet.
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
        
        if let unwrappedSpeed = locations.last?.speed {
            speed = Measurement(value: unwrappedSpeed, unit: UnitSpeed.metersPerSecond)
        }
        
        if let unwrappedAltitude = locations.last?.altitude {
            altitude = Measurement(value: unwrappedAltitude, unit: UnitLength.meters)
        }
        
        if let unwrappedCourse = locations.last?.course {
            course = Measurement(value: unwrappedCourse, unit: UnitAngle.degrees)
        }
        
        if let unwrappedLocation = locations.last?.coordinate {
            location = unwrappedLocation
        }
        
        (updateDelegate ?? {print("No Update Delegate")})()
    }
}
