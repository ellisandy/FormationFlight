//
//  FlightsListViewUITests.swift
//
//  Created by Tests on 2025-11-17.
//

import XCTest

/// UI tests for the Flights list: empty state, creating a flight through the
/// editor, swipe-to-delete, and the validation alert.
///
/// Every test launches against a fresh in-memory store (`-uiTestsResetStore`),
/// so the starting screen is always the empty state unless the test also asks
/// for seed data (`-uiTestsSeedFlights`, which inserts `UI F1` and `UI F2`).
/// Elements are located by accessibility identifier only; display strings are
/// used solely for system alerts, which have no identifiers.
final class FlightsListViewUITests: XCTestCase {

    private var app: XCUIApplication!

    // Predicates are built fresh on each call: `NSPredicate` is not `Sendable`, and
    // under Swift 6 a value reachable from `self` cannot be handed to
    // `XCUIElementQuery`, so these are static factories rather than properties.

    /// Matches the list row container of every flight (`flightRow_<uuid>`).
    private static func flightRowPredicate() -> NSPredicate {
        NSPredicate(format: "identifier BEGINSWITH %@", "flightRow_")
    }
    /// Matches the swipe-action delete button of every flight (`flightRowDelete_<uuid>`).
    private static func flightRowDeletePredicate() -> NSPredicate {
        NSPredicate(format: "identifier BEGINSWITH %@", "flightRowDelete_")
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        // The simulator keeps its last orientation between runs; the editor's
        // Form only fits without scrolling in portrait.
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()

        // The editor requests location authorization when it appears. On a
        // fresh simulator that raises a system alert, which would otherwise
        // block the first interaction with the editor.
        addUIInterruptionMonitor(withDescription: "Location permission alert") { alert in
            let allow = alert.buttons["Allow While Using App"]
            guard allow.exists else { return false }
            allow.tap()
            return true
        }
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Launch

    /// Launches the app against an in-memory store and waits for the Flights list.
    /// - Parameter seeded: When `true`, the store starts with the two seed flights
    ///   `UI F1` and `UI F2`; otherwise it starts empty.
    ///
    /// The safety disclaimer (R-07) is pre-acknowledged through the
    /// `-hasAcknowledgedSafetyDisclaimer YES` launch argument, which
    /// `UserDefaults` honours directly, so it never blocks these tests.
    /// `testSafetyDisclaimerShowsOnFirstLaunchAndIsAcknowledgedOnce` launches
    /// on its own to cover the first-launch path.
    private func launch(seeded: Bool = false) {
        app.launchArguments += ["-uiTestsResetStore", "-hasAcknowledgedSafetyDisclaimer", "YES"]
        if seeded {
            app.launchArguments += ["-uiTestsSeedFlights"]
        }
        app.launch()

        XCTAssertTrue(
            app.otherElements["FlightsListViewRoot"].waitForExistence(timeout: 5),
            "FlightsListViewRoot should be on screen after launch"
        )
    }

    // MARK: - Queries

    /// All flight rows currently in the list, regardless of element type.
    private var flightRows: XCUIElementQuery {
        app.descendants(matching: .any).matching(Self.flightRowPredicate())
    }

    /// Waits until `query` matches exactly `count` elements.
    private func waitForCount(_ count: Int, of query: XCUIElementQuery, timeout: TimeInterval = 5, _ message: String) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count == %d", count), object: query)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "\(message) (expected \(count) match(es), found \(query.count))")
    }

    // MARK: - Editor flow

    /// Taps the toolbar add button and waits for the editor's mission name field.
    private func openEditorFromToolbar() {
        let addButton = app.buttons["addFlightButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "addFlightButton should be in the Flights toolbar")
        addButton.tap()

        XCTAssertTrue(
            app.textFields["missionNameField"].waitForExistence(timeout: 5),
            "missionNameField should appear once the editor is pushed"
        )
    }

    /// Scrolls the editor form until `element` exists. Rows of a SwiftUI `Form`
    /// are only in the accessibility tree once laid out, so on short screens the
    /// Target row is not queryable until the form is scrolled. The drag starts
    /// near the bottom of the window so it never lands on the time-entry wheels,
    /// which would spin instead of scrolling the form.
    private func revealInEditorForm(_ element: XCUIElement, _ description: String, maxSwipes: Int = 3) {
        let window = app.windows.firstMatch
        var swipes = 0
        while !element.exists, swipes < maxSwipes {
            let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
            let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
            start.press(forDuration: 0.05, thenDragTo: end)
            swipes += 1
        }
        XCTAssertTrue(element.waitForExistence(timeout: 2), "\(description) should be reachable in the editor form")
    }

    /// Fills in the already-open editor with `name`, picks the map's current pin
    /// as the target, and saves. Ends back on the Flights list.
    private func completeEditor(name: String) {
        let nameField = app.textFields["missionNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "missionNameField should exist in the editor")
        nameField.tap()
        // Return dismisses the keyboard so the rows below the field are reachable.
        nameField.typeText(name + "\n")

        let targetRow = app.buttons["targetRow"]
        revealInEditorForm(targetRow, "targetRow")
        targetRow.tap()

        let mapSave = app.buttons["checkpointSaveButton"]
        XCTAssertTrue(mapSave.waitForExistence(timeout: 10), "checkpointSaveButton should appear in the map picker toolbar")
        mapSave.tap()

        XCTAssertTrue(
            app.staticTexts["targetLatitudeLabel"].waitForExistence(timeout: 5),
            "targetLatitudeLabel should appear in the editor after the map picker saves"
        )

        let saveButton = app.buttons["flightEditorSaveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "flightEditorSaveButton should be in the editor toolbar")
        saveButton.tap()
    }

    /// Opens the editor from the toolbar and creates a flight named `name`.
    private func createFlightUI(name: String) {
        openEditorFromToolbar()
        completeEditor(name: name)
    }

    // MARK: - Tests

    func testSafetyDisclaimerShowsOnFirstLaunchAndIsAcknowledgedOnce() throws {
        // Deliberately not `launch()`: this test must start with the disclaimer
        // unacknowledged. `-uiTestsResetStore` only resets the SwiftData store,
        // not UserDefaults, so an explicit NO is passed to override any YES the
        // simulator persisted from an earlier run and keep this test repeatable.
        app.launchArguments += ["-uiTestsResetStore", "-hasAcknowledgedSafetyDisclaimer", "NO"]
        app.launch()

        let disclaimer = app.otherElements["safetyDisclaimerView"]
        XCTAssertTrue(disclaimer.waitForExistence(timeout: 5), "A first launch must present safetyDisclaimerView")

        let acknowledgeButton = app.buttons["safetyDisclaimerAcknowledgeButton"]
        XCTAssertTrue(acknowledgeButton.waitForExistence(timeout: 5), "safetyDisclaimerAcknowledgeButton should be inside the disclaimer")

        // The full-screen cover sits over the Flights list, so its toolbar
        // button must not be reachable until the disclaimer is acknowledged.
        let addButton = app.buttons["addFlightButton"]
        XCTAssertFalse(addButton.isHittable, "addFlightButton must not be hittable behind the safety disclaimer")

        acknowledgeButton.tap()

        XCTAssertFalse(disclaimer.waitForExistence(timeout: 2), "safetyDisclaimerView should be dismissed after tapping I Understand")
        XCTAssertTrue(
            app.otherElements["FlightsListViewRoot"].waitForExistence(timeout: 5),
            "FlightsListViewRoot should be on screen once the disclaimer is acknowledged"
        )
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "addFlightButton should exist once the disclaimer is acknowledged")
        XCTAssertTrue(addButton.isHittable, "addFlightButton should be hittable once the disclaimer is acknowledged")
    }

    func testEmptyStateAndCreateFirstFlightButtonPresentsEditor() throws {
        launch()

        let emptyState = app.otherElements["emptyStateView"]
        XCTAssertTrue(emptyState.waitForExistence(timeout: 5), "A reset store must show emptyStateView")

        let createButton = app.buttons["emptyStateCreateFirstFlightButton"]
        XCTAssertTrue(createButton.exists, "emptyStateCreateFirstFlightButton should be inside the empty state")
        createButton.tap()

        let nameField = app.textFields["missionNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Tapping the empty-state button should push the editor (missionNameField)")

        // B-21: Cancel is the editor's single exit (the system back button is
        // hidden). The editor is pristine here, so no discard dialog appears.
        let cancelButton = app.buttons["flightEditorCancelButton"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 2), "The editor's navigation bar should have flightEditorCancelButton")
        cancelButton.tap()

        XCTAssertTrue(
            app.otherElements["FlightsListViewRoot"].waitForExistence(timeout: 5),
            "FlightsListViewRoot should be back after cancelling the editor"
        )
        XCTAssertTrue(emptyState.waitForExistence(timeout: 5), "emptyStateView should be shown again; nothing was saved")
        XCTAssertFalse(nameField.exists, "missionNameField should be gone once the editor is popped")
    }

    func testAddFlightButtonPresentsEditor() throws {
        launch()

        openEditorFromToolbar()
        completeEditor(name: "Created Via Toolbar")

        waitForCount(1, of: flightRows, "Saving one flight should produce exactly one flightRow_ element")
        XCTAssertFalse(app.otherElements["emptyStateView"].exists, "emptyStateView should be gone once a flight exists")
    }

    func testSwipeToDeleteShowsConfirmationAndDeletes() throws {
        launch(seeded: true)

        waitForCount(2, of: flightRows, "The seeded store should show both UI F1 and UI F2 rows")

        let firstRow = flightRows.element(boundBy: 0)
        firstRow.swipeLeft()

        let deleteButtons = app.buttons.matching(Self.flightRowDeletePredicate())
        let deleteButton = deleteButtons.element(boundBy: 0)
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "Swiping a row left should reveal its flightRowDelete_ button")
        XCTAssertEqual(deleteButtons.count, 1, "Only the swiped row should expose a flightRowDelete_ button")
        deleteButton.tap()

        let confirmAlert = app.alerts["Delete Flight?"]
        XCTAssertTrue(confirmAlert.waitForExistence(timeout: 5), "Tapping the swipe delete should show the Delete Flight? alert")
        confirmAlert.buttons["Delete"].tap()

        XCTAssertFalse(confirmAlert.waitForExistence(timeout: 1), "Delete Flight? alert should be dismissed after confirming")
        waitForCount(1, of: flightRows, "Confirming the delete should drop the flightRow_ count from 2 to 1")
    }

    func testValidationAlertAppearsOnSaveWithoutTarget() throws {
        launch()

        openEditorFromToolbar()

        let saveButton = app.buttons["flightEditorSaveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "flightEditorSaveButton should be in the editor toolbar")
        saveButton.tap()

        let validationAlert = app.alerts["Validation"]
        XCTAssertTrue(validationAlert.waitForExistence(timeout: 5), "Saving with no name and no target should show the Validation alert")
        validationAlert.buttons["OK"].tap()

        XCTAssertFalse(validationAlert.waitForExistence(timeout: 1), "Validation alert should be dismissed after tapping OK")
        XCTAssertTrue(app.textFields["missionNameField"].exists, "The editor should remain on screen after dismissing the alert")
        XCTAssertEqual(flightRows.count, 0, "No flightRow_ element should be created by a rejected save")
    }
}
