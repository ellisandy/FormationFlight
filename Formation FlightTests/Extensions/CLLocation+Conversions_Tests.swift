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
        let winds = Winds(velocity: 50, direction: 0, velocityUnit: .metersPerSecond)
        let location = CLLocation(coordinate: HOME_LOCATION.getCLCoordinate(),
                                  altitude: 0,
                                  horizontalAccuracy: 0,
                                  verticalAccuracy: 0,
                                  course: 0,
                                  courseAccuracy: 0,
                                  speed: 50.0,
                                  speedAccuracy: 0,
                                  timestamp: Date.now)
        
        XCTAssertEqual(location.getTrueAirSpeed(with: winds)!.value, 100.0, accuracy: 0.1)
    }
    
    func testGetTrueAirSpeedWithTenKnotTailWind() {
        let winds = Winds(velocity: 50, direction: 180, velocityUnit: .metersPerSecond)
        let location = CLLocation(coordinate: HOME_LOCATION.getCLCoordinate(),
                                  altitude: 0,
                                  horizontalAccuracy: 0,
                                  verticalAccuracy: 0,
                                  course: 0,
                                  courseAccuracy: 0,
                                  speed: 150.0,
                                  speedAccuracy: 0,
                                  timestamp: Date.now)
        
        XCTAssertEqual(location.getTrueAirSpeed(with: winds)!.value, 100.0, accuracy: 0.1)
    }
    
    func testGetTrueAirSpeedWithTenKnotDirectCrossWind() {
        let winds = Winds(velocity: 50, direction: 90, velocityUnit: .metersPerSecond)
        let location = CLLocation(coordinate: HOME_LOCATION.getCLCoordinate(),
                                  altitude: 0,
                                  horizontalAccuracy: 0,
                                  verticalAccuracy: 0,
                                  course: 0,
                                  courseAccuracy: 0,
                                  speed: 86.6,
                                  speedAccuracy: 0,
                                  timestamp: Date.now)
        
        XCTAssertEqual(location.getTrueAirSpeed(with: winds)!.value, 100.0, accuracy: 0.1)
    }
    
    func testGetTrueAirSpeedWithTenKnotQuarteringHeadind() {
        let winds = Winds(velocity: 50, direction: 60, velocityUnit: .metersPerSecond)
        let location = CLLocation(coordinate: HOME_LOCATION.getCLCoordinate(),
                                  altitude: 0,
                                  horizontalAccuracy: 0,
                                  verticalAccuracy: 0,
                                  course: 0,
                                  courseAccuracy: 0,
                                  speed: 65.1,
                                  speedAccuracy: 0,
                                  timestamp: Date.now)
        
        XCTAssertEqual(location.getTrueAirSpeed(with: winds)!.value, 100.0, accuracy: 0.1)
    }
    
    func testGetTrueAirSpeedWithTenKnotQuarteringTailWind() {
        let winds = Winds(velocity: 50, direction: 120, velocityUnit: .metersPerSecond)
        let location = CLLocation(coordinate: HOME_LOCATION.getCLCoordinate(),
                                  altitude: 0,
                                  horizontalAccuracy: 0,
                                  verticalAccuracy: 0,
                                  course: 0,
                                  courseAccuracy: 0,
                                  speed: 115.1,
                                  speedAccuracy: 0,
                                  timestamp: Date.now)
        
        XCTAssertEqual(location.getTrueAirSpeed(with: winds)!.value, 100.0, accuracy: 0.1)
    }
    
    // MARK: - testPerformanceExample()
    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            let winds = Winds(velocity: 10, direction: 180, velocityUnit: .metersPerSecond)
            let location = CLLocation(coordinate: HOME_LOCATION.getCLCoordinate(),
                                      altitude: 0,
                                      horizontalAccuracy: 0,
                                      verticalAccuracy: 0,
                                      course: 0,
                                      courseAccuracy: 0,
                                      speed: 110.0,
                                      speedAccuracy: 0,
                                      timestamp: Date.now)
            
            XCTAssertEqual(location.getTrueAirSpeed(with: winds)!.value, 100.0, accuracy: 0.1)
        }
    }
    
    // MARK: - getCourse()
    func testGetCourse_North() {
        let p1 = CLLocation(latitude: 0.0, longitude: 0.0)
        let p2 = CLLocation(latitude: 1.0, longitude: 0.0)
        
        XCTAssertEqual(p1.getCourse(to: p2).converted(to: .degrees).value, 0.0, accuracy: 0)
    }
    
    func testGetCourse_South() {
        let p1 = CLLocation(latitude: 0.0, longitude: 0.0)
        let p2 = CLLocation(latitude: 1.0, longitude: 0.0)
        
        XCTAssertEqual(p2.getCourse(to: p1).converted(to: .degrees).value, 180.0, accuracy: 0)
    }
    
    func testGetCourse_East() {
        let p1 = CLLocation(latitude: 0.0, longitude: 0.0)
        let p2 = CLLocation(latitude: 0.0, longitude: 1.0)
        
        XCTAssertEqual(p1.getCourse(to: p2), Measurement<UnitAngle>(value: 90.0, unit: UnitAngle.degrees))
    }
    
    func testGetCourse_West() {
        let p1 = CLLocation(latitude: 0.0, longitude: 0.0)
        let p2 = CLLocation(latitude: 0.0, longitude: 1.0)
        
        XCTAssertEqual(p2.getCourse(to: p1).converted(to: .degrees).value, 270.0, accuracy: 0)
    }
    
    func testGetCourse_RealWorld_1() {
        let p1 = CLLocation(latitude: 48.42583, longitude: -122.37916)
        let p2 = CLLocation(latitude: 48.45335, longitude: -122.37849)
        
        XCTAssertEqual(p1.getCourse(to: p2).converted(to: .degrees).value, 0.0, accuracy: 1.0)
    }
    
    func testGetCourse_RealWorld_2() {
        let p1 = CLLocation(latitude: 48.42583, longitude: -122.37916)
        let p2 = CLLocation(latitude: 48.42570, longitude: -122.36455)
        
        XCTAssertEqual(p1.getCourse(to: p2).converted(to: .degrees).value, 90.0, accuracy: 1.0)
    }
    
    func testGetCourse_RealWorld_3() {
        let p1 = CLLocation(latitude: 48.42583, longitude: -122.37916)
        let p2 = CLLocation(latitude: 48.42570, longitude: -122.36455)
        
        XCTAssertEqual(p2.getCourse(to: p1).converted(to: .degrees).value, 270.0, accuracy: 1.0)
    }
    
    func testGetCourse_RealWorld_4() {
        let p1 = CLLocation(latitude: 48.42583, longitude: -122.37916)
        let p2 = CLLocation(latitude: 48.45335, longitude: -122.37849)
        
        XCTAssertEqual(p2.getCourse(to: p1).converted(to: .degrees).value, 180.0, accuracy: 1.0)
    }
    
    
    func testGetCourse_RealWorld_5() {
        let p1 = HOME_LOCATION.getCLLocation()
        let p2 = BVS_LOCATION.getCLLocation()
        
        XCTAssertEqual(p1.getCourse(to: p2).converted(to: .degrees).value, 333.0, accuracy: 1.0)
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
        
        XCTAssertEqual(unwrappedTime.converted(to: .seconds).value, EXPECTED_ETA, accuracy: 0.1)
    }
    
    // Head Winds assuming bearing of due east
    func testGetTime_100Meters_HeadWind() throws {
        let winds = Winds(velocity: 50, direction: 90, velocityUnit: .metersPerSecond)
        let adjustedETA = EXPECTED_DISTANCE / 50
        let adjustedStartLocation = CLLocation(coordinate: START_LOCATION.coordinate,
                                               altitude: 0, 
                                               horizontalAccuracy: 0,
                                               verticalAccuracy: 0, 
                                               course: 0,
                                               speed: 86.60254037844386,
                                               timestamp: Date.now)
        let unwrappedTime = try XCTUnwrap(adjustedStartLocation.getTime(to: END_LOCATION, with: winds))
        
        XCTAssertEqual(unwrappedTime.converted(to: .seconds).value, adjustedETA, accuracy: 0.1)
    }
    
    // Tail Winds assuming bearing of due east
    func testGetTime_100Meters_TailWind() throws {
        let winds = Winds(velocity: 50, direction: 270, velocityUnit: .metersPerSecond)
        let adjustedETA = EXPECTED_DISTANCE / (DEFAULT_SPEED + 50)
        let adjustedStartLocation = CLLocation(coordinate: START_LOCATION.coordinate, 
                                               altitude: 0,
                                               horizontalAccuracy: 0,
                                               verticalAccuracy: 0,
                                               course: 0,
                                               speed: 86.60254037844386,
                                               timestamp: Date.now)
        let unwrappedTime = try XCTUnwrap(adjustedStartLocation.getTime(to: END_LOCATION, with: winds))
        
        XCTAssertEqual(unwrappedTime.converted(to: .seconds).value, adjustedETA, accuracy: 0.1)
    }
    
    // Direct Cross Wind assuming bearing of due east
    func testGetTime_100Meters_DirectCrossWind() throws {
        let winds = Winds(velocity: 50, direction: 180, velocityUnit: .metersPerSecond)
        let adjustedETA = 60000 / 86.6  // estimated Ground Speed
        let adjustedStartLocation = CLLocation(coordinate: START_LOCATION.coordinate,
                                               altitude: 0,
                                               horizontalAccuracy: 0,
                                               verticalAccuracy: 0,
                                               course: 0,
                                               speed: DEFAULT_SPEED + 50,
                                               timestamp: Date.now)
        let unwrappedTime = try XCTUnwrap(adjustedStartLocation.getTime(to: END_LOCATION, with: winds))
        
        XCTAssertEqual(unwrappedTime.converted(to: .seconds).value, adjustedETA, accuracy: 0.1)
    }
    
    // Quartering Tail Wind assuming bearing of due east
    func testGetTime_100Meters_QuarteringTailWind() throws {
        let winds = Winds(velocity: 50, direction: 210, velocityUnit: .metersPerSecond)
        let adjustedETA = EXPECTED_DISTANCE / 115.1421613913769
        let adjustedStartLocation = CLLocation(coordinate: START_LOCATION.coordinate,
                                               altitude: 0,
                                               horizontalAccuracy: 0,
                                               verticalAccuracy: 0,
                                               course: 0,
                                               speed: DEFAULT_SPEED + 40.129,
                                               timestamp: Date.now)
        let unwrappedTime = try XCTUnwrap(adjustedStartLocation.getTime(to: END_LOCATION, with: winds))
        
        XCTAssertEqual(unwrappedTime.converted(to: .seconds).value, adjustedETA, accuracy: 0.1)
    }
    
    // Quartering Head Wind assuming bearing of due east
    func testGetTime_100Meters_QuarteringHeadWind() throws {
        let winds = Winds(velocity: 50, direction: 150, velocityUnit: .metersPerSecond)
        let adjustedETA = EXPECTED_DISTANCE / (65.142161391376902)
        let adjustedStartLocation = CLLocation(coordinate: START_LOCATION.coordinate,
                                               altitude: 0,
                                               horizontalAccuracy: 0,
                                               verticalAccuracy: 0,
                                               course: 0,
                                               speed: DEFAULT_SPEED + 40.129,
                                               timestamp: Date.now)
        let unwrappedTime = try XCTUnwrap(adjustedStartLocation.getTime(to: END_LOCATION, with: winds))
        
        XCTAssertEqual(unwrappedTime.converted(to: .seconds).value, adjustedETA, accuracy: 0.1)
    }
    
    // Quartering Head Wind assuming bearing of due east
    func testGetTime_100Meters_NoSpeed() {
        let winds = Winds(velocity: 10, direction: 60, velocityUnit: .metersPerSecond)

        XCTAssertNil(START_LOCATION.getTime(to: END_LOCATION, with: winds))
    }
    
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

        
        let firstLegCourse = STARTING_POINT.getCourse(to: FIRST_CHECKPOINT)
        let secondLegCourse = FIRST_CHECKPOINT.getCourse(to: SECOND_CHECKPOINT)
        let thirdLegCourse = SECOND_CHECKPOINT.getCourse(to: FINAL_CHECKPOINT)
        let thirdLegLongCourse = SECOND_CHECKPOINT.getCourse(to: FINAL_CHECKPOINT_DOUBLE)

        XCTAssertEqual(firstLeg, 60_000, accuracy: 0.01)
        XCTAssertEqual(secondLeg, 60_000, accuracy: 0.01)
        XCTAssertEqual(thirdLeg, 60_000, accuracy: 0.01)
        XCTAssertEqual(thirdLegLong, 120_000, accuracy: 0.01)

        
        XCTAssertEqual(firstLegCourse.value, 90.0, accuracy: 0.5)
        XCTAssertEqual(secondLegCourse.value, 180.0, accuracy: 0.5)
        XCTAssertEqual(thirdLegCourse.value, 270.0, accuracy: 0.5)
        XCTAssertEqual(thirdLegLongCourse.value, 270.0, accuracy: 1)
    }
    
    func testGetTimeTripTenKnotNorth() {
        // WINDS from the north at 10 knots
        let expectedWinds = Winds(velocity: 10.0, direction: 0.0, velocityUnit: .metersPerSecond)
        let currentLocation = CLLocation(coordinate: STARTING_POINT.coordinate,
                                         altitude: 0,
                                         horizontalAccuracy: 0,
                                         verticalAccuracy: 0,
                                         course: 0,
                                         speed: 100.0 - 10.0, // starting with a ten knot headwind
                                         timestamp: Date.now)
        
        let secondLocation = CLLocation(coordinate: FIRST_CHECKPOINT.coordinate,
                                         altitude: 0,
                                         horizontalAccuracy: 0,
                                         verticalAccuracy: 0,
                                         course: 90,
                                         speed: 99.5, // starting with a ten knot crosswind
                                         timestamp: Date.now)
        
        
        var totalTime = 0.0
        
        // TAS is 100 knots // Starting GS 90kts
        XCTAssertEqual(currentLocation.getTrueAirSpeed(with: expectedWinds)!.value, 100.0, accuracy: 0.1)
        
        // first leg time == 603.01 (approximate GS 99.5 kts)
        XCTAssertEqual(currentLocation.getTime(to: [FIRST_CHECKPOINT], with: expectedWinds)!.value, 603.35, accuracy: 0.1)
        
        // second leg time == 545.4545454545 (approximate GS 110 kts)
        XCTAssertEqual(secondLocation.getTrueAirSpeed(with: expectedWinds)!.value, 100.0, accuracy: 0.1)
        XCTAssertEqual(secondLocation.getTime(to: [SECOND_CHECKPOINT], with: expectedWinds)!.value, 545.45, accuracy: 0.1)
        
        // final let time == 603.01 (approximate GS 99.5 kts)
        
        // total time =~ 1,751 seconds
        let expectedTime = 1752.1488727994
        
        totalTime = currentLocation.getTime(to: [FIRST_CHECKPOINT, SECOND_CHECKPOINT, FINAL_CHECKPOINT], with: expectedWinds)!.value
     
        XCTAssertEqual(totalTime, expectedTime, accuracy: 0.1)
    }
    
    func testGetTargetAirspeedTripTenKnotNorth() {
        // WINDS from the north at 10 knots
        let expectedWinds = Winds(velocity: 10.0, direction: 0.0, velocityUnit: .metersPerSecond)
        let currentLocation = CLLocation(coordinate: STARTING_POINT.coordinate,
                                         altitude: 0,
                                         horizontalAccuracy: 0,
                                         verticalAccuracy: 0,
                                         course: 0,
                                         speed: 100.0 - 10.0, // starting with a ten knot headwind
                                         timestamp: Date.now)
        
        let secondLocation = CLLocation(coordinate: FIRST_CHECKPOINT.coordinate,
                                         altitude: 0,
                                         horizontalAccuracy: 0,
                                         verticalAccuracy: 0,
                                         course: 90,
                                         speed: 99.5, // starting with a ten knot crosswind
                                         timestamp: Date.now)
        
        let thirdLocation = CLLocation(coordinate: SECOND_CHECKPOINT.coordinate,
                                       altitude: 0,
                                       horizontalAccuracy: 0,
                                       verticalAccuracy: 0,
                                       course: 180,
                                       speed: 110.0, // starting with a ten knot crosswind
                                       timestamp: Date.now)
        
        
        var targetAirspeed = Measurement(value: 0.0, unit: UnitSpeed.metersPerSecond)
        
        // TAS is 100 knots // Starting GS 90kts
        XCTAssertEqual(currentLocation.getTrueAirSpeed(with: expectedWinds)!.value, 100.0, accuracy: 0.1)
        
        // first leg time == 603.01 (approximate GS 99.5 kts)
        XCTAssertEqual(currentLocation.getTime(to: [FIRST_CHECKPOINT], with: expectedWinds)!.value, 603.35, accuracy: 0.1)
        
        // second leg time == 545.4545454545 (approximate GS 110 kts)
        XCTAssertEqual(secondLocation.getTrueAirSpeed(with: expectedWinds)!.value, 100.0, accuracy: 0.1)
        XCTAssertEqual(secondLocation.getTime(to: [SECOND_CHECKPOINT], with: expectedWinds)!.value, 545.45, accuracy: 0.1)
        
        // final let time == 603.01 (approximate GS 99.5 kts)
        XCTAssertEqual(thirdLocation.getTrueAirSpeed(with: expectedWinds)!.value, 100.0, accuracy: 0.1)
        XCTAssertEqual(thirdLocation.getTime(to: [FINAL_CHECKPOINT], with: expectedWinds)!.value, 603.35, accuracy: 0.1)

        // total time =~ 1,751 seconds
//        let expectedTime = 1752.1488727994
//        let timeDifference = 1800.0 - expectedTime
//        
        //TAS + (100*(1-((first, second, third)/1800)))
        //100+(100*(1-((603+545+603)/1800)))
        
        targetAirspeed = currentLocation.getTargetAirspeed(tot: Measurement(value: 1800.0, unit: .seconds),
                                                           destinations: [FIRST_CHECKPOINT, SECOND_CHECKPOINT, FINAL_CHECKPOINT],
                                                           winds: expectedWinds)!
        
        //Alright Lets do it again, but adjusting to 102.658 meters/sec
     
//        XCTAssertEqual(targetAirspeed.value, 100.0, accuracy: 0.1)
        
        let adjustedCurrentLocation = CLLocation(coordinate: STARTING_POINT.coordinate,
                                                 altitude: 0,
                                                 horizontalAccuracy: 0,
                                                 verticalAccuracy: 0,
                                                 course: 0,
                                                 speed: targetAirspeed.value - 10.0, // Subtracting the 10 knot headwind when starting
                                                 timestamp: Date.now)

        XCTAssertEqual(adjustedCurrentLocation.getTrueAirSpeed(with: expectedWinds)!.value, targetAirspeed.value, accuracy: 0.01)
        
        XCTAssertEqual(adjustedCurrentLocation.getTime(to: [FIRST_CHECKPOINT, SECOND_CHECKPOINT, FINAL_CHECKPOINT],
                                                       with: expectedWinds)!.value,
                       1800.0,
                       accuracy: 1.1)
    }
    
    func testGetTargetAirspeedTripTenKnotNorthLong() {
        // WINDS from the north at 10 knots
        let expectedWinds = Winds(velocity: 10.0, direction: 0.0, velocityUnit: .metersPerSecond)
        let currentLocation = CLLocation(coordinate: STARTING_POINT.coordinate,
                                         altitude: 0,
                                         horizontalAccuracy: 0,
                                         verticalAccuracy: 0,
                                         course: 0,
                                         speed: 100.0 - 10.0, // starting with a ten knot headwind
                                         timestamp: Date.now)
        
        let secondLocation = CLLocation(coordinate: FIRST_CHECKPOINT.coordinate,
                                         altitude: 0,
                                         horizontalAccuracy: 0,
                                         verticalAccuracy: 0,
                                         course: 90,
                                         speed: 99.5, // starting with a ten knot crosswind
                                         timestamp: Date.now)
        
        let thirdLocation = CLLocation(coordinate: SECOND_CHECKPOINT.coordinate,
                                       altitude: 0,
                                       horizontalAccuracy: 0,
                                       verticalAccuracy: 0,
                                       course: 180,
                                       speed: 110.0, // starting with a ten knot crosswind
                                       timestamp: Date.now)
        
        
        var targetAirspeed = Measurement(value: 0.0, unit: UnitSpeed.metersPerSecond)
        
        // TAS is 100 knots // Starting GS 90kts
        XCTAssertEqual(currentLocation.getTrueAirSpeed(with: expectedWinds)!.value, 100.0, accuracy: 0.1)
        
        // first leg time == 603.01 (approximate GS 99.5 kts)
        XCTAssertEqual(currentLocation.getTime(to: [FIRST_CHECKPOINT], with: expectedWinds)!.value, 603.35, accuracy: 0.1)
        
        // second leg time == 545.4545454545 (approximate GS 110 kts)
        XCTAssertEqual(secondLocation.getTrueAirSpeed(with: expectedWinds)!.value, 100.0, accuracy: 0.1)
        XCTAssertEqual(secondLocation.getTime(to: [SECOND_CHECKPOINT], with: expectedWinds)!.value, 545.45, accuracy: 0.1)
        
        // final let time == 603.01 (approximate GS 99.5 kts)
        XCTAssertEqual(thirdLocation.getTrueAirSpeed(with: expectedWinds)!.value, 100.0, accuracy: 0.1)
        XCTAssertEqual(thirdLocation.getTime(to: [FINAL_CHECKPOINT_DOUBLE], with: expectedWinds)!.value, 1207.32, accuracy: 0.1)

        // total time =~ 1,751 seconds
//        let expectedTime = 1752.1488727994
//        let timeDifference = 1800.0 - expectedTime
//
        //TAS + (100*(1-((first, second, third)/1800)))
        //100+(100*(1-((603+545+603)/1800)))
        
        targetAirspeed = currentLocation.getTargetAirspeed(tot: Measurement(value: 2400.0, unit: .seconds),
                                                           destinations: [FIRST_CHECKPOINT, SECOND_CHECKPOINT, FINAL_CHECKPOINT_DOUBLE],
                                                           winds: expectedWinds)!
        
        //Alright Lets do it again, but adjusting to 102.658 meters/sec
     
//        XCTAssertEqual(targetAirspeed.value, 100.0, accuracy: 0.1)
        
        let adjustedCurrentLocation = CLLocation(coordinate: STARTING_POINT.coordinate,
                                                 altitude: 0,
                                                 horizontalAccuracy: 0,
                                                 verticalAccuracy: 0,
                                                 course: 0,
                                                 speed: targetAirspeed.value - 10.0, // Subtracting the 10 knot headwind when starting
                                                 timestamp: Date.now)

        XCTAssertEqual(adjustedCurrentLocation.getTrueAirSpeed(with: expectedWinds)!.value, targetAirspeed.value, accuracy: 1.0)
        
        XCTAssertEqual(adjustedCurrentLocation.getTime(to: [FIRST_CHECKPOINT, SECOND_CHECKPOINT, FINAL_CHECKPOINT_DOUBLE],
                                                       with: expectedWinds)!.value,
                       2400.0,
                       accuracy: 1.0)
    }
}
