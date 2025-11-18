//
//  CLLocation+Conversions_Test.swift
//  Formation FlightTests
//
//  Created by Jack Ellis on 12/31/23.
//

import XCTest
import CoreLocation
@testable import Formation_Flight

final class CLLocation_Conversions_Test: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    let HOME_LOCATION = Target(id: UUID(), longitude: -122.379581, latitude: 48.425643)
    let TREE_FARM_LOCATION = Target(id: UUID(), longitude: -122.36519, latitude: 48.42076)
    let BVS_LOCATION = Target(id: UUID(), longitude: -122.41299, latitude: 48.46915)

    // MARK: - getCourse()
    func testGetCourse_North() {
        let p1 = CLLocation(latitude: 0.0, longitude: 0.0)
        let p2 = CLLocation(latitude: 1.0, longitude: 0.0)
        
        XCTAssertEqual(p1.getBearing(to: p2)!.converted(to: .degrees).value, 0.0, accuracy: 0)
    }
    
    func testGetCourse_South() {
        let p1 = CLLocation(latitude: 0.0, longitude: 0.0)
        let p2 = CLLocation(latitude: 1.0, longitude: 0.0)
        
        XCTAssertEqual(p2.getBearing(to: p1)!.converted(to: .degrees).value, 180.0, accuracy: 0)
    }
    
    func testGetCourse_East() {
        let p1 = CLLocation(latitude: 0.0, longitude: 0.0)
        let p2 = CLLocation(latitude: 0.0, longitude: 1.0)
        
        XCTAssertEqual(p1.getBearing(to: p2), Measurement<UnitAngle>(value: 90.0, unit: UnitAngle.degrees))
    }
    
    func testGetCourse_West() {
        let p1 = CLLocation(latitude: 0.0, longitude: 0.0)
        let p2 = CLLocation(latitude: 0.0, longitude: 1.0)
        
        XCTAssertEqual(p2.getBearing(to: p1)!.converted(to: .degrees).value, 270.0, accuracy: 0)
    }
    
    func testGetCourse_RealWorld_1() {
        let p1 = CLLocation(latitude: 48.42583, longitude: -122.37916)
        let p2 = CLLocation(latitude: 48.45335, longitude: -122.37849)
        
        XCTAssertEqual(p1.getBearing(to: p2)!.converted(to: .degrees).value, 0.0, accuracy: 1.0)
    }
    
    func testGetCourse_RealWorld_2() {
        let p1 = CLLocation(latitude: 48.42583, longitude: -122.37916)
        let p2 = CLLocation(latitude: 48.42570, longitude: -122.36455)
        
        XCTAssertEqual(p1.getBearing(to: p2)!.converted(to: .degrees).value, 90.0, accuracy: 1.0)
    }
    
    func testGetCourse_RealWorld_3() {
        let p1 = CLLocation(latitude: 48.42583, longitude: -122.37916)
        let p2 = CLLocation(latitude: 48.42570, longitude: -122.36455)
        
        XCTAssertEqual(p2.getBearing(to: p1)!.converted(to: .degrees).value, 270.0, accuracy: 1.0)
    }
    
    func testGetCourse_RealWorld_4() {
        let p1 = CLLocation(latitude: 48.42583, longitude: -122.37916)
        let p2 = CLLocation(latitude: 48.45335, longitude: -122.37849)
        
        XCTAssertEqual(p2.getBearing(to: p1)!.converted(to: .degrees).value, 180.0, accuracy: 1.0)
    }
    
    
    func testGetCourse_RealWorld_5() {
        let p1 = HOME_LOCATION.getCLLocation()
        let p2 = BVS_LOCATION.getCLLocation()
        
        XCTAssertEqual(p1.getBearing(to: p2)!.converted(to: .degrees).value, 333.0, accuracy: 1.0)
    }
    
    // 100 Meters/Second
    let DEFAULT_SPEED = 100.0
    
    // Bearing is 90 degrees
    let EXPECTED_HEADING = 90.0
    
    // Distance is 60k Meters
    let EXPECTED_DISTANCE = 60000.0
    
    // ETA estimated 10 Minutes
    let EXPECTED_ETA: Double = 600.0
    
    // Known Distance of 60,000 meters apart
    let START_LOCATION = CLLocation(latitude: 0.0, longitude: 0.0)
    let END_LOCATION = CLLocation(latitude: 0.0, longitude: 0.53898917)
    

    
    // MARK: Multiple Point Calculations
    let STARTING_POINT = CLLocation(latitude: 48.75097, longitude: -121.94117)
    let FIRST_CHECKPOINT = CLLocation(latitude: 48.75097, longitude: -121.125242) // 60_000 Meters away CONFIRM TO EAST
    let SECOND_CHECKPOINT = CLLocation(latitude: 48.2114255, longitude: -121.125242) // 60_000 Meters away CONFIRM SOUTH
    let FINAL_CHECKPOINT = CLLocation(latitude: 48.2114255, longitude: -121.9325625) // 60_000 Meters away CONFIRM WEST
    let FINAL_CHECKPOINT_DOUBLE = CLLocation(latitude: 48.2114255, longitude: -122.739883) // 120_000 Meters away CONFIRM WEST
    
    func testDistanceStartToFirst() {
        let firstLeg = STARTING_POINT.distance(from: [FIRST_CHECKPOINT])!
        let secondLeg = FIRST_CHECKPOINT.distance(from: [SECOND_CHECKPOINT])!
        let thirdLeg = SECOND_CHECKPOINT.distance(from: [FINAL_CHECKPOINT])!
        let thirdLegLong = SECOND_CHECKPOINT.distance(from: [FINAL_CHECKPOINT_DOUBLE])!

        
        let firstLegCourse = STARTING_POINT.getBearing(to: FIRST_CHECKPOINT)
        let secondLegCourse = FIRST_CHECKPOINT.getBearing(to: SECOND_CHECKPOINT)
        let thirdLegCourse = SECOND_CHECKPOINT.getBearing(to: FINAL_CHECKPOINT)
        let thirdLegLongCourse = SECOND_CHECKPOINT.getBearing(to: FINAL_CHECKPOINT_DOUBLE)

        XCTAssertEqual(firstLeg, 60_000, accuracy: 0.01)
        XCTAssertEqual(secondLeg, 60_000, accuracy: 0.01)
        XCTAssertEqual(thirdLeg, 60_000, accuracy: 0.01)
        XCTAssertEqual(thirdLegLong, 120_000, accuracy: 0.01)

        
        XCTAssertEqual(firstLegCourse!.value, 90.0, accuracy: 0.5)
        XCTAssertEqual(secondLegCourse!.value, 180.0, accuracy: 0.5)
        XCTAssertEqual(thirdLegCourse!.value, 270.0, accuracy: 0.5)
        XCTAssertEqual(thirdLegLongCourse!.value, 270.0, accuracy: 1)
    }
    
    func testDistanceEmptyCheckpoints() {
        XCTAssertNil(STARTING_POINT.distance(from: []))
    }

    // MARK: - distance(from location: CLLocation?)
    func testDistanceFrom_NilReturnsNil() {
        let here = CLLocation(latitude: 37.3349, longitude: -122.0090)
        let result = here.distance(from: (nil as CLLocation?))
        XCTAssertNil(result)
    }

    func testDistanceFrom_SameCoordinateIsZero() throws {
        let here = CLLocation(latitude: 37.3349, longitude: -122.0090)
        let result = here.distance(from: here)
        XCTAssertEqual(result, 0.0, accuracy: 0.001)
    }

    func testDistanceFrom_KnownDistanceRoughlyMatches() throws {
        // Apple Park Visitor Center to Apple Park main building are close; expect a small non-zero distance.
        let p1 = CLLocation(latitude: 37.3349, longitude: -122.0090)
        let p2 = CLLocation(latitude: 37.3346, longitude: -122.0090)
        let result: Measurement<UnitLength>? = p1.distance(from: p2)
        // Rough expected distance between these latitudes (~33 meters). Allow generous tolerance for geodesic differences.
        XCTAssertEqual(result!.value, 33.0, accuracy: 10.0)
    }
}
