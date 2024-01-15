//
//  Checkpoints.swift
//  Formation Flight
//
//  Created by Jack Ellis on 1/15/24.
//

import Foundation
import SwiftData
import MapKit

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

let HOME_LOCATION = CheckPoint(id: UUID(), name: "Home", longitude: -122.379581, latitude: 48.425643)
let TREE_FARM_LOCATION = CheckPoint(id: UUID(), name: "Tree Farm", longitude: -122.36519, latitude: 48.42076)
let BVS_LOCATION = CheckPoint(id: UUID(), name: "BVS Airport", longitude: -122.41299, latitude: 48.46915)
