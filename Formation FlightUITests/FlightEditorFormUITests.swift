// FlightEditorFormUITests.swift
// UI tests for FlightEditorForm using XCTest UI Testing

import XCTest

final class FlightEditorFormUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        navigateToFlightEditor()
    }

    // Helper to find elements quickly
    private func field(_ identifier: String) -> XCUIElement { app.textFields[identifier] }
    private func secureField(_ identifier: String) -> XCUIElement { app.secureTextFields[identifier] }
    private func other(_ identifier: String) -> XCUIElement { app.otherElements[identifier] }
    private func button(_ identifier: String) -> XCUIElement { app.buttons[identifier] }
    private func datePicker(_ identifier: String) -> XCUIElement { app.datePickers[identifier] }

    // Scroll the main view until an element with the given identifier is visible or timeout elapses
    @discardableResult
    private func scrollToElement(_ element: XCUIElement, maxScrolls: Int = 8, directionUpFirst: Bool = false) -> Bool {
        let scrollView = app.scrollViews.firstMatch
        let container = scrollView.exists ? scrollView : app

        var attempts = 0
        // Try an initial small swipe in the hinted direction
        if directionUpFirst {
            container?.swipeUp()
        } else {
            container?.swipeDown()
        }

        while !element.exists || !element.isHittable {
            if attempts >= maxScrolls { break }
            attempts += 1
            // Alternate swipe direction to discover content in both directions
            if attempts % 2 == 0 {
                container?.swipeUp()
            } else {
                container?.swipeDown()
            }
            if element.waitForExistence(timeout: 0.5), element.isHittable { return true }
        }
        return element.exists
    }

    private func navigateToFlightEditor() {
        // Try common identifiers/titles for a plus button in a navigation bar
        let addButtonByIdentifier = app.buttons["addFlightButton"]
        addButtonByIdentifier.tap()
    }

    func testEditMissionTitleAndDate() throws {
        let titleField = field("missionTitleField")
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Mission title field should exist")
        titleField.tap()
        titleField.typeText("UI Test Mission")

        let dp = datePicker("missionDatePicker")
        XCTAssertTrue(dp.waitForExistence(timeout: 2), "Mission date picker should exist")
        // Interact with date picker in a minimal way; exact wheels depend on style.
        // This ensures we at least can focus it.
        dp.tap()
    }

    func testEnterWindInputs() throws {
        let directionField = field("windDirectionField")
        XCTAssertTrue(directionField.waitForExistence(timeout: 5))
        directionField.tap()
        directionField.typeText("270")

        let velocityField = field("windVelocityField")
        XCTAssertTrue(velocityField.waitForExistence(timeout: 2))
        velocityField.tap()
        velocityField.typeText("15")
    }

    func testOpenCheckpointSheetFromNew() throws {
        let newButton = button("newCheckpointButton")
        XCTAssertTrue(newButton.waitForExistence(timeout: 5))
        newButton.tap()

        let sheet = other("checkpointSheet")
        // The sheet may appear offscreen; scroll to reveal if needed
        _ = scrollToElement(sheet, maxScrolls: 6, directionUpFirst: true)
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "Checkpoint sheet should appear")

        // Dismiss sheet by tapping outside or using a cancel control if available.
        // If the sheet provides a Cancel button with identifier, prefer that.
        app.swipeDown()
    }

    func testTapFirstCheckpointRowIfPresent() throws {
        let newButton = button("newCheckpointButton")
        XCTAssertTrue(newButton.waitForExistence(timeout: 2))
        newButton.tap()

        let sheet = other("checkpointSheet")
        _ = scrollToElement(sheet, maxScrolls: 6, directionUpFirst: true)
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))

        let nameField = field("checkpointNameField")
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("CP Home")

        let saveButton = button("checkpointSaveButton")
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        saveButton.tap()

        
        // If there is at least one checkpoint, we should be able to tap it and open the sheet
        let row = button("checkpointRow_0")
        if row.waitForExistence(timeout: 2) {
            row.tap()
            let sheet = other("checkpointSheet")
            XCTAssertTrue(sheet.waitForExistence(timeout: 3))
            XCTAssertEqual(nameField.value as? String, "CP Home", "checkpointNameField should contain 'CP Home'")
            app.swipeDown()
        }
    }

    func testEndToEndCreateFlightWithCheckpoint() throws {
        // 1) Fill out mission title
        let titleField = field("missionTitleField")
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("End-to-End Mission")

        // 2) Set wind inputs
        let directionField = field("windDirectionField")
        XCTAssertTrue(directionField.waitForExistence(timeout: 2))
        directionField.tap()
        directionField.typeText("180")

        let velocityField = field("windVelocityField")
        XCTAssertTrue(velocityField.waitForExistence(timeout: 2))
        velocityField.tap()
        velocityField.typeText("25")

        // 3) Add a checkpoint via the New Check Point button
        let newButton = button("newCheckpointButton")
        XCTAssertTrue(newButton.waitForExistence(timeout: 2))
        newButton.tap()

        let sheet = other("checkpointSheet")
        _ = scrollToElement(sheet, maxScrolls: 6, directionUpFirst: true)
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))

        let nameField = field("checkpointNameField")
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("CP Home")

        let saveButton = button("checkpointSaveButton")
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        saveButton.tap()

        // 4) Verify at least one checkpoint row exists now (index 0)
        let firstRow = button("checkpointRow_0")
        XCTAssertTrue(firstRow.waitForExistence(timeout: 3), "Expected a checkpoint row after adding one")

        // 5) Optionally, tap the row to ensure editing works and the sheet appears
        firstRow.tap()
        XCTAssertTrue(sheet.waitForExistence(timeout: 3))
        let cancelButton = button("checkpointCancelButton")
        if cancelButton.waitForExistence(timeout: 2) {
            cancelButton.tap()
        } else {
            app.swipeDown()
        }
    }

    func testAddTwoCheckpointsAndReorder() throws {
        // Open the New Checkpoint sheet and add first checkpoint
        let newButton = button("newCheckpointButton")
        XCTAssertTrue(newButton.waitForExistence(timeout: 5))
        newButton.tap()

        let sheet = other("checkpointSheet")
        _ = scrollToElement(sheet, maxScrolls: 6, directionUpFirst: true)
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))

        let nameField = field("checkpointNameField")
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("CP One")

        let saveButton = button("checkpointSaveButton")
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        saveButton.tap()

        // Add second checkpoint
        XCTAssertTrue(newButton.waitForExistence(timeout: 3))
        newButton.tap()
        _ = scrollToElement(sheet, maxScrolls: 6, directionUpFirst: true)
        XCTAssertTrue(sheet.waitForExistence(timeout: 3))
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("CP Two")
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        saveButton.tap()

        // Verify two rows exist
        let firstRow = button("checkpointRow_0")
        let secondRow = button("checkpointRow_1")
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "First checkpoint row should exist")
        XCTAssertTrue(secondRow.waitForExistence(timeout: 5), "Second checkpoint row should exist")

        // Attempt to reorder: drag the second row onto the first row (move up)
        // This assumes the list supports drag and drop reordering.
        if secondRow.isHittable && firstRow.isHittable {
            let start = secondRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let end = firstRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
            start.press(forDuration: 0.5, thenDragTo: end)
        } else {
            // Fallback: long press on second, then a short drag upward
            secondRow.press(forDuration: 0.8)
            app.swipeUp()
        }

        // After reorder, verify that rows still exist; if there are labels per row, try to validate order.
        XCTAssertTrue(button("checkpointRow_0").waitForExistence(timeout: 3))
        XCTAssertTrue(button("checkpointRow_1").waitForExistence(timeout: 3))

        // Optional: If the UI exposes labels per row index, assert text order.
        // For example, if there are staticTexts with identifiers like `checkpointNameLabel_0` and `checkpointNameLabel_1`.
        let firstNameLabel = app.staticTexts["checkpointNameLabel_0"]
        let secondNameLabel = app.staticTexts["checkpointNameLabel_1"]
        if firstNameLabel.exists && secondNameLabel.exists {
            // After dragging second onto first, expect order to be: CP Two, CP One
            XCTAssertEqual(firstNameLabel.label, "CP Two")
            XCTAssertEqual(secondNameLabel.label, "CP One")
        }
    }

    func testDeleteCheckpoint() throws {
        // Ensure there is at least one checkpoint by creating one
        let newButton = button("newCheckpointButton")
        XCTAssertTrue(newButton.waitForExistence(timeout: 5))
        newButton.tap()

        let sheet = other("checkpointSheet")
        _ = scrollToElement(sheet, maxScrolls: 6, directionUpFirst: true)
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))

        let nameField = field("checkpointNameField")
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("CP To Delete")

        let saveButton = button("checkpointSaveButton")
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        saveButton.tap()

        // Verify the checkpoint row exists
        let row = button("checkpointRow_0")
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Expected a checkpoint row to delete")

        // Prefer swipe-to-delete on the row
        row.swipeLeft()
        // Look for the Delete button that appears after swipe
        let deleteButton = app.buttons["Delete"]
        if deleteButton.waitForExistence(timeout: 2) {
            deleteButton.tap()
        }

        // Exit edit mode if a Done button is present
        let doneButton = app.navigationBars.buttons["Done"]
        if doneButton.waitForExistence(timeout: 2) {
            doneButton.tap()
        }

        // Assert the row no longer exists
        XCTAssertFalse(row.waitForExistence(timeout: 2), "Checkpoint row should be deleted")
    }

    func testUpdateCheckpointNameAndSave() throws {
        // 1) Create an initial checkpoint
        let newButton = button("newCheckpointButton")
        XCTAssertTrue(newButton.waitForExistence(timeout: 5))
        newButton.tap()

        let sheet = other("checkpointSheet")
        _ = scrollToElement(sheet, maxScrolls: 6, directionUpFirst: true)
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))

        let nameField = field("checkpointNameField")
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("Original CP")

        let saveButton = button("checkpointSaveButton")
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        saveButton.tap()

        // 2) Open the first checkpoint for editing by tapping its row
        let firstRow = button("checkpointRow_0")
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "Expected first checkpoint row to exist")
        firstRow.tap()
        _ = scrollToElement(sheet, maxScrolls: 6, directionUpFirst: true)
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))

        // 3) Update the name and save
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()

        // Clear existing text in the text field
        if let currentValue = nameField.value as? String {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            nameField.typeText(deleteString)
        }
        nameField.typeText("Updated CP")

        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        saveButton.tap()

        // 4) Verify the updated name is reflected. If there is a label for the row name, check it.
        let firstNameLabel = app.staticTexts["checkpointNameLabel_0"]
        if firstNameLabel.waitForExistence(timeout: 2) {
            XCTAssertEqual(firstNameLabel.label, "Updated CP")
        } else {
            // Fallback: reopen the row and check the field value inside the sheet
            firstRow.tap()
            _ = scrollToElement(sheet, maxScrolls: 6, directionUpFirst: true)
            XCTAssertTrue(sheet.waitForExistence(timeout: 5))
            XCTAssertEqual(nameField.value as? String, "Updated CP")

            // Dismiss the sheet
            let cancelButton = button("checkpointCancelButton")
            if cancelButton.waitForExistence(timeout: 2) {
                cancelButton.tap()
            } else {
                app.swipeDown()
            }
        }
    }
}

