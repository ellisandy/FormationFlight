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
    var authroizationStatus: CLAuthorizationStatus?
    var speedInKnots: Double = -1
    var altitudeInFeet: Double = -1
    var course: Double = -1
    
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

        if let unwrappedSpeed = locations.last?.speedInKnots {
            speedInKnots = unwrappedSpeed
        }
        
        if let unwrappedAltitude = locations.last?.altitudeInFeet {
            altitudeInFeet = unwrappedAltitude
        }
        
        if let unwrappedCourse = locations.last?.course {
            course = unwrappedCourse
        }
    }
}
