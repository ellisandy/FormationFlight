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
    
    // MARK: - getTrueAirSpeed()
    func testGetTrueAirSpeedWithTenKnotHeadWind() {
        let winds = Winds(velocity: 50, direction: 0)
        let location = CLLocation(coordinate: HOME_LOCATION.getCLCoordinate(),
                                  altitude: 0,
                                  horizontalAccuracy: 0,
                                  verticalAccuracy: 0,
                                  course: 0,
                                  courseAccuracy: 0,
                                  speed: 50.0,
                                  speedAccuracy: 0,
                                  timestamp: Date.now)
        
        XCTAssertEqual(location.getTrueAirSpeed(with: winds)!, 100.0, accuracy: 0.1)
    }
    
    func testGetTrueAirSpeedWithTenKnotTailWind() {
        let winds = Winds(velocity: 50, direction: 180)
        let location = CLLocation(coordinate: HOME_LOCATION.getCLCoordinate(),
                                  altitude: 0,
                                  horizontalAccuracy: 0,
                                  verticalAccuracy: 0,
                                  course: 0,
                                  courseAccuracy: 0,
                                  speed: 150.0,
                                  speedAccuracy: 0,
                                  timestamp: Date.now)
        
        XCTAssertEqual(location.getTrueAirSpeed(with: winds)!, 100.0, accuracy: 0.1)
    }
    
    func testGetTrueAirSpeedWithTenKnotDirectCrossWind() {
        let winds = Winds(velocity: 50, direction: 90)
        let location = CLLocation(coordinate: HOME_LOCATION.getCLCoordinate(),
                                  altitude: 0,
                                  horizontalAccuracy: 0,
                                  verticalAccuracy: 0,
                                  course: 0,
                                  courseAccuracy: 0,
                                  speed: 86.6,
                                  speedAccuracy: 0,
                                  timestamp: Date.now)
        
        XCTAssertEqual(location.getTrueAirSpeed(with: winds)!, 100.0, accuracy: 0.1)
    }
    
    func testGetTrueAirSpeedWithTenKnotQuarteringHeadind() {
        let winds = Winds(velocity: 50, direction: 60)
        let location = CLLocation(coordinate: HOME_LOCATION.getCLCoordinate(),
                                  altitude: 0,
                                  horizontalAccuracy: 0,
                                  verticalAccuracy: 0,
                                  course: 0,
                                  courseAccuracy: 0,
                                  speed: 65.1,
                                  speedAccuracy: 0,
                                  timestamp: Date.now)
        
        XCTAssertEqual(location.getTrueAirSpeed(with: winds)!, 100.0, accuracy: 0.1)
    }
    
    func testGetTrueAirSpeedWithTenKnotQuarteringTailWind() {
        let winds = Winds(velocity: 50, direction: 120)
        let location = CLLocation(coordinate: HOME_LOCATION.getCLCoordinate(),
                                  altitude: 0,
                                  horizontalAccuracy: 0,
                                  verticalAccuracy: 0,
                                  course: 0,
                                  courseAccuracy: 0,
                                  speed: 115.1,
                                  speedAccuracy: 0,
                                  timestamp: Date.now)
        
        XCTAssertEqual(location.getTrueAirSpeed(with: winds)!, 100.0, accuracy: 0.1)
    }
    
    // MARK: - testPerformanceExample()
    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            let winds = Winds(velocity: 10, direction: 180)
            let location = CLLocation(coordinate: HOME_LOCATION.getCLCoordinate(),
                                      altitude: 0,
                                      horizontalAccuracy: 0,
                                      verticalAccuracy: 0,
                                      course: 0,
                                      courseAccuracy: 0,
                                      speed: 110.0,
                                      speedAccuracy: 0,
                                      timestamp: Date.now)
            
            XCTAssertEqual(location.getTrueAirSpeed(with: winds)!, 100.0, accuracy: 0.1)
        }
    }
    
    // MARK: - getCourse()
    func testGetCourse_North() {
        let p1 = CLLocation(latitude: 0.0, longitude: 0.0)
        let p2 = CLLocation(latitude: 1.0, longitude: 0.0)
        
        XCTAssertEqual(p1.getCourse(to: p2), 0.0, accuracy: 0)
    }
    
    func testGetCourse_South() {
        let p1 = CLLocation(latitude: 0.0, longitude: 0.0)
        let p2 = CLLocation(latitude: 1.0, longitude: 0.0)
        
        XCTAssertEqual(p2.getCourse(to: p1), 180.0, accuracy: 0)
    }
    
    func testGetCourse_East() {
        let p1 = CLLocation(latitude: 0.0, longitude: 0.0)
        let p2 = CLLocation(latitude: 0.0, longitude: 1.0)
        
        XCTAssertEqual(p1.getCourse(to: p2), 90.0, accuracy: 0)
    }
    
    func testGetCourse_West() {
        let p1 = CLLocation(latitude: 0.0, longitude: 0.0)
        let p2 = CLLocation(latitude: 0.0, longitude: 1.0)
        
        XCTAssertEqual(p2.getCourse(to: p1), 270.0, accuracy: 0)
    }
    
    func testGetCourse_RealWorld_1() {
        let p1 = CLLocation(latitude: 48.42583, longitude: -122.37916)
        let p2 = CLLocation(latitude: 48.45335, longitude: -122.37849)
        
        XCTAssertEqual(p1.getCourse(to: p2), 0.0, accuracy: 1.0)
    }
    
    func testGetCourse_RealWorld_2() {
        let p1 = CLLocation(latitude: 48.42583, longitude: -122.37916)
        let p2 = CLLocation(latitude: 48.42570, longitude: -122.36455)
        
        XCTAssertEqual(p1.getCourse(to: p2), 90.0, accuracy: 1.0)
    }
    
    func testGetCourse_RealWorld_3() {
        let p1 = CLLocation(latitude: 48.42583, longitude: -122.37916)
        let p2 = CLLocation(latitude: 48.42570, longitude: -122.36455)
        
        XCTAssertEqual(p2.getCourse(to: p1), 270.0, accuracy: 1.0)
    }
    
    func testGetCourse_RealWorld_4() {
        let p1 = CLLocation(latitude: 48.42583, longitude: -122.37916)
        let p2 = CLLocation(latitude: 48.45335, longitude: -122.37849)
        
        XCTAssertEqual(p2.getCourse(to: p1), 180.0, accuracy: 1.0)
    }
    
    
    func testGetCourse_RealWorld_5() {
        let p1 = HOME_LOCATION.getCLLocation()
        let p2 = BVS_LOCATION.getCLLocation()
        
        XCTAssertEqual(p1.getCourse(to: p2), 333.0, accuracy: 1.0)
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
    
    // MARK: getTime()
    
    // No Winds
    func testGetTimeNoWind() throws {
        let winds = Winds(velocity: 0, direction: 0)
        let adjustedStartLocation = CLLocation(coordinate: START_LOCATION.coordinate, 
                                               altitude: 0,
                                               horizontalAccuracy: 0,
                                               verticalAccuracy: 0,
                                               course: 0,
                                               speed: DEFAULT_SPEED,
                                               timestamp: Date.now)
        let unwrappedTime = try XCTUnwrap(adjustedStartLocation.getTime(to: END_LOCATION, with: winds))
        
        XCTAssertEqual(unwrappedTime, EXPECTED_ETA, accuracy: 0.1)
    }
    
    // Head Winds assuming bearing of due east
    func testGetTime_100Meters_HeadWind() throws {
        let winds = Winds(velocity: 50, direction: 90)
        let adjustedETA = EXPECTED_DISTANCE / 50
        let adjustedStartLocation = CLLocation(coordinate: START_LOCATION.coordinate,
                                               altitude: 0, 
                                               horizontalAccuracy: 0,
                                               verticalAccuracy: 0, 
                                               course: 0,
                                               speed: 86.60254037844386,
                                               timestamp: Date.now)
        let unwrappedTime = try XCTUnwrap(adjustedStartLocation.getTime(to: END_LOCATION, with: winds))
        
        XCTAssertEqual(unwrappedTime, adjustedETA, accuracy: 0.1)
    }
    
    // Tail Winds assuming bearing of due east
    func testGetTime_100Meters_TailWind() throws {
        let winds = Winds(velocity: 50, direction: 270)
        let adjustedETA = EXPECTED_DISTANCE / (DEFAULT_SPEED + 50)
        let adjustedStartLocation = CLLocation(coordinate: START_LOCATION.coordinate, 
                                               altitude: 0,
                                               horizontalAccuracy: 0,
                                               verticalAccuracy: 0,
                                               course: 0,
                                               speed: 86.60254037844386,
                                               timestamp: Date.now)
        let unwrappedTime = try XCTUnwrap(adjustedStartLocation.getTime(to: END_LOCATION, with: winds))
        
        XCTAssertEqual(unwrappedTime, adjustedETA, accuracy: 0.1)
    }
    
    // Direct Cross Wind assuming bearing of due east
    func testGetTime_100Meters_DirectCrossWind() throws {
        let winds = Winds(velocity: 50, direction: 180)
        let adjustedETA = 60000 / 86.6  // estimated Ground Speed
        let adjustedStartLocation = CLLocation(coordinate: START_LOCATION.coordinate,
                                               altitude: 0,
                                               horizontalAccuracy: 0,
                                               verticalAccuracy: 0,
                                               course: 0,
                                               speed: DEFAULT_SPEED + 50,
                                               timestamp: Date.now)
        let unwrappedTime = try XCTUnwrap(adjustedStartLocation.getTime(to: END_LOCATION, with: winds))
        
        XCTAssertEqual(unwrappedTime, adjustedETA, accuracy: 0.1)
    }
    
    // Quartering Tail Wind assuming bearing of due east
    func testGetTime_100Meters_QuarteringTailWind() throws {
        let winds = Winds(velocity: 50, direction: 210)
        let adjustedETA = EXPECTED_DISTANCE / 115.1421613913769
        let adjustedStartLocation = CLLocation(coordinate: START_LOCATION.coordinate,
                                               altitude: 0,
                                               horizontalAccuracy: 0,
                                               verticalAccuracy: 0,
                                               course: 0,
                                               speed: DEFAULT_SPEED + 40.129,
                                               timestamp: Date.now)
        let unwrappedTime = try XCTUnwrap(adjustedStartLocation.getTime(to: END_LOCATION, with: winds))
        
        XCTAssertEqual(unwrappedTime, adjustedETA, accuracy: 0.1)
    }
    
    // Quartering Head Wind assuming bearing of due east
    func testGetTime_100Meters_QuarteringHeadWind() throws {
        let winds = Winds(velocity: 50, direction: 150)
        let adjustedETA = EXPECTED_DISTANCE / (65.142161391376902)
        let adjustedStartLocation = CLLocation(coordinate: START_LOCATION.coordinate,
                                               altitude: 0,
                                               horizontalAccuracy: 0,
                                               verticalAccuracy: 0,
                                               course: 0,
                                               speed: DEFAULT_SPEED + 40.129,
                                               timestamp: Date.now)
        let unwrappedTime = try XCTUnwrap(adjustedStartLocation.getTime(to: END_LOCATION, with: winds))
        
        XCTAssertEqual(unwrappedTime, adjustedETA, accuracy: 0.1)
    }
    
    // Quartering Head Wind assuming bearing of due east
    func testGetTime_100Meters_NoSpeed() {
        let winds = Winds(velocity: 10, direction: 60)

        XCTAssertNil(START_LOCATION.getTime(to: END_LOCATION, with: winds))
    }
}
