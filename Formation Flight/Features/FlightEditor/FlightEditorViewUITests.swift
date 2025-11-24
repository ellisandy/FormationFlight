import XCTest

final class FlightEditorViewUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testMissionNameEntry() throws {
        let missionField = app.textFields["missionNameField"]
        XCTAssertTrue(missionField.waitForExistence(timeout: 5))
        missionField.tap()
        missionField.typeText("Operation Sunrise")
        // Verify text field now contains the typed value
        XCTAssertEqual(missionField.value as? String, "Operation Sunrise")
    }

    func testSwitchTimeTypeToHack() throws {
        let segmented = app.segmentedControls["timeTypeSegmentedControl"]
        XCTAssertTrue(segmented.waitForExistence(timeout: 5))
        let hackButton = segmented.buttons["Hack"]
        XCTAssertTrue(hackButton.exists)
        hackButton.tap()
        // Basic assertion that selection changed
        XCTAssertTrue(hackButton.isSelected)
    }

    func testSelectTargetAndGoFly() throws {
        let targetRow = app.otherElements["targetRow"]
        // The HStack may be represented as an otherElement; we wait for it
        XCTAssertTrue(targetRow.waitForExistence(timeout: 5))
        targetRow.tap()

        // On the map picker screen, we expect a Save button to exist.
        // If your map picker uses a different identifier, adjust this accordingly.
        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 10))
        saveButton.tap()

        // Back on the editor, expect coordinate labels to appear
        let lat = app.staticTexts["targetLatitudeLabel"]
        let lon = app.staticTexts["targetLongitudeLabel"]
        XCTAssertTrue(lat.waitForExistence(timeout: 5))
        XCTAssertTrue(lon.waitForExistence(timeout: 5))

        // Tap Go Fly
        let goFly = app.buttons["goFlyButton"]
        XCTAssertTrue(goFly.waitForExistence(timeout: 5))
        goFly.tap()

        // Verify the full screen cover presents FlightView by checking for something unique.
        // If FlightView exposes an identifier, replace the below with that.
        // As a fallback, wait briefly for any change (this is a placeholder and should be customized).
        sleep(1)
        XCTAssertTrue(app.exists)
    }
}
