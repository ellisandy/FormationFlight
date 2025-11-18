//
//  TargetTests.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/17/23.
//

import Foundation
import MapKit
import Testing
@testable import Formation_Flight

@Suite("Target")
struct TargetTests {
    
    @Test
    func testInitialization() {
        let latitude = 37.7749
        let longitude = -122.4194
        let target = Target(longitude: longitude, latitude: latitude)
        
        #expect(target.latitude == latitude)
        #expect(target.longitude == longitude)
    }
    
    @Test
    func testCodableRoundTrip() throws {
        let fixedID = UUID(uuidString: "12345678-1234-5678-1234-567812345678")!
        let target = Target(id: fixedID, longitude: -75.0, latitude: 40.0)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(target)
        
        let decoder = JSONDecoder()
        let decodedTarget = try decoder.decode(Target.self, from: data)
        
        #expect(decodedTarget == target)
    }
    
    @Test
    func testHashableAndIdentifiable() {
        let fixedID = UUID(uuidString: "12345678-1234-5678-1234-567812345678")!
        let target1 = Target(id: fixedID, longitude: 10.0, latitude: 50.0)
        let target2 = Target(id: UUID(), longitude: 10.0, latitude: 50.0)
        
        #expect(target1 != target2)
        
        let set: Set<Target> = [target1, target2]
        #expect(set.count == 2)
        
        #expect(target1.id != target2.id)
    }
    
    @Test
    func testCLCoordinateConversion() {
        let latitude = 51.5074
        let longitude = -0.1278
        let target = Target(longitude: longitude, latitude: latitude)
        
        let coordinate = target.getCLCoordinate()
        
        #expect(coordinate.latitude == latitude)
        #expect(coordinate.longitude == longitude)
    }
    
    @Test
    func testCLLocationConversion() {
        let latitude = 48.8566
        let longitude = 2.3522
        let target = Target(longitude: longitude, latitude: latitude)
        
        let location = target.getCLLocation()
        
        #expect(location.coordinate.latitude == latitude)
        #expect(location.coordinate.longitude == longitude)
    }
}
