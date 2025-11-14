//
//  FlightEditorConfig_Test.swift
//  Formation FlightTests
//
//  Created by Jack Ellis on 12/24/23.
//

import XCTest
@testable import Formation_Flight


final class FlightEditorConfig_Test: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testPresentAddFlight() throws {
        var sut = FlightEditorConfig.init()
        
        sut.presentAddFlight()
        
        XCTAssert(sut.isPresented == true)
        XCTAssert(sut.shouldSaveChanges == false)
        XCTAssert(sut.flight.title == "")
    }
    
    func testPresentEditFlight() throws {
        let flight = Flight.emptyFlight()
        flight.title = "Test"
        var sut = FlightEditorConfig.init()
    
        sut.presentEditFlight(flight)
        
        XCTAssert(sut.isPresented == true)
        XCTAssert(sut.shouldSaveChanges == false)
        XCTAssert(sut.flight.title == "Test")
    }
    
    func testDone() throws {
        var sut = FlightEditorConfig.init()
        sut.isPresented = true
        sut.shouldSaveChanges = false
        
        sut.done()

        XCTAssert(sut.isPresented == false)
        XCTAssert(sut.shouldSaveChanges == true)
    }
    
    func testCancel() throws {
        var sut = FlightEditorConfig.init()
        sut.isPresented = true
        sut.shouldSaveChanges = true
        
        sut.cancel()

        XCTAssert(sut.isPresented == false)
        XCTAssert(sut.shouldSaveChanges == false)
    }
}
