//
//  Flight_Test.swift
//  Formation FlightTests
//
//  Created by Jack Ellis on 12/31/23.
//

import XCTest
@testable import Formation_Flight
import CoreLocation
import SwiftUI

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
    }
    
    override func tearDownWithError() throws {
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
        sut.inflightCheckPoints = sut.checkPoints
        
        let currentLoc = CLLocation(coordinate: startLocation.coordinate,
                                    altitude: 0,
                                    horizontalAccuracy: 0.1,
                                    verticalAccuracy: 0.1,
                                    course: 0,
                                    speed: speed,
                                    timestamp: startDate)
        
        let expectedPanelData = InstrumentPanelData(currentETA: Measurement(value: expectedTOT, unit: UnitDuration.seconds),
                                                    ETADelta: Measurement(value: 0.0, unit: UnitDuration.seconds),
                                                    bearingNext: Measurement(value: expectedBearing, unit: UnitAngle.degrees),
                                                    currentTrueAirSpeed: Measurement(value: speed, unit: UnitSpeed.metersPerSecond),
                                                    targetTrueAirSpeed: Measurement(value: speed, unit: UnitSpeed.metersPerSecond),
                                                    distanceToNext: Measurement(value: expectedDistance, unit: UnitLength.meters),
                                                    distanceToFinal: Measurement(value: 0.0, unit: UnitLength.meters),
                                                    groundSpeed: Measurement(value: 10, unit: UnitSpeed.metersPerSecond),
                                                    bearingFinal: Measurement(value: 0, unit: UnitAngle.degrees),
                                                    expectedWindVelocity: sut.expectedWinds.velocity.value.metersPerSecondsMeasurement.erasedType,
                                                    expectedWindDirection: sut.expectedWinds.direction.erasedType
        )
        
        // Action
        let config = SettingsEditorConfig(speedUnit: .kts, distanceUnit: .nm, yellowTolerance: 5, redTolerance: 10, minSpeed: 100, maxSpeed: 160, proximityToNextPoint: 0.5)
        let actualPanelData = InstrumentPanelCalculator.makeData(currentLocation: currentLoc, flight: sut, config: config)
        
        // Assert
        XCTAssertEqual(sut.title, "XCT Test Flight" ,"Title should not be empty")
        
        let actualETA = try XCTUnwrap(actualPanelData.currentETA).value
        let expectedETA = try XCTUnwrap(expectedPanelData.currentETA).value
        XCTAssertEqual(actualETA, expectedETA, accuracy: 0.1, "Time on Target is not within Range")
        
        let actualDelta = try XCTUnwrap(actualPanelData.ETADelta).value
        let expectedDelta = try XCTUnwrap(expectedPanelData.ETADelta).value
        XCTAssertEqual(actualDelta, expectedDelta, accuracy: 0.1, "Time on Target Drift is not within Range")
        
        let actualBearingNext = try XCTUnwrap(actualPanelData.bearingNext).value
        let expectedBearingNext = try XCTUnwrap(expectedPanelData.bearingNext).value
        XCTAssertEqual(actualBearingNext, expectedBearingNext, accuracy: 0.1, "Course is not within Range")
        
        let actualTAS = try XCTUnwrap(actualPanelData.currentTrueAirspeed).value
        let expectedTAS = try XCTUnwrap(expectedPanelData.currentTrueAirspeed).value
        XCTAssertEqual(actualTAS, expectedTAS, accuracy: 0.1, "Groundspeed  is not within Range")
        
        let actualTargetTAS = try XCTUnwrap(actualPanelData.targetTrueAirspeed).value
        let expectedTargetTAS = try XCTUnwrap(expectedPanelData.targetTrueAirspeed).value
        XCTAssertEqual(actualTargetTAS, expectedTargetTAS, accuracy: 0.1, "Target GroundSpeed is not within Range")
        
        let actualDistNext = try XCTUnwrap(actualPanelData.distanceToNext).value
        let expectedDistNext = try XCTUnwrap(expectedPanelData.distanceToNext).value
        XCTAssertEqual(actualDistNext, expectedDistNext, accuracy: 0.1, "Distance to next is not within Range")
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
        sut.inflightCheckPoints = sut.checkPoints

        
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
                                                    bearingNext: Measurement(value: expectedBearing, unit: UnitAngle.degrees),
                                                    currentTrueAirSpeed: Measurement(value: speed / 2, unit: UnitSpeed.metersPerSecond),
                                                    targetTrueAirSpeed: Measurement(value: speed, unit: UnitSpeed.metersPerSecond),
                                                    distanceToNext: Measurement(value: expectedDistance, unit: UnitLength.meters),
                                                    distanceToFinal: Measurement(value: 0.0, unit: UnitLength.meters),
                                                    groundSpeed: Measurement(value: 10, unit: UnitSpeed.metersPerSecond),
                                                    bearingFinal: Measurement(value: 0, unit: UnitAngle.degrees),
                                                    expectedWindVelocity: sut.expectedWinds.velocity.value.metersPerSecondsMeasurement.erasedType,
                                                    expectedWindDirection: sut.expectedWinds.direction.erasedType
        )
        
        // Action
        let config = SettingsEditorConfig(speedUnit: .kts, distanceUnit: .nm, yellowTolerance: 5, redTolerance: 10, minSpeed: 100, maxSpeed: 160, proximityToNextPoint: 0.5)
        let actualPanelData = InstrumentPanelCalculator.makeData(currentLocation: currentLoc, flight: sut, config: config)
        
        // Assert
        XCTAssertEqual(sut.title, "XCT Test Flight" ,"Title should not be empty")
        
        let actualETA = try XCTUnwrap(actualPanelData.currentETA).value
        let expectedETA = try XCTUnwrap(expectedPanelData.currentETA).value
        XCTAssertEqual(actualETA, expectedETA, accuracy: 0.1, "Time on Target is not within Range")
        
        let actualDelta = try XCTUnwrap(actualPanelData.ETADelta).value
        let expectedDelta = try XCTUnwrap(expectedPanelData.ETADelta).value
        XCTAssertEqual(actualDelta, expectedDelta, accuracy: 0.1, "Time on Target Drift is not within Range")
        
        let actualBearingNext = try XCTUnwrap(actualPanelData.bearingNext).value
        let expectedBearingNext = try XCTUnwrap(expectedPanelData.bearingNext).value
        XCTAssertEqual(actualBearingNext, expectedBearingNext, accuracy: 0.1, "Course is not within Range")
        
        let actualTAS = try XCTUnwrap(actualPanelData.currentTrueAirspeed).value
        let expectedTAS = try XCTUnwrap(expectedPanelData.currentTrueAirspeed).value
        XCTAssertEqual(actualTAS, expectedTAS, accuracy: 0.1, "Groundspeed  is not within Range")
        
        let actualTargetTAS = try XCTUnwrap(actualPanelData.targetTrueAirspeed).value
        let expectedTargetTAS = try XCTUnwrap(expectedPanelData.targetTrueAirspeed).value
        XCTAssertEqual(actualTargetTAS, expectedTargetTAS, accuracy: 0.1, "Target GroundSpeed is not within Range")
        
        let actualDistNext = try XCTUnwrap(actualPanelData.distanceToNext).value
        let expectedDistNext = try XCTUnwrap(expectedPanelData.distanceToNext).value
        XCTAssertEqual(actualDistNext, expectedDistNext, accuracy: 0.1, "Distance to next is not within Range")
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
        sut.inflightCheckPoints = sut.checkPoints

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
                                                    bearingNext: Measurement(value: expectedBearing, unit: UnitAngle.degrees),
                                                    currentTrueAirSpeed: Measurement(value: speed * 2, unit: UnitSpeed.metersPerSecond),
                                                    targetTrueAirSpeed: Measurement(value: speed, unit: UnitSpeed.metersPerSecond),
                                                    distanceToNext: Measurement(value: expectedDistance, unit: UnitLength.meters),
                                                    distanceToFinal: Measurement(value: 0.0, unit: UnitLength.meters),
                                                    groundSpeed: Measurement(value: 10, unit: UnitSpeed.metersPerSecond),
                                                    bearingFinal: Measurement(value: 0, unit: UnitAngle.degrees),
                                                    expectedWindVelocity: sut.expectedWinds.velocity.value.metersPerSecondsMeasurement.erasedType,
                                                    expectedWindDirection: sut.expectedWinds.direction.erasedType)
        
        // Action
        let config = SettingsEditorConfig(speedUnit: .kts, distanceUnit: .nm, yellowTolerance: 5, redTolerance: 10, minSpeed: 100, maxSpeed: 160, proximityToNextPoint: 0.5)
        let actualPanelData = InstrumentPanelCalculator.makeData(currentLocation: currentLoc, flight: sut, config: config)
        
        // Assert
        XCTAssertEqual(sut.title, "XCT Test Flight" ,"Title should not be empty")
        
        let actualETA = try XCTUnwrap(actualPanelData.currentETA).value
        let expectedETA = try XCTUnwrap(expectedPanelData.currentETA).value
        XCTAssertEqual(actualETA, expectedETA, accuracy: 0.1, "Time on Target is not within Range")
        
        let actualDelta = try XCTUnwrap(actualPanelData.ETADelta).value
        let expectedDelta = try XCTUnwrap(expectedPanelData.ETADelta).value
        XCTAssertEqual(actualDelta, expectedDelta, accuracy: 0.1, "Time on Target Drift is not within Range")
        
        let actualBearingNext = try XCTUnwrap(actualPanelData.bearingNext).value
        let expectedBearingNext = try XCTUnwrap(expectedPanelData.bearingNext).value
        XCTAssertEqual(actualBearingNext, expectedBearingNext, accuracy: 0.1, "Course is not within Range")
        
        let actualTAS = try XCTUnwrap(actualPanelData.currentTrueAirspeed).value
        let expectedTAS = try XCTUnwrap(expectedPanelData.currentTrueAirspeed).value
        XCTAssertEqual(actualTAS, expectedTAS, accuracy: 0.1, "Groundspeed  is not within Range")
        
        let actualTargetTAS = try XCTUnwrap(actualPanelData.targetTrueAirspeed).value
        let expectedTargetTAS = try XCTUnwrap(expectedPanelData.targetTrueAirspeed).value
        XCTAssertEqual(actualTargetTAS, expectedTargetTAS, accuracy: 0.1, "Target GroundSpeed is not within Range")
        
        let actualDistNext = try XCTUnwrap(actualPanelData.distanceToNext).value
        let expectedDistNext = try XCTUnwrap(expectedPanelData.distanceToNext).value
        XCTAssertEqual(actualDistNext, expectedDistNext, accuracy: 0.1, "Distance to next is not within Range")
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
        sut.inflightCheckPoints = sut.checkPoints

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
                                                    bearingNext: Measurement(value: expectedBearing, unit: UnitAngle.degrees),
                                                    currentTrueAirSpeed: Measurement(value: speed, unit: UnitSpeed.metersPerSecond),
                                                    targetTrueAirSpeed: Measurement(value: 150.0, unit: UnitSpeed.metersPerSecond),
                                                    distanceToNext: Measurement(value: expectedDistance, unit: UnitLength.meters),
                                                    distanceToFinal: Measurement(value: 0.0, unit: UnitLength.meters),
                                                    groundSpeed: Measurement(value: 10, unit: UnitSpeed.metersPerSecond),
                                                    bearingFinal: Measurement(value: 0, unit: UnitAngle.degrees),
                                                    expectedWindVelocity: sut.expectedWinds.velocity.value.metersPerSecondsMeasurement.erasedType,
                                                    expectedWindDirection: sut.expectedWinds.direction.erasedType)
        
        // Action
        let config = SettingsEditorConfig(speedUnit: .kts, distanceUnit: .nm, yellowTolerance: 5, redTolerance: 10, minSpeed: 100, maxSpeed: 160, proximityToNextPoint: 0.5)
        let actualPanelData = InstrumentPanelCalculator.makeData(currentLocation: currentLoc, flight: sut, config: config)
        
        // Assert
        XCTAssertEqual(sut.title, "XCT Test Flight" ,"Title should not be empty")
        
        let actualETA = try XCTUnwrap(actualPanelData.currentETA).value
        let expectedETA = try XCTUnwrap(expectedPanelData.currentETA).value
        XCTAssertEqual(actualETA, expectedETA, accuracy: 0.1, "Time on Target is not within Range")
        
        let actualDelta = try XCTUnwrap(actualPanelData.ETADelta).value
        let expectedDelta = try XCTUnwrap(expectedPanelData.ETADelta).value
        XCTAssertEqual(actualDelta, expectedDelta, accuracy: 0.1, "Time on Target Drift is not within Range")
        
        let actualBearingNext = try XCTUnwrap(actualPanelData.bearingNext).value
        let expectedBearingNext = try XCTUnwrap(expectedPanelData.bearingNext).value
        XCTAssertEqual(actualBearingNext, expectedBearingNext, accuracy: 0.1, "Course is not within Range")
        
        let actualTAS = try XCTUnwrap(actualPanelData.currentTrueAirspeed).value
        let expectedTAS = try XCTUnwrap(expectedPanelData.currentTrueAirspeed).value
        XCTAssertEqual(actualTAS, expectedTAS, accuracy: 0.1, "Groundspeed  is not within Range")
        
        let actualTargetTAS = try XCTUnwrap(actualPanelData.targetTrueAirspeed).value
        let expectedTargetTAS = try XCTUnwrap(expectedPanelData.targetTrueAirspeed).value
        XCTAssertEqual(actualTargetTAS, expectedTargetTAS, accuracy: 0.1, "Target GroundSpeed is not within Range")
        
        let actualDistNext = try XCTUnwrap(actualPanelData.distanceToNext).value
        let expectedDistNext = try XCTUnwrap(expectedPanelData.distanceToNext).value
        XCTAssertEqual(actualDistNext, expectedDistNext, accuracy: 0.1, "Distance to next is not within Range")
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
        sut.inflightCheckPoints = sut.checkPoints

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
                                                    bearingNext: Measurement(value: expectedBearing, unit: UnitAngle.degrees),
                                                    currentTrueAirSpeed: Measurement(value: speed, unit: UnitSpeed.metersPerSecond),
                                                    targetTrueAirSpeed: Measurement(value: 50.0, unit: UnitSpeed.metersPerSecond),
                                                    distanceToNext: Measurement(value: expectedDistance, unit: UnitLength.meters),
                                                    distanceToFinal: Measurement(value: 0.0, unit: UnitLength.meters),
                                                    groundSpeed: Measurement(value: 10, unit: UnitSpeed.metersPerSecond),
                                                    bearingFinal: Measurement(value: 0, unit: UnitAngle.degrees),
                                                    expectedWindVelocity: sut.expectedWinds.velocity.value.metersPerSecondsMeasurement.erasedType,
                                                    expectedWindDirection: sut.expectedWinds.direction.erasedType)
        
        // Action
        let config = SettingsEditorConfig(speedUnit: .kts, distanceUnit: .nm, yellowTolerance: 5, redTolerance: 10, minSpeed: 100, maxSpeed: 160, proximityToNextPoint: 0.5)
        let actualPanelData = InstrumentPanelCalculator.makeData(currentLocation: currentLoc, flight: sut, config: config)
        
        // Assert
        XCTAssertEqual(sut.title, "XCT Test Flight" ,"Title should not be empty")
        
        let actualETA = try XCTUnwrap(actualPanelData.currentETA).value
        let expectedETA = try XCTUnwrap(expectedPanelData.currentETA).value
        XCTAssertEqual(actualETA, expectedETA, accuracy: 0.1, "Time on Target is not within Range")
        
        let actualDelta = try XCTUnwrap(actualPanelData.ETADelta).value
        let expectedDelta = try XCTUnwrap(expectedPanelData.ETADelta).value
        XCTAssertEqual(actualDelta, expectedDelta, accuracy: 0.1, "Time on Target Drift is not within Range")
        
        let actualBearingNext = try XCTUnwrap(actualPanelData.bearingNext).value
        let expectedBearingNext = try XCTUnwrap(expectedPanelData.bearingNext).value
        XCTAssertEqual(actualBearingNext, expectedBearingNext, accuracy: 0.1, "Course is not within Range")
        
        let actualTAS = try XCTUnwrap(actualPanelData.currentTrueAirspeed).value
        let expectedTAS = try XCTUnwrap(expectedPanelData.currentTrueAirspeed).value
        XCTAssertEqual(actualTAS, expectedTAS, accuracy: 0.1, "Groundspeed  is not within Range")
        
        let actualTargetTAS = try XCTUnwrap(actualPanelData.targetTrueAirspeed).value
        let expectedTargetTAS = try XCTUnwrap(expectedPanelData.targetTrueAirspeed).value
        XCTAssertEqual(actualTargetTAS, expectedTargetTAS, accuracy: 0.1, "Target GroundSpeed is not within Range")
        
        let actualDistNext = try XCTUnwrap(actualPanelData.distanceToNext).value
        let expectedDistNext = try XCTUnwrap(expectedPanelData.distanceToNext).value
        XCTAssertEqual(actualDistNext, expectedDistNext, accuracy: 0.1, "Distance to next is not within Range")
    }
    
    func testProvideInstrumentPanelDataWithFiftyKnotQuarteringTailWindSuccess() throws {
        let currentDate = Date.now
        let missionDate = currentDate.addingTimeInterval(expectedTOT)
        
        // Setup
        let sut = Flight.emptyFlight()
        sut.title = "XCT Test Flight"
        
        let windVelocity = 50.0
        let windDirection = 210.0
        
        sut.expectedWinds = Winds(velocity: windVelocity, direction: windDirection, velocityUnit: .metersPerSecond)
        sut.missionDate = missionDate
        sut.checkPoints = [CheckPoint(id: UUID(),
                                      name: "End Location",
                                      longitude: endLocation.coordinate.longitude,
                                      latitude: endLocation.coordinate.latitude)]
        sut.inflightCheckPoints = sut.checkPoints

        
        let currentLoc = CLLocation(coordinate: startLocation.coordinate,
                                    altitude: 0,
                                    horizontalAccuracy: 0.1,
                                    verticalAccuracy: 0.1,
                                    course: 0,
                                    speed: 140.126,
                                    timestamp: startDate)
        
        let expectedPanelData = InstrumentPanelData(currentETA: Measurement(value: 600.0, unit: UnitDuration.seconds),
                                                    ETADelta: Measurement(value: -78.8904559167, unit: UnitDuration.seconds),
                                                    bearingNext: Measurement(value: 90.0, unit: UnitAngle.degrees),
                                                    currentTrueAirSpeed: Measurement(value: speed, unit: UnitSpeed.metersPerSecond),
                                                    targetTrueAirSpeed: Measurement(value: 84.8612343929191, unit: UnitSpeed.metersPerSecond),
                                                    distanceToNext: Measurement(value: expectedDistance, unit: UnitLength.meters),
                                                    distanceToFinal: Measurement(value: 0.0, unit: UnitLength.meters),
                                                    groundSpeed: Measurement(value: 10, unit: UnitSpeed.metersPerSecond),
                                                    bearingFinal: Measurement(value: 0, unit: UnitAngle.degrees),
                                                    expectedWindVelocity: sut.expectedWinds.velocity.value.metersPerSecondsMeasurement.erasedType,
                                                    expectedWindDirection: sut.expectedWinds.direction.erasedType)
        
        // Action
        let config = SettingsEditorConfig(speedUnit: .kts, distanceUnit: .nm, yellowTolerance: 5, redTolerance: 10, minSpeed: 100, maxSpeed: 160, proximityToNextPoint: 0.5)
        let actualPanelData = InstrumentPanelCalculator.makeData(currentLocation: currentLoc, flight: sut, config: config)
        
        // Assert
        XCTAssertEqual(sut.title, "XCT Test Flight" ,"Title should not be empty")
        
        let actualETA = try XCTUnwrap(actualPanelData.currentETA).value
        let expectedETA = try XCTUnwrap(expectedPanelData.currentETA).value
        XCTAssertEqual(actualETA, expectedETA, accuracy: 0.1, "Time on Target is not within Range")
        
        let actualDelta = try XCTUnwrap(actualPanelData.ETADelta).value
        let expectedDelta = try XCTUnwrap(expectedPanelData.ETADelta).value
        XCTAssertEqual(actualDelta, expectedDelta, accuracy: 0.1, "Time on Target Drift is not within Range")
        
        let actualBearingNext = try XCTUnwrap(actualPanelData.bearingNext).value
        let expectedBearingNext = try XCTUnwrap(expectedPanelData.bearingNext).value
        XCTAssertEqual(actualBearingNext, expectedBearingNext, accuracy: 0.5, "Course is not within Range")
        
        let actualTAS = try XCTUnwrap(actualPanelData.currentTrueAirspeed).value
        let expectedTAS = try XCTUnwrap(expectedPanelData.currentTrueAirspeed).value
        XCTAssertEqual(actualTAS, expectedTAS, accuracy: 0.1, "Groundspeed  is not within Range")
        
        let actualTargetTAS = try XCTUnwrap(actualPanelData.targetTrueAirspeed).value
        let expectedTargetTAS = try XCTUnwrap(expectedPanelData.targetTrueAirspeed).value
        XCTAssertEqual(actualTargetTAS, expectedTargetTAS, accuracy: 0.1, "Target GroundSpeed is not within Range")
        
        let actualDistNext = try XCTUnwrap(actualPanelData.distanceToNext).value
        let expectedDistNext = try XCTUnwrap(expectedPanelData.distanceToNext).value
        XCTAssertEqual(actualDistNext, expectedDistNext, accuracy: 0.1, "Distance to next is not within Range")
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
        sut.inflightCheckPoints = sut.checkPoints

        let currentLoc = CLLocation(coordinate: startLocation.coordinate,
                                    altitude: 0,
                                    horizontalAccuracy: 0.1,
                                    verticalAccuracy: 0.1,
                                    course: 0,
                                    speed: 140.126,
                                    timestamp: startDate)
        
        let expectedPanelData = InstrumentPanelData(currentETA: Measurement(value: 600.0, unit: UnitDuration.seconds),
                                                    ETADelta: Measurement(value: 321.1080342493, unit: UnitDuration.seconds),
                                                    bearingNext: Measurement(value: 90.0, unit: UnitAngle.degrees),
                                                    currentTrueAirSpeed: Measurement(value: speed, unit: UnitSpeed.metersPerSecond),
                                                    targetTrueAirSpeed: Measurement(value: 134.85, unit: UnitSpeed.metersPerSecond),
                                                    distanceToNext: Measurement(value: expectedDistance, unit: UnitLength.meters),
                                                    distanceToFinal: Measurement(value: 0.0, unit: UnitLength.meters),
                                                    groundSpeed: Measurement(value: 10, unit: UnitSpeed.metersPerSecond),
                                                    bearingFinal: Measurement(value: 0, unit: UnitAngle.degrees),
                                                    expectedWindVelocity: sut.expectedWinds.velocity.value.metersPerSecondsMeasurement.erasedType,
                                                    expectedWindDirection: sut.expectedWinds.direction.erasedType)
        
        // Action
        let config = SettingsEditorConfig(speedUnit: .kts, distanceUnit: .nm, yellowTolerance: 5, redTolerance: 10, minSpeed: 100, maxSpeed: 160, proximityToNextPoint: 0.5)
        let actualPanelData = InstrumentPanelCalculator.makeData(currentLocation: currentLoc, flight: sut, config: config)
        
        // Assert
        XCTAssertEqual(sut.title, "XCT Test Flight" ,"Title should not be empty")
        
        let actualETA = try XCTUnwrap(actualPanelData.currentETA).value
        let expectedETA = try XCTUnwrap(expectedPanelData.currentETA).value
        XCTAssertEqual(actualETA, expectedETA, accuracy: 0.1, "Time on Target is not within Range")
        
        let actualDelta = try XCTUnwrap(actualPanelData.ETADelta).value
        let expectedDelta = try XCTUnwrap(expectedPanelData.ETADelta).value
        XCTAssertEqual(actualDelta, expectedDelta, accuracy: 0.1, "Time on Target Drift is not within Range")
        
        let actualBearingNext = try XCTUnwrap(actualPanelData.bearingNext).value
        let expectedBearingNext = try XCTUnwrap(expectedPanelData.bearingNext).value
        XCTAssertEqual(actualBearingNext, expectedBearingNext, accuracy: 0.5, "Course is not within Range")
        
        let actualTAS = try XCTUnwrap(actualPanelData.currentTrueAirspeed).value
        let expectedTAS = try XCTUnwrap(expectedPanelData.currentTrueAirspeed).value
        XCTAssertEqual(actualTAS, expectedTAS, accuracy: 0.1, "Groundspeed  is not within Range")
        
        let actualTargetTAS = try XCTUnwrap(actualPanelData.targetTrueAirspeed).value
        let expectedTargetTAS = try XCTUnwrap(expectedPanelData.targetTrueAirspeed).value
        XCTAssertEqual(actualTargetTAS, expectedTargetTAS, accuracy: 0.1, "Target GroundSpeed is not within Range")
        
        let actualDistNext = try XCTUnwrap(actualPanelData.distanceToNext).value
        let expectedDistNext = try XCTUnwrap(expectedPanelData.distanceToNext).value
        XCTAssertEqual(actualDistNext, expectedDistNext, accuracy: 0.1, "Distance to next is not within Range")
    }

    // MARK: - WindComponents
    func testWindWindComponentsHeadWind() {
        let bearing = 0.0
        let sut = Winds(velocity: 10, direction: 0.0, velocityUnit: .metersPerSecond)
        XCTAssertEqual(sut.windComponents(given: bearing).windEffectiveVelocity, -10.0, accuracy: 0.001)
    }

    func testWindWindComponentsTailWind() {
        let bearing = 0.0
        let sut = Winds(velocity: 10, direction: 180.0, velocityUnit: .metersPerSecond)
        XCTAssertEqual(sut.windComponents(given: bearing).windEffectiveVelocity, 10.0, accuracy: 0.001)
    }
    
    func testWindWindComponentsQuarteringTailWindWind() {
        let bearing = 0.0
        let sut = Winds(velocity: 10, direction: 120, velocityUnit: .metersPerSecond)
        XCTAssertEqual(sut.windComponents(given: bearing).windEffectiveVelocity, 5.0, accuracy: 0.001)
    }

    func testWindWindComponentsQuarteringHeadWindWind() {
        let bearing = 0.0
        let sut = Winds(velocity: 10, direction: 60.0, velocityUnit: .metersPerSecond)
        XCTAssertEqual(sut.windComponents(given: bearing).windEffectiveVelocity, -5.0, accuracy: 0.001)
    }
    
    func testWindWindComponentsDirectCrossWindWind() {
        let bearing = 0.0
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
        let bearing = startLocation.getBearing(to: endLocation)!.converted(to: .degrees).value
        XCTAssertEqual(bearing, expectedBearing, accuracy: 0.1, "Bearings do not equal 90 Degrees")
    }
    
    static func dateFromStringHelper(dateString: String) -> Date {
        let df = DateFormatter()
        df.dateFormat = "dd/MM/yyyy HH:mm:ss"
        return df.date(from: dateString)!
    }
}
