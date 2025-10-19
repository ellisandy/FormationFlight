//
//  Flight_Test.swift
//  Formation FlightTests
//
//  Created by Jack Ellis on 12/31/23.
//

import XCTest
@testable import Formation_Flight
import CoreLocation

final class Flight_Test: XCTestCase {
    
    let startDate: Date = {
        return dateFromStringHelper(dateString: "01/01/2020 00:00:00")
    }()
    
    // End Date 10 Minutes Later
    let endDate: Date = {
        return dateFromStringHelper(dateString: "01/01/2020 00:10:00")
    }()
    
    // 100 Meters/Second
    let speed = 100.0
    
    // Bearing is 90 degrees
    let expectedBearing = 90.0
    
    // Distance is 60k Meters
    let expectedDistance = 60000.0
    
    let expectedTOT = 600.0
    
    // Known Distance of 60,000 meters apart
    let startLocation = CLLocation(latitude: 0.0, longitude: 0.0)
    let endLocation = CLLocation(latitude: 0.0, longitude: 0.53898917)
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    // FIXME: Test the DistanceToFinal
    func testProvideInstrumentPanelDataWithOnTrackSuccess() throws {
        let currentDate = Date.now
        let missionDate = currentDate.addingTimeInterval(expectedTOT)
        
        // Setup
        let sut = Flight.emptyFlight()
        sut.title = "XCT Test Flight"
        sut.expectedWinds = Winds(velocity: 0, direction: 0)
        sut.missionDate = missionDate
        sut.checkPoints = [CheckPoint(id: UUID(),
                                      name: "End Location",
                                      longitude: endLocation.coordinate.longitude,
                                      latitude: endLocation.coordinate.latitude)]
        
        let currentLoc = CLLocation(coordinate: startLocation.coordinate,
                                    altitude: 0,
                                    horizontalAccuracy: 0.1,
                                    verticalAccuracy: 0.1,
                                    course: 0,
                                    speed: speed,
                                    timestamp: startDate)
        
        let expectedPanelData = InstrumentPanelData(currentETA: Measurement(value: expectedTOT, unit: UnitDuration.seconds),
                                                    ETADelta: Measurement(value: 0.0, unit: UnitDuration.seconds),
                                                    course: Measurement(value: expectedBearing, unit: UnitAngle.degrees),
                                                    currentTrueAirSpeed: Measurement(value: speed, unit: UnitSpeed.metersPerSecond),
                                                    targetTrueAirSpeed: Measurement(value: speed, unit: UnitSpeed.metersPerSecond),
                                                    distanceToNext: Measurement(value: expectedDistance, unit: UnitLength.meters),
                                                    distanceToFinal: Measurement(value: 0.0, unit: UnitLength.meters))
        
        // Action
        let actualPanelData = sut.provideInstrumentPanelData(from: currentLoc)
        
        // Assert
        XCTAssertEqual(sut.title, "XCT Test Flight" ,"Title should not be empty")
        
        XCTAssertEqual(actualPanelData.currentETA!.value, expectedPanelData.currentETA!.value, accuracy: 0.1, "Time on Target is not within Range")
        XCTAssertEqual(actualPanelData.ETADelta!.value, expectedPanelData.ETADelta!.value, accuracy: 0.1, "Time on Target Drift is not within Range")
        XCTAssertEqual(actualPanelData.course!.value, expectedPanelData.course!.value, accuracy: 0.1, "Course is not within Range")
        XCTAssertEqual(actualPanelData.currentTrueAirspeed!.value, expectedPanelData.currentTrueAirspeed!.value, accuracy: 0.1, "Groundspeed  is not within Range")
        XCTAssertEqual(actualPanelData.targetTrueAirspeed!.value, expectedPanelData.targetTrueAirspeed!.value, accuracy: 0.1, "Target GroundSpeed is not within Range")
        XCTAssertEqual(actualPanelData.distanceToNext!.value, expectedPanelData.distanceToNext!.value, accuracy: 0.1, "Distance to next is not within Range")
    }

    func testProvideInstrumentPanelDataWithHalfSpeedSuccess() throws {
        let currentDate = Date.now
        let missionDate = currentDate.addingTimeInterval(expectedTOT)
        
        // Setup
        let sut = Flight.emptyFlight()
        sut.title = "XCT Test Flight"
        sut.expectedWinds = Winds(velocity: 0, direction: 0)
        sut.missionDate = missionDate
        sut.checkPoints = [CheckPoint(id: UUID(),
                                      name: "End Location",
                                      longitude: endLocation.coordinate.longitude,
                                      latitude: endLocation.coordinate.latitude)]
        
        let currentLoc = CLLocation(coordinate: startLocation.coordinate,
                                    altitude: 0,
                                    horizontalAccuracy: 0.1,
                                    verticalAccuracy: 0.1,
                                    course: 0,
                                    speed: speed / 2,
                                    timestamp: startDate)
        
        // if I'm going half the speed, it will take twice as long
        let expectedPanelData = InstrumentPanelData(currentETA: Measurement(value: 600.0, unit: UnitDuration.seconds),
                                                    ETADelta: Measurement(value: 600.0, unit: UnitDuration.seconds),
                                                    course: Measurement(value: expectedBearing, unit: UnitAngle.degrees),
                                                    currentTrueAirSpeed: Measurement(value: speed / 2, unit: UnitSpeed.metersPerSecond),
                                                    targetTrueAirSpeed: Measurement(value: speed, unit: UnitSpeed.metersPerSecond),
                                                    distanceToNext: Measurement(value: expectedDistance, unit: UnitLength.meters),
                                                    distanceToFinal: Measurement(value: 0.0, unit: UnitLength.meters))
        
        // Action
        let actualPanelData = sut.provideInstrumentPanelData(from: currentLoc)
        
        // Assert
        XCTAssertEqual(sut.title, "XCT Test Flight" ,"Title should not be empty")
        
        XCTAssertEqual(actualPanelData.currentETA!.value, expectedPanelData.currentETA!.value, accuracy: 0.1, "Time on Target is not within Range")
        XCTAssertEqual(actualPanelData.ETADelta!.value, expectedPanelData.ETADelta!.value, accuracy: 0.1, "Time on Target Drift is not within Range")
        XCTAssertEqual(actualPanelData.course!.value, expectedPanelData.course!.value, accuracy: 0.1, "Course is not within Range")
        XCTAssertEqual(actualPanelData.currentTrueAirspeed!.value, expectedPanelData.currentTrueAirspeed!.value, accuracy: 0.1, "Groundspeed  is not within Range")
        XCTAssertEqual(actualPanelData.targetTrueAirspeed!.value, expectedPanelData.targetTrueAirspeed!.value, accuracy: 0.1, "Target GroundSpeed is not within Range")
        XCTAssertEqual(actualPanelData.distanceToNext!.value, expectedPanelData.distanceToNext!.value, accuracy: 0.1, "Distance to next is not within Range")
    }
    
    func testProvideInstrumentPanelDataWithDoubleSpeedSuccess() throws {
        let currentDate = Date.now
        let missionDate = currentDate.addingTimeInterval(expectedTOT)
        
        // Setup
        let sut = Flight.emptyFlight()
        sut.title = "XCT Test Flight"
        sut.expectedWinds = Winds(velocity: 0, direction: 0)
        sut.missionDate = missionDate
        sut.checkPoints = [CheckPoint(id: UUID(),
                                      name: "End Location",
                                      longitude: endLocation.coordinate.longitude,
                                      latitude: endLocation.coordinate.latitude)]
        
        let currentLoc = CLLocation(coordinate: startLocation.coordinate,
                                    altitude: 0,
                                    horizontalAccuracy: 0.1,
                                    verticalAccuracy: 0.1,
                                    course: 0,
                                    speed: speed * 2,
                                    timestamp: startDate)
        
        // if I'm going double the speed, it'll take half the time
        let expectedPanelData = InstrumentPanelData(currentETA: Measurement(value: 600.0, unit: UnitDuration.seconds),
                                                    ETADelta: Measurement(value: -300.0, unit: UnitDuration.seconds),
                                                    course: Measurement(value: expectedBearing, unit: UnitAngle.degrees),
                                                    currentTrueAirSpeed: Measurement(value: speed * 2, unit: UnitSpeed.metersPerSecond),
                                                    targetTrueAirSpeed: Measurement(value: speed, unit: UnitSpeed.metersPerSecond),
                                                    distanceToNext: Measurement(value: expectedDistance, unit: UnitLength.meters),
                                                    distanceToFinal: Measurement(value: 0.0, unit: UnitLength.meters))
        
        // Action
        let actualPanelData = sut.provideInstrumentPanelData(from: currentLoc)
        
        // Assert
        XCTAssertEqual(sut.title, "XCT Test Flight" ,"Title should not be empty")
        
        XCTAssertEqual(actualPanelData.currentETA!.value, expectedPanelData.currentETA!.value, accuracy: 0.1, "Time on Target is not within Range")
        XCTAssertEqual(actualPanelData.ETADelta!.value, expectedPanelData.ETADelta!.value, accuracy: 0.1, "Time on Target Drift is not within Range")
        XCTAssertEqual(actualPanelData.course!.value, expectedPanelData.course!.value, accuracy: 0.1, "Course is not within Range")
        XCTAssertEqual(actualPanelData.currentTrueAirspeed!.value, expectedPanelData.currentTrueAirspeed!.value, accuracy: 0.1, "Groundspeed  is not within Range")
        XCTAssertEqual(actualPanelData.targetTrueAirspeed!.value, expectedPanelData.targetTrueAirspeed!.value, accuracy: 0.1, "Target GroundSpeed is not within Range")
        XCTAssertEqual(actualPanelData.distanceToNext!.value, expectedPanelData.distanceToNext!.value, accuracy: 0.1, "Distance to next is not within Range")
    }

    func testProvideInstrumentPanelDataWithFiftyKnotHeadWindSuccess() throws {
        let currentDate = Date.now
        let missionDate = currentDate.addingTimeInterval(expectedTOT)
        
        // Setup
        let sut = Flight.emptyFlight()
        sut.title = "XCT Test Flight"
        
        let windVelocity = 50.0
        let windDirection = 90.0
        
        // Fifty Knot Head Wind (from the bearing)
        sut.expectedWinds = Winds(velocity: windVelocity, direction: windDirection, velocityUnit: .metersPerSecond)
        sut.missionDate = missionDate
        sut.checkPoints = [CheckPoint(id: UUID(),
                                      name: "End Location",
                                      longitude: endLocation.coordinate.longitude,
                                      latitude: endLocation.coordinate.latitude)]
        
        let currentLoc = CLLocation(coordinate: startLocation.coordinate,
                                    altitude: 0,
                                    horizontalAccuracy: 0.1,
                                    verticalAccuracy: 0.1,
                                    course: 0,
                                    speed: 86.60254037844386,
                                    timestamp: startDate)
        
        // if I have a fifty knot head wind
        let expectedPanelData = InstrumentPanelData(currentETA: Measurement(value: 600.0, unit: UnitDuration.seconds),
                                                    ETADelta: Measurement(value: 600.0, unit: UnitDuration.seconds),
                                                    course: Measurement(value: expectedBearing, unit: UnitAngle.degrees),
                                                    currentTrueAirSpeed: Measurement(value: speed, unit: UnitSpeed.metersPerSecond),
                                                    targetTrueAirSpeed: Measurement(value: 150.0, unit: UnitSpeed.metersPerSecond),
                                                    distanceToNext: Measurement(value: expectedDistance, unit: UnitLength.meters),
                                                    distanceToFinal: Measurement(value: 0.0, unit: UnitLength.meters))
        
        // Action
        let actualPanelData = sut.provideInstrumentPanelData(from: currentLoc)
        
        // Assert
        XCTAssertEqual(sut.title, "XCT Test Flight" ,"Title should not be empty")
        
        XCTAssertEqual(actualPanelData.currentETA!.value, expectedPanelData.currentETA!.value, accuracy: 0.1, "Time on Target is not within Range")
        XCTAssertEqual(actualPanelData.ETADelta!.value, expectedPanelData.ETADelta!.value, accuracy: 0.1, "Time on Target Drift is not within Range")
        XCTAssertEqual(actualPanelData.course!.value, expectedPanelData.course!.value, accuracy: 0.1, "Course is not within Range")
        XCTAssertEqual(actualPanelData.currentTrueAirspeed!.value, expectedPanelData.currentTrueAirspeed!.value, accuracy: 0.1, "Groundspeed  is not within Range")
        XCTAssertEqual(actualPanelData.targetTrueAirspeed!.value, expectedPanelData.targetTrueAirspeed!.value, accuracy: 0.1, "Target GroundSpeed is not within Range")
        XCTAssertEqual(actualPanelData.distanceToNext!.value, expectedPanelData.distanceToNext!.value, accuracy: 0.1, "Distance to next is not within Range")
    }
    
    func testProvideInstrumentPanelDataWithFiftyKnotTailWindSuccess() throws {
        let currentDate = Date.now
        let missionDate = currentDate.addingTimeInterval(expectedTOT)
        
        // Setup
        let sut = Flight.emptyFlight()
        sut.title = "XCT Test Flight"
        
        let windVelocity = 50.0
        let windDirection = 270.0
        
        // Fifty Knot Head Wind (from the bearing)
        sut.expectedWinds = Winds(velocity: windVelocity, direction: windDirection, velocityUnit: .metersPerSecond)
        sut.missionDate = missionDate
        sut.checkPoints = [CheckPoint(id: UUID(),
                                      name: "End Location",
                                      longitude: endLocation.coordinate.longitude,
                                      latitude: endLocation.coordinate.latitude)]
        
        let currentLoc = CLLocation(coordinate: startLocation.coordinate,
                                    altitude: 0,
                                    horizontalAccuracy: 0.1,
                                    verticalAccuracy: 0.1,
                                    course: 0,
                                    speed: 86.60254037844386,
                                    timestamp: startDate)
        
        // if I have a fifty knot head wind
        let expectedPanelData = InstrumentPanelData(currentETA: Measurement(value: 600.0, unit: UnitDuration.seconds),
                                                    ETADelta: Measurement(value: -200.0, unit: UnitDuration.seconds),
                                                    course: Measurement(value: expectedBearing, unit: UnitAngle.degrees),
                                                    currentTrueAirSpeed: Measurement(value: speed, unit: UnitSpeed.metersPerSecond),
                                                    targetTrueAirSpeed: Measurement(value: 50.0, unit: UnitSpeed.metersPerSecond),
                                                    distanceToNext: Measurement(value: expectedDistance, unit: UnitLength.meters),
                                                    distanceToFinal: Measurement(value: 0.0, unit: UnitLength.meters))
        
        // Action
        let actualPanelData = sut.provideInstrumentPanelData(from: currentLoc)
        
        // Assert
        XCTAssertEqual(sut.title, "XCT Test Flight" ,"Title should not be empty")
        
        XCTAssertEqual(actualPanelData.currentETA!.value, expectedPanelData.currentETA!.value, accuracy: 0.1, "Time on Target is not within Range")
        XCTAssertEqual(actualPanelData.ETADelta!.value, expectedPanelData.ETADelta!.value, accuracy: 0.1, "Time on Target Drift is not within Range")
        XCTAssertEqual(actualPanelData.course!.value, expectedPanelData.course!.value, accuracy: 0.1, "Course is not within Range")
        XCTAssertEqual(actualPanelData.currentTrueAirspeed!.value, expectedPanelData.currentTrueAirspeed!.value, accuracy: 0.1, "Groundspeed  is not within Range")
        XCTAssertEqual(actualPanelData.targetTrueAirspeed!.value, expectedPanelData.targetTrueAirspeed!.value, accuracy: 0.1, "Target GroundSpeed is not within Range")
        XCTAssertEqual(actualPanelData.distanceToNext!.value, expectedPanelData.distanceToNext!.value, accuracy: 0.1, "Distance to next is not within Range")
    }
    
    func testProvideInstrumentPanelDataWithFiftyKnotQuarteringTailWindSuccess() throws {
        let currentDate = Date.now
        let missionDate = currentDate.addingTimeInterval(expectedTOT)
        
        // Setup
        let sut = Flight.emptyFlight()
        sut.title = "XCT Test Flight"
        
        let windVelocity = 50.0
        let windDirection = 210.0
        
        // Fifty Knot Head Wind (from the bearing)
        sut.expectedWinds = Winds(velocity: windVelocity, direction: windDirection, velocityUnit: .metersPerSecond)
        sut.missionDate = missionDate
        sut.checkPoints = [CheckPoint(id: UUID(),
                                      name: "End Location",
                                      longitude: endLocation.coordinate.longitude,
                                      latitude: endLocation.coordinate.latitude)]
        
        let currentLoc = CLLocation(coordinate: startLocation.coordinate,
                                    altitude: 0,
                                    horizontalAccuracy: 0.1,
                                    verticalAccuracy: 0.1,
                                    course: 0,
                                    speed: 140.126, // course of 0 degrees, wind at 210, so the read GS is 140~. When changing to 90 degrees, that should equal 115 GS
//                                    speed: 86.60254037844386,
                                    timestamp: startDate)
        
        // if I have a fifty knot head wind
        let expectedPanelData = InstrumentPanelData(currentETA: Measurement(value: 600.0, unit: UnitDuration.seconds),
                                                    ETADelta: Measurement(value: -78.8904559167, unit: UnitDuration.seconds),
                                                    course: Measurement(value: 116, unit: UnitAngle.degrees),
                                                    currentTrueAirSpeed: Measurement(value: speed, unit: UnitSpeed.metersPerSecond),
                                                    targetTrueAirSpeed: Measurement(value: 84.8612343929191, unit: UnitSpeed.metersPerSecond), // FIXME: Probably Wrong... Something is weird in the math
                                                    distanceToNext: Measurement(value: expectedDistance, unit: UnitLength.meters),
                                                    distanceToFinal: Measurement(value: 0.0, unit: UnitLength.meters))
        
        // Action
        let actualPanelData = sut.provideInstrumentPanelData(from: currentLoc)
        
        // Assert
        XCTAssertEqual(sut.title, "XCT Test Flight" ,"Title should not be empty")
        
        XCTAssertEqual(actualPanelData.currentETA!.value, expectedPanelData.currentETA!.value, accuracy: 0.1, "Time on Target is not within Range")
        XCTAssertEqual(actualPanelData.ETADelta!.value, expectedPanelData.ETADelta!.value, accuracy: 0.1, "Time on Target Drift is not within Range")
        XCTAssertEqual(actualPanelData.course!.value, expectedPanelData.course!.value, accuracy: 0.5, "Course is not within Range")
        XCTAssertEqual(actualPanelData.currentTrueAirspeed!.value, expectedPanelData.currentTrueAirspeed!.value, accuracy: 0.1, "Groundspeed  is not within Range")
        XCTAssertEqual(actualPanelData.targetTrueAirspeed!.value, expectedPanelData.targetTrueAirspeed!.value, accuracy: 0.1, "Target GroundSpeed is not within Range")
        XCTAssertEqual(actualPanelData.distanceToNext!.value, expectedPanelData.distanceToNext!.value, accuracy: 0.1, "Distance to next is not within Range")
    }
    
    func testProvideInstrumentPanelDataWithFiftyKnotQuarteringHeadWindSuccess() throws {
        let currentDate = Date.now
        let missionDate = currentDate.addingTimeInterval(expectedTOT)
        
        // Setup
        let sut = Flight.emptyFlight()
        sut.title = "XCT Test Flight"
        
        let windVelocity = 50.0
        let windDirection = 150.0
        
        sut.expectedWinds = Winds(velocity: windVelocity, direction: windDirection, velocityUnit: .metersPerSecond)
        sut.missionDate = missionDate
        sut.checkPoints = [CheckPoint(id: UUID(),
                                      name: "End Location",
                                      longitude: endLocation.coordinate.longitude,
                                      latitude: endLocation.coordinate.latitude)]
        
        let currentLoc = CLLocation(coordinate: startLocation.coordinate,
                                    altitude: 0,
                                    horizontalAccuracy: 0.1,
                                    verticalAccuracy: 0.1,
                                    course: 0,
                                    speed: 140.126, // course of 0 degrees, wind at 150, so the read GS is 140~. When changing to 90 degrees, that should equal 65.1 GS with a heading of 116
                                    timestamp: startDate)
        
        // if I have a fifty knot head wind
        let expectedPanelData = InstrumentPanelData(currentETA: Measurement(value: 600.0, unit: UnitDuration.seconds),
                                                    ETADelta: Measurement(value: 321.1080342493, unit: UnitDuration.seconds),
                                                    course: Measurement(value: 116, unit: UnitAngle.degrees),
                                                    currentTrueAirSpeed: Measurement(value: speed, unit: UnitSpeed.metersPerSecond),
                                                    targetTrueAirSpeed: Measurement(value: 134.85, unit: UnitSpeed.metersPerSecond),
                                                    distanceToNext: Measurement(value: expectedDistance, unit: UnitLength.meters),
                                                    distanceToFinal: Measurement(value: 0.0, unit: UnitLength.meters))
        
        // Action
        let actualPanelData = sut.provideInstrumentPanelData(from: currentLoc)
        
        // Assert
        XCTAssertEqual(sut.title, "XCT Test Flight" ,"Title should not be empty")
        
        XCTAssertEqual(actualPanelData.currentETA!.value, expectedPanelData.currentETA!.value, accuracy: 0.1, "Time on Target is not within Range")
        XCTAssertEqual(actualPanelData.ETADelta!.value, expectedPanelData.ETADelta!.value, accuracy: 0.1, "Time on Target Drift is not within Range")
        XCTAssertEqual(actualPanelData.course!.value, expectedPanelData.course!.value, accuracy: 0.5, "Course is not within Range")
        XCTAssertEqual(actualPanelData.currentTrueAirspeed!.value, expectedPanelData.currentTrueAirspeed!.value, accuracy: 0.1, "Groundspeed  is not within Range")
        XCTAssertEqual(actualPanelData.targetTrueAirspeed!.value, expectedPanelData.targetTrueAirspeed!.value, accuracy: 0.1, "Target GroundSpeed is not within Range")
        XCTAssertEqual(actualPanelData.distanceToNext!.value, expectedPanelData.distanceToNext!.value, accuracy: 0.1, "Distance to next is not within Range")
    }

    // MARK: - WindComponents
    func testWindWindComponentsHeadWind() {
        let bearing = 0.0
        
        // Wind from the north
        let sut = Winds(velocity: 10, direction: 0.0, velocityUnit: .metersPerSecond)
        
        XCTAssertEqual(sut.windComponents(given: bearing).windEffectiveVelocity, -10.0, accuracy: 0.001)
    }

    func testWindWindComponentsTailWind() {
        let bearing = 0.0
        
        // Wind from the north
        let sut = Winds(velocity: 10, direction: 180.0, velocityUnit: .metersPerSecond)
        
        XCTAssertEqual(sut.windComponents(given: bearing).windEffectiveVelocity, 10.0, accuracy: 0.001)
    }
    
    func testWindWindComponentsQuarteringTailWindWind() {
        let bearing = 0.0
        
        // Wind from the north
        let sut = Winds(velocity: 10, direction: 120, velocityUnit: .metersPerSecond)
        
        XCTAssertEqual(sut.windComponents(given: bearing).windEffectiveVelocity, 5.0, accuracy: 0.001)
    }

    func testWindWindComponentsQuarteringHeadWindWind() {
        let bearing = 0.0
        
        // Wind from the north
        let sut = Winds(velocity: 10, direction: 60.0, velocityUnit: .metersPerSecond)
        
        XCTAssertEqual(sut.windComponents(given: bearing).windEffectiveVelocity, -5.0, accuracy: 0.001)
    }
    
    func testWindWindComponentsDirectCrossWindWind() {
        let bearing = 0.0
        
        // Wind from the north
        let sut = Winds(velocity: 10, direction: 90.0, velocityUnit: .metersPerSecond)
        
        XCTAssertEqual(sut.windComponents(given: bearing).windEffectiveVelocity, 0.0, accuracy: 0.001)
    }
    
    func testSecondsUntilNoTime() {
        let actualDiff = startDate.secondsUntil(time: startDate)
        let expectedDiff = 0.0
        
        XCTAssertEqual(actualDiff, expectedDiff, accuracy: 0.001)
    }
    
    func testSecondsUntilMinusTen() {
        let actualDiff = endDate.secondsUntil(time: startDate)
        let expectedDiff = -600.0
        
        XCTAssertEqual(actualDiff, expectedDiff, accuracy: 0.001)
    }
    
    func testSecondsUntilPlusTen() {
        let actualDiff = startDate.secondsUntil(time: endDate)
        let expectedDiff = 600.0
        
        XCTAssertEqual(actualDiff, expectedDiff, accuracy: 0.001)
    }
    
    func testFind60kMetersAway() {
        let distance: Double = startLocation.distance(from: endLocation)
        
        XCTAssertEqual(distance, expectedDistance, accuracy: 0.001, "Not within 60,000 Meters")
    }
    
    func testFindBearingBetweenTwoPoints() {
        let bearing = startLocation.getCourse(to: endLocation).converted(to: .degrees).value
        
        XCTAssertEqual(bearing, expectedBearing, accuracy: 0.1, "Bearings do not equal 90 Degrees")
    }
    
    static func dateFromStringHelper(dateString: String) -> Date {
        let df = DateFormatter()
        df.dateFormat = "dd/MM/yyyy HH:mm:ss"
        
        // Purposefully Force Unwrapping to throw
        return df.date(from: dateString)!
    }
}
