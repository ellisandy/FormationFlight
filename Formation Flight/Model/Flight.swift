//
//  Flight.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/17/23.
//

import Foundation
import SwiftData
import MapKit

/// Individual Planned Flight
@Model
final class Flight {
    var title: String = ""
    var missionDate: Date = Date.now
    var targetAltitude: Double = 0
    var targetSpeed: Double = 0
    var expectedWinds: Winds = Winds(velocity: 0, direction: 0)
    var checkPoints: [CheckPoint] = []
    var interceptTime: Date = Date.now
    

    
    /// Initialize a Flight
    /// - Parameters:
    ///   - title: Title of the flight
    ///   - missionDate: Date of the mission
    ///   - targetAltitude: Target Altitude
    ///   - targetSpeed: Target Ground Speed in Knots
    ///   - expectedWinds: Expected Winds for calciulation
    ///   - checkPoints: A list of checkpoints.
    ///   - interceptTime: DateTime of the intercept (To be deleted)
    init(title: String, missionDate: Date, targetAltitude: Double, targetSpeed: Double, expectedWinds: Winds, checkPoints: [CheckPoint], interceptTime: Date) {
        self.title = title
        self.missionDate = missionDate
        self.targetAltitude = targetAltitude // TODO: Remove
        self.targetSpeed = targetSpeed // TODO: Reconsider if this is needed
        self.expectedWinds = expectedWinds
        self.checkPoints = checkPoints
        self.interceptTime = interceptTime // TODO: Remove
    }

}

extension Flight {
    static func emptyFlight() -> Flight {
        return Flight(title: "", missionDate: Date.now, targetAltitude: 500, targetSpeed: 100, expectedWinds: Winds(velocity: 0, direction: 0), checkPoints: [], interceptTime: Date.now)
    }
    
    func validFlight() -> Bool {
        var validStatus = true
        
        if checkPoints.isEmpty {
            validStatus = false
        }
        
        return validStatus
    }
    
    func getCLCoordinate2D() -> [CLLocationCoordinate2D] {
        return self.checkPoints.map { checkpoint in
            CLLocationCoordinate2D(latitude: checkpoint.latitude, longitude: checkpoint.longitude)
        }
    }
    
    func getCLLocation() -> [CLLocation] {
        return self.checkPoints.map { cp in
            CLLocation(latitude: cp.latitude, longitude: cp.longitude)
        }
    }
    
    func getCLCoordinate2D(userLocation startPoint: CLLocationCoordinate2D?) -> [CLLocationCoordinate2D] {
        if startPoint == nil { return getCLCoordinate2D() }
        
        var locations = getCLCoordinate2D()
        //SAFE
        locations.insert(startPoint!, at: 0)
        
        return locations
    }
}

struct Winds: Codable, Hashable {
    var velocity: Double
    var direction: Double
    
    var windVelocityAsText: String {
        get { velocity == 0 ? "" : "\(velocity)" }
        set { velocity = Double(newValue) ?? 0 }
    }
    
    var windDirectionAsText: String {
        get { direction == 0 ? "" : "\(direction)"}
        set { direction = Double(newValue) ?? 0 }
    }
    
    func windComponents(given bearing: Double) -> (windCorrectionAngle: Double, windEffectiveVelocity: Double) {
        let windEffectiveVelocity = (velocity * cos((direction - bearing).degreesToRadians)) * -1
        
        return (0, windEffectiveVelocity)
    }
}

struct CheckPoint: Codable, Hashable, Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var longitude: Double
    var latitude: Double
    
    func getCLCoordinate() -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    func getCLLocation() -> CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
    
    func mapPoint() -> MKMapPoint {
        MKMapPoint(getCLCoordinate())
    }
}

// 48.42564384298293, -122.37958153333842
let HOME_LOCATION = CheckPoint(id: UUID(), name: "Home", longitude: -122.379581, latitude: 48.425643)
let TREE_FARM_LOCATION = CheckPoint(id: UUID(), name: "Tree Farm", longitude: -122.36519, latitude: 48.42076)
let BVS_LOCATION = CheckPoint(id: UUID(), name: "BVS Airport", longitude: -122.41299, latitude: 48.46915)
