//
//  Checkpoints.swift
//  Formation Flight
//
//  Created by Jack Ellis on 1/15/24.
//

import Foundation
import SwiftData
import MapKit

struct Target: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var longitude: Double
    var latitude: Double
    
    init(id: UUID = UUID(), longitude: Double, latitude: Double) {
        self.id = id
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

