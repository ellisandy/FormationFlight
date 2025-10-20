//
//  Checkpoints.swift
//  Formation Flight
//
//  Created by Jack Ellis on 1/15/24.
//

import Foundation
import SwiftData
import MapKit

struct CheckPoint: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var longitude: Double
    var latitude: Double

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
}
