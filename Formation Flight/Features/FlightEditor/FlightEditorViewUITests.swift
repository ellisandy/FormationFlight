import XCTest

final class FlightEditorViewUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-uiTestsResetStore", "1"]

        app.launch()
        
        // Tap add button to present editor
        let addButton = app.buttons["addFlightButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 2), "Add button should exist")
        addButton.tap()
    }

    func testMissionNameEntry() throws {
        let missionField = app.textFields["missionNameField"]
        XCTAssertTrue(missionField.waitForExistence(timeout: 5), "Mission name field should exist")
        missionField.tap()
        missionField.typeText("Operation Sunrise")
        XCTAssertEqual(missionField.value as? String, "Operation Sunrise")
    }

    func testSwitchTimeTypeToHack() throws {
        let segmented = app.segmentedControls["timeTypeSegmentedControl"]
        XCTAssertTrue(segmented.waitForExistence(timeout: 5), "Segmented control should exist")
        let hackButton = segmented.buttons["Hack"]
        XCTAssertTrue(hackButton.exists, "Hack button should exist")
        hackButton.tap()
        XCTAssertTrue(hackButton.isSelected)
    }

    func testSelectTargetAndGoFly() throws {
        let targetRow = app.staticTexts["SelectNewTargetLabel"].firstMatch
        XCTAssertTrue(targetRow.waitForExistence(timeout: 5), "Target row should exist")
        targetRow.tap()

        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 10), "Map Save button should exist")
        saveButton.tap()

        let lat = app.staticTexts["targetLatitudeLabel"]
        let lon = app.staticTexts["targetLongitudeLabel"]
        XCTAssertTrue(lat.waitForExistence(timeout: 5), "Latitude label should appear")
        XCTAssertTrue(lon.waitForExistence(timeout: 5), "Longitude label should appear")

        let goFly = app.buttons["goFlyButton"]
        XCTAssertTrue(goFly.waitForExistence(timeout: 5), "Go Fly button should exist")
        goFly.tap()

        // TODO: Replace with a specific identifier from FlightView when available,
        // e.g., app.otherElements["flightViewRoot"].waitForExistence(timeout: 5)
        XCTAssertTrue(app.exists)
    }

    func testValidationError_MissingMissionTitle_WhenTargetSelected() throws {
        // Select a target first
        let targetRow = app.staticTexts["SelectNewTargetLabel"].firstMatch
        XCTAssertTrue(targetRow.waitForExistence(timeout: 5), "Target row should exist")
        targetRow.tap()

        let mapSave = app.buttons["Save"]
        XCTAssertTrue(mapSave.waitForExistence(timeout: 10), "Map Save button should exist")
        mapSave.tap()

        // Ensure mission title is empty
        let missionField = app.textFields["missionNameField"]
        XCTAssertTrue(missionField.waitForExistence(timeout: 5), "Mission name field should exist")
        missionField.tap()
        if let current = missionField.value as? String, current.isEmpty == false {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count)
            missionField.typeText(deleteString)
        }

        // Attempt to save
        let saveButton = app.buttons["flightEditorSaveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Save/Add button should exist")
        saveButton.tap()

        // Expect validation alert for missing title
        let validationAlert = app.alerts["Validation"]
        XCTAssertTrue(validationAlert.waitForExistence(timeout: 5), "Validation alert should appear for missing title")
        validationAlert.buttons["OK"].tap()
    }

    func testValidationError_MissingTarget_WhenTitleEntered() throws {
        // Enter a mission title
        let missionField = app.textFields["missionNameField"]
        XCTAssertTrue(missionField.waitForExistence(timeout: 5), "Mission name field should exist")
        missionField.tap()
        if let current = missionField.value as? String, current.isEmpty == false {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count)
            missionField.typeText(deleteString)
        }
        missionField.typeText("Test Mission")

        // Attempt to save without selecting a target
        let saveButton = app.buttons["flightEditorSaveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Save/Add button should exist")
        saveButton.tap()

        // Expect validation alert for missing target
        let validationAlert = app.alerts["Validation"]
        XCTAssertTrue(validationAlert.waitForExistence(timeout: 5), "Validation alert should appear for missing target")
        validationAlert.buttons["OK"].tap()
    }

    func testCreateFlightAndVerifyInList() throws {
        // Enter mission name
        let missionField = app.textFields["missionNameField"]
        XCTAssertTrue(missionField.waitForExistence(timeout: 5))
        missionField.tap()
        missionField.typeText("Mission Alpha")

        // Select target
        let targetRow = app.staticTexts["SelectNewTargetLabel"].firstMatch
        XCTAssertTrue(targetRow.waitForExistence(timeout: 5))
        targetRow.tap()

        let mapSave = app.buttons["Save"]
        XCTAssertTrue(mapSave.waitForExistence(timeout: 10))
        mapSave.tap()

        // Save flight
        let saveButton = app.buttons["flightEditorSaveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        // Verify it appears in the list
        let missionCell = app.cells.firstMatch
        XCTAssertTrue(missionCell.waitForExistence(timeout: 5), "Created flight should appear in list")
    }

    func testEditExistingFlightAndVerifyUpdates() throws {
        // Precondition: Create a flight first
        try testCreateFlightAndVerifyInList()

        // Tap the created flight to edit
        let createdFlightButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "Mission Alpha")).firstMatch
        XCTAssertTrue(createdFlightButton.waitForExistence(timeout: 5))
        createdFlightButton.tap()

        // Change mission name
        let missionField = app.textFields["missionNameField"]
        XCTAssertTrue(missionField.waitForExistence(timeout: 5))
        missionField.tap()
        if let current = missionField.value as? String { 
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count)
            missionField.typeText(deleteString)
        }
        missionField.typeText("Mission Beta")

        // Switch to Hack time type
        let segmented = app.segmentedControls["timeTypeSegmentedControl"]
        XCTAssertTrue(segmented.waitForExistence(timeout: 5))
        let hackButton = segmented.buttons["Hack"]
        XCTAssertTrue(hackButton.exists)
        hackButton.tap()

        // Optionally adjust hack time (if picker is accessible). For now, just save.
        let saveButton = app.buttons["flightEditorSaveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        // Verify the updated name in the list
        let updatedCell = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "Mission Beta")).firstMatch
        XCTAssertTrue(updatedCell.waitForExistence(timeout: 5), "Edited flight should show updated name")
    }
}
