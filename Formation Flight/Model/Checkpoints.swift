//
//  Checkpoints.swift
//  Formation Flight
//
//  Created by Jack Ellis on 1/15/24.
//

import Foundation
import SwiftData
import MapKit

final class CheckPoint: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let longitude: Double
    let latitude: Double

    init(id: UUID = UUID(), name: String, longitude: Double, latitude: Double) {
        self.id = id
        self.name = name
        self.longitude = longitude
        self.latitude = latitude
    }
    
    func getCLCoordinate() -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    func getCLLocation() -> CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
    
    static func == (lhs: CheckPoint, rhs: CheckPoint) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.longitude == rhs.longitude && lhs.latitude == rhs.latitude
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(longitude)
        hasher.combine(latitude)
    }
}
