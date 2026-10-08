//
//  Formation_FlightUITestsLaunchTests.swift
//  Formation FlightUITests
//
//  Created by Jack Ellis on 12/15/23.
//

import XCTest

@MainActor
final class Formation_FlightUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUp() async throws {
        continueAfterFailure = false
        // Keep the launch screenshot deterministic across runs.
        XCUIDevice.shared.orientation = .portrait
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        // Launch against an empty in-memory store so the captured screen (the
        // empty state) is identical on every run regardless of what the
        // simulator has saved. The safety disclaimer (R-07) is pre-acknowledged
        // so the screenshot shows the Flights list, not the first-launch cover.
        app.launchArguments += ["-uiTestsResetStore", "-hasAcknowledgedSafetyDisclaimer", "YES"]
        app.launch()

        let root = app.otherElements["FlightsListViewRoot"]
        XCTAssertTrue(
            root.waitForExistence(timeout: 5),
            "FlightsListViewRoot should be on screen after launch before the launch screenshot is taken"
        )

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
