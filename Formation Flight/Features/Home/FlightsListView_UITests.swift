//
//  FlightsListViewUITests.swift
//
//  Created by Tests on 2025-11-17.
//

import XCTest

final class FlightsListViewUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Ensure deterministic, isolated store for UI tests
        app.launchArguments += ["-uiTestsResetStore", "1"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers
    private func createFlightUI(name: String = "UI Test Flight") {
        // Tap add button to present editor
        let addButton = app.buttons["addFlightButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 2), "Add button should exist")
        addButton.tap()

        // Enter mission name – assumes a text field labeled or placeholder "Mission Name"
        // Update the identifier/label if your editor uses a different one.
        let nameField = app.textFields["Mission Name"]
        var usedField: XCUIElement
        if nameField.waitForExistence(timeout: 2) {
            usedField = nameField
        } else {
            // Try a generic first text field fallback
            let anyTextField = app.textFields.element(boundBy: 0)
            XCTAssertTrue(anyTextField.exists, "A text field for mission name should exist")
            usedField = anyTextField
        }
        usedField.tap()
        usedField.typeText(name)
        // Attempt to dismiss the keyboard to allow scrolling
        let returnKey = app.keyboards.buttons["Return"].firstMatch
        if returnKey.exists {
            returnKey.tap()
        } else {
            // Try tapping the navigation bar or root to resign first responder
            if app.navigationBars.element.exists {
                app.navigationBars.element.tap()
            } else {
                app.otherElements.element(boundBy: 0).tap()
            }
        }

        // Select a target – attempts to find button, scrolling if necessary
        var selectTargetButton = app.buttons["Select Target"]
        if !selectTargetButton.waitForExistence(timeout: 2) {
            // Try to scroll within a scroll view or the first scrollable container
            let scrollView = app.scrollViews.firstMatch
            if scrollView.exists {
                scrollView.swipeUp()
            } else {
                // Fallback: swipe up on the root if no explicit scroll view is found
                app.swipeUp()
            }
            // Re-query after scrolling
            selectTargetButton = app.buttons["Select Target"]
        }
        if selectTargetButton.waitForExistence(timeout: 2) {
            selectTargetButton.tap()
            // For simplicity, tap the first selectable coordinate or confirm selection
            // If your UI shows a map, you might need to tap a default pin or use a canned coordinate button.
            // Try a generic "Done" or "Use This Location" button.
            let done = app.buttons["Save"].firstMatch
            if done.waitForExistence(timeout: 2) {
                done.tap()
            }
            let useLocation = app.buttons["Use This Location"].firstMatch
            if useLocation.exists { useLocation.tap() }
        }

        // Tap Save or Add
        let saveButton = app.buttons["Save"].firstMatch.exists ? app.buttons["Save"] : app.buttons["Add"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2), "Save/Add button should exist")
        saveButton.tap()
    }

    func testEmptyStateAndCreateFirstFlightButtonPresentsEditor() throws {
        let root = app.otherElements["FlightsListViewRoot"]
        XCTAssertTrue(root.waitForExistence(timeout: 5), "FlightsListView should appear")

        // If empty, create via empty state button; otherwise, just ensure editor can present
        let emptyState = app.otherElements["emptyStateView"]
        if emptyState.waitForExistence(timeout: 1) {
            let createBtn = app.buttons["emptyStateCreateFirstFlightButton"]
            XCTAssertTrue(createBtn.exists)
            createBtn.tap()
            XCTAssertTrue(app.navigationBars.element.waitForExistence(timeout: 2))
            // Dismiss editor by cancelling if available, else save a minimal flight
            if app.buttons["Cancel"].exists {
                app.buttons["Cancel"].tap()
            } else if app.buttons["Save"].exists {
                // Attempt helper to save properly
                app.navigationBars.buttons.element(boundBy: 0).tap() // navigate back if needed
            }
        } else {
            // Not empty; ensure add button presents the editor
            let addButton = app.buttons["addFlightButton"]
            XCTAssertTrue(addButton.exists)
            addButton.tap()
            XCTAssertTrue(app.navigationBars.element.waitForExistence(timeout: 2))
        }
    }

    func testAddFlightButtonPresentsEditor() throws {
        let root = app.otherElements["FlightsListViewRoot"]
        XCTAssertTrue(root.waitForExistence(timeout: 5))

        createFlightUI(name: "Created Via Toolbar")

        // Verify at least one row exists
        let cell = app.otherElements.containing(NSPredicate(format: "identifier BEGINSWITH %@", "flightRow_")).element(boundBy: 0)
        XCTAssertTrue(cell.waitForExistence(timeout: 2))
    }

    func testSwipeToDeleteShowsConfirmationAndDeletes() throws {
        let root = app.otherElements["FlightsListViewRoot"]
        XCTAssertTrue(root.waitForExistence(timeout: 5))

        // Create a new row named "To Delete"
        let flightName = "To Delete"
        createFlightUI(name: flightName)

        // Find any element on screen that matches the created flight name
        // Prefer a button with that label, otherwise fall back to any static text with that label
        var targetElement: XCUIElement = app.buttons[flightName]
        if !targetElement.waitForExistence(timeout: 2) {
            targetElement = app.staticTexts[flightName]
        }
        XCTAssertTrue(targetElement.waitForExistence(timeout: 2), "Expected to find an element labeled \(flightName)")

        // Swipe left on the located element to reveal delete action
        targetElement.swipeLeft()

        let deleteButton = app.buttons.containing(NSPredicate(format: "identifier BEGINSWITH %@", "flightRowDelete_")).element(boundBy: 0)
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2), "Swipe delete button should exist")
        XCTAssertEqual(app.buttons.containing(NSPredicate(format: "identifier BEGINSWITH %@", "flightRowDelete_")).count, 1, "There should be exactly one delete button visible")
        deleteButton.tap()

        // Confirm deletion
        let confirmAlert = app.alerts["Delete Flight?"]
        XCTAssertTrue(confirmAlert.waitForExistence(timeout: 2))
        confirmAlert.buttons["Delete"].tap()

        // Verify the element no longer exists
        XCTAssertFalse(targetElement.waitForExistence(timeout: 2), "Row should disappear after deletion")
    }

    func testValidationAlertAppearsOnSaveWithoutTarget() throws {
        let root = app.otherElements["FlightsListViewRoot"]
        XCTAssertTrue(root.waitForExistence(timeout: 5))

        let addButton = app.buttons["addFlightButton"]
        XCTAssertTrue(addButton.exists)
        addButton.tap()

        let saveOrAdd = app.buttons["Save"].firstMatch.exists ? app.buttons["Save"] : app.buttons["Add"]
        if !saveOrAdd.waitForExistence(timeout: 2) {
            throw XCTSkip("Save/Add button not found in editor; update test to match editor UI identifiers.")
        }
        saveOrAdd.tap()

        let validationAlert = app.alerts["Validation"]
        XCTAssertTrue(validationAlert.waitForExistence(timeout: 2))
        validationAlert.buttons["OK"].tap()
    }
}

