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

    // Resolve a reasonable scrollable container for forms
    private var scrollContainer: XCUIElement {
        let table = app.tables.firstMatch
        if table.exists { return table }
        let scroll = app.scrollViews.firstMatch
        if scroll.exists { return scroll }
        return app
    }

    // Scroll until an element is visible/hittable or retries exhausted
    @discardableResult
    private func scrollToElement(_ element: XCUIElement, maxScrolls: Int = 10, directionUpFirst: Bool = false) -> Bool {
        let container = scrollContainer

        // Give the element a moment to appear before scrolling
        _ = element.waitForExistence(timeout: 0.5)

        var attempts = 0

        // Initial nudge in hinted direction
        if directionUpFirst {
            container.swipeUp()
        } else {
            container.swipeDown()
        }

        // If it already exists and is hittable, done
        if element.exists && element.isHittable { return true }

        while attempts < maxScrolls {
            attempts += 1

            // Alternate directions each attempt
            if attempts % 2 == 0 {
                container.swipeUp()
            } else {
                container.swipeDown()
            }

            // Small wait to let layout settle
            if element.waitForExistence(timeout: 0.6), element.isHittable {
                return true
            }
        }

        // As a last resort, if it exists but isn't hittable, try a final up and down
        if element.exists && !element.isHittable {
            container.swipeUp()
            container.swipeDown()
        }

        return element.exists
    }

    private func navigateToFlightEditor() {
        // Try a known identifier for the "add flight" action
        let addButtonByIdentifier = app.buttons["addFlightButton"]
        if addButtonByIdentifier.waitForExistence(timeout: 3) {
            addButtonByIdentifier.tap()
        }
    }

    func testEditMissionTitleAndDate() throws {
        let titleField = field("missionTitleField")
        if !titleField.isHittable { _ = scrollToElement(titleField, maxScrolls: 6, directionUpFirst: true) }
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Mission title field should exist")
        titleField.tap()
        titleField.typeText("UI Test Mission")

        let dp = datePicker("missionDatePicker")
        if !dp.isHittable { _ = scrollToElement(dp, maxScrolls: 6, directionUpFirst: true) }
        XCTAssertTrue(dp.waitForExistence(timeout: 3), "Mission date picker should exist")
        dp.tap()
    }

    func testEnterWindInputs() throws {
        let directionField = field("windDirectionField")
        if !directionField.isHittable { _ = scrollToElement(directionField, maxScrolls: 6, directionUpFirst: true) }
        XCTAssertTrue(directionField.waitForExistence(timeout: 5))
        directionField.tap()
        directionField.typeText("270")

        let velocityField = field("windVelocityField")
        if !velocityField.isHittable { _ = scrollToElement(velocityField, maxScrolls: 6, directionUpFirst: true) }
        XCTAssertTrue(velocityField.waitForExistence(timeout: 3))
        velocityField.tap()
        velocityField.typeText("15")
    }

    func testOpenCheckpointSheetFromNew() throws {
        let newButton = button("newCheckpointButton")
        if !newButton.isHittable { _ = scrollToElement(newButton, maxScrolls: 6, directionUpFirst: true) }
        XCTAssertTrue(newButton.waitForExistence(timeout: 5))
        newButton.tap()

        let sheet = other("checkpointSheet")
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "Checkpoint sheet should appear")

        app.swipeDown()
    }

    func testTapFirstCheckpointRowIfPresent() throws {
        let newButton = button("newCheckpointButton")
        if !newButton.isHittable { _ = scrollToElement(newButton, maxScrolls: 6, directionUpFirst: true) }
        XCTAssertTrue(newButton.waitForExistence(timeout: 3))
        newButton.tap()

        let sheet = other("checkpointSheet")
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))

        let nameField = field("checkpointNameField")
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("CP Home")

        let saveButton = button("checkpointSaveButton")
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        saveButton.tap()

        let row = button("checkpointRow_0")
        if row.waitForExistence(timeout: 3) {
            if !row.isHittable { _ = scrollToElement(row, maxScrolls: 6, directionUpFirst: true) }
            row.tap()
            let sheet = other("checkpointSheet")
            XCTAssertTrue(sheet.waitForExistence(timeout: 3))
            XCTAssertEqual(nameField.value as? String, "CP Home", "checkpointNameField should contain 'CP Home'")
            app.swipeDown()
        }
    }

    func testEndToEndCreateFlightWithCheckpoint() throws {
        let titleField = field("missionTitleField")
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("End-to-End Mission")

        let directionField = field("windDirectionField")
        if !directionField.isHittable { _ = scrollToElement(directionField, maxScrolls: 6, directionUpFirst: true) }
        XCTAssertTrue(directionField.waitForExistence(timeout: 3))
        directionField.tap()
        directionField.typeText("180")

        let velocityField = field("windVelocityField")
        if !velocityField.isHittable { _ = scrollToElement(velocityField, maxScrolls: 6, directionUpFirst: true) }
        XCTAssertTrue(velocityField.waitForExistence(timeout: 3))
        velocityField.tap()
        velocityField.typeText("25")

        let newButton = button("newCheckpointButton")
        if !newButton.isHittable { _ = scrollToElement(newButton, maxScrolls: 6, directionUpFirst: false) }
        XCTAssertTrue(newButton.waitForExistence(timeout: 3))
        newButton.tap()

        let sheet = other("checkpointSheet")
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))

        let nameField = field("checkpointNameField")
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("CP Home")

        let saveButton = button("checkpointSaveButton")
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        saveButton.tap()

        let firstRow = button("checkpointRow_0")
        _ = scrollToElement(firstRow, maxScrolls: 10, directionUpFirst: false)
        XCTAssertTrue(firstRow.waitForExistence(timeout: 3), "Expected a checkpoint row after adding one")

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
        let newButton = button("newCheckpointButton")
        if !newButton.isHittable { _ = scrollToElement(newButton, maxScrolls: 6, directionUpFirst: false) }
        XCTAssertTrue(newButton.waitForExistence(timeout: 5))
        newButton.tap()

        let sheet = other("checkpointSheet")
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))

        let nameField = field("checkpointNameField")
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("CP One")

        let saveButton = button("checkpointSaveButton")
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        saveButton.tap()

        if !newButton.isHittable { _ = scrollToElement(newButton, maxScrolls: 6, directionUpFirst: true) }
        newButton.tap()
        XCTAssertTrue(sheet.waitForExistence(timeout: 3))
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("CP Two")
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        saveButton.tap()

        let firstRow = button("checkpointRow_0")
        let secondRow = button("checkpointRow_1")
        _ = scrollToElement(secondRow, maxScrolls: 10, directionUpFirst: false)
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "First checkpoint row should exist")
        XCTAssertTrue(secondRow.waitForExistence(timeout: 5), "Second checkpoint row should exist")

        if secondRow.isHittable && firstRow.isHittable {
            let start = secondRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let end = firstRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
            start.press(forDuration: 0.5, thenDragTo: end)
        } else {
            secondRow.press(forDuration: 0.8)
            app.swipeUp()
        }

        XCTAssertTrue(button("checkpointRow_0").waitForExistence(timeout: 3))
        XCTAssertTrue(button("checkpointRow_1").waitForExistence(timeout: 3))

        let firstNameLabel = app.staticTexts["checkpointNameLabel_0"]
        let secondNameLabel = app.staticTexts["checkpointNameLabel_1"]
        if firstNameLabel.exists && secondNameLabel.exists {
            XCTAssertEqual(firstNameLabel.label, "CP Two")
            XCTAssertEqual(secondNameLabel.label, "CP One")
        }
    }

    func testDeleteCheckpoint() throws {
        let newButton = button("newCheckpointButton")
        if !newButton.isHittable { _ = scrollToElement(newButton, maxScrolls: 6, directionUpFirst: false) }
        XCTAssertTrue(newButton.waitForExistence(timeout: 5))
        newButton.tap()

        let sheet = other("checkpointSheet")
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))

        let nameField = field("checkpointNameField")
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("CP To Delete")

        let saveButton = button("checkpointSaveButton")
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        saveButton.tap()

        let row = button("checkpointRow_0")
        if !row.isHittable { _ = scrollToElement(newButton, maxScrolls: 6, directionUpFirst: false) }
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Expected a checkpoint row to delete")

        row.swipeLeft()
        let deleteButton = app.buttons["Delete"]
        if deleteButton.waitForExistence(timeout: 2) {
            deleteButton.tap()
        }

        let doneButton = app.navigationBars.buttons["Done"]
        if doneButton.waitForExistence(timeout: 2) {
            doneButton.tap()
        }

        XCTAssertFalse(row.waitForExistence(timeout: 2), "Checkpoint row should be deleted")
    }

    func testUpdateCheckpointNameAndSave() throws {
        let newButton = button("newCheckpointButton")
        if !newButton.isHittable { _ = scrollToElement(newButton, maxScrolls: 6, directionUpFirst: false) }
        XCTAssertTrue(newButton.waitForExistence(timeout: 5))
        newButton.tap()

        let sheet = other("checkpointSheet")
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))

        let nameField = field("checkpointNameField")
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("Original CP")

        let saveButton = button("checkpointSaveButton")
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        saveButton.tap()

        if !newButton.isHittable { _ = scrollToElement(newButton, maxScrolls: 6, directionUpFirst: false) }
        let firstRow = button("checkpointRow_0")
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "Expected first checkpoint row to exist")
        firstRow.tap()
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))

        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()

        if let currentValue = nameField.value as? String {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            nameField.typeText(deleteString)
        }
        nameField.typeText("Updated CP")

        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        saveButton.tap()

        if !newButton.isHittable { _ = scrollToElement(newButton, maxScrolls: 6, directionUpFirst: false) }
        let firstNameLabel = app.staticTexts["checkpointNameLabel_0"]
        if firstNameLabel.waitForExistence(timeout: 2) {
            XCTAssertEqual(firstNameLabel.label, "Updated CP")
        } else {
            firstRow.tap()
            _ = scrollToElement(sheet, maxScrolls: 10, directionUpFirst: true)
            XCTAssertTrue(sheet.waitForExistence(timeout: 5))
            XCTAssertEqual(nameField.value as? String, "Updated CP")

            let cancelButton = button("checkpointCancelButton")
            if cancelButton.waitForExistence(timeout: 2) {
                cancelButton.tap()
            } else {
                app.swipeDown()
            }
        }
    }
}

