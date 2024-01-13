//
//  FlightCalculationProvider.swift
//  Formation FlightTests
//
//  Created by Jack Ellis on 12/30/23.
//

import XCTest
import CoreLocation
@testable import Formation_Flight

final class FlightCalculationProvider_Test: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }


    
    func testcalculateData() {
        //288,200 feet
        //87,843.36 meters
        // traveling 100 M/s (194 kts)
        let p1 = CLLocation(latitude: 38.0, longitude: 0.0)
        let p2 = CLLocation(latitude: 38.0, longitude: 1.0)
        let winds = Winds(velocity: 0, direction: 0)
        let speed = 100.0 //100 M/s
        
        
        let sut = FlightCalculationProvider.calculateData(currentLocation: p1, targetLocation: p2, winds: winds, groundSpeed: speed)
        
        XCTAssertEqual(sut.course.converted(to: .degrees).value, 90.0, accuracy: 1.0)
        XCTAssertEqual(sut.ETA.converted(to: .seconds).value, 878.43, accuracy: 1.0)
    }
}
