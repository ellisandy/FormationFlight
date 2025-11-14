//
//  Formation_FlightUITests.swift
//  Formation FlightUITests
//
//  Created by Jack Ellis on 12/15/23.
//

import XCTest

final class Formation_FlightUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    func test_appShowsFlightsListViewQuickly() throws {
        let app = XCUIApplication()
        let start = Date()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 60), "App did not reach foreground in time.")

        let contentRoot = app.otherElements["FlightsListViewRoot"]
        let threshold: TimeInterval = 30
        let appeared = contentRoot.waitForExistence(timeout: threshold)

        let elapsed = Date().timeIntervalSince(start)
        XCTAssertTrue(appeared, "FlightsListView did not appear within \(threshold)s (elapsed: \(elapsed)s).")
    }

    func test_measureStartupToFlightsListView() throws {
        if #available(iOS 13.0, *) {
            measure(metrics: [XCTClockMetric()]) {
                let app = XCUIApplication()
                app.terminate()
                let start = Date()
                app.launch()
                XCTAssertTrue(app.wait(for: .runningForeground, timeout: 60))
                XCTAssertTrue(app.otherElements["FlightsListViewRoot"].waitForExistence(timeout: 30))
                let elapsed = Date().timeIntervalSince(start)
                XCTAssertLessThan(elapsed, 30, "Startup exceeded threshold: \(elapsed)s")
            }
        }
    }
}

