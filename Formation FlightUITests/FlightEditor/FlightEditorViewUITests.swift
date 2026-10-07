import XCTest

/// UI tests for the flight editor: field entry, time-type switching, target
/// selection, Go Fly gating and the hand-off to `FlightView`, validation, and
/// create/edit round trips back to the Flights list.
///
/// Every test launches against a fresh in-memory store (`-uiTestsResetStore`).
/// Tests that start from a new flight call `openNewFlightEditor()`; tests that
/// start from an existing flight launch with `-uiTestsSeedFlights` (`UI F1`,
/// `UI F2`, both hack-time). Elements are located by accessibility identifier
/// only; display strings are used solely for system alerts and the
/// confirmation dialog, which have no identifiers.
final class FlightEditorViewUITests: XCTestCase {

    private var app: XCUIApplication!

    /// Matches the list row container of every flight (`flightRow_<uuid>`).
    private let flightRowPredicate = NSPredicate(format: "identifier BEGINSWITH %@", "flightRow_")

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
    private func launch(seeded: Bool = false) {
        app.launchArguments += ["-uiTestsResetStore"]
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
        app.descendants(matching: .any).matching(flightRowPredicate)
    }

    /// The tappable row of the flight named `name`: the `flightRow_` container whose
    /// own label, or any descendant's label, carries the mission name.
    ///
    /// In a SwiftUI `List` the row's `Button` is folded into the cell element, so
    /// a separate `.button` carrying `flightRowButton_<uuid>` is not reliably
    /// exposed; matching the row container and tapping its centre hits the button.
    private func flightRowButton(named name: String) -> XCUIElement {
        // Exact match: "UI F1 Renamed" must not satisfy a lookup for "UI F1".
        let byLabel = NSPredicate(format: "label == %@", name)
        let rows = flightRows
        let direct = rows.matching(byLabel)
        return direct.count > 0 ? direct.firstMatch : rows.containing(byLabel).firstMatch
    }

    /// Waits until `query` matches exactly `count` elements.
    private func waitForCount(_ count: Int, of query: XCUIElementQuery, timeout: TimeInterval = 5, _ message: String) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count == %d", count), object: query)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "\(message) (expected \(count) match(es), found \(query.count))")
    }

    // MARK: - Editor flow

    /// Taps the toolbar add button and waits for the editor's mission name field.
    private func openNewFlightEditor() {
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
    /// Target row and Go Fly button are not queryable until the form is scrolled.
    /// The drag starts near the bottom of the window so it never lands on the
    /// time-entry wheels, which would spin instead of scrolling the form.
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

    /// Types `name` into the mission name field and dismisses the keyboard with Return.
    private func enterMissionName(_ name: String) {
        let nameField = app.textFields["missionNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "missionNameField should exist in the editor")
        nameField.tap()
        nameField.typeText(name + "\n")
    }

    /// Opens the map picker from the Target row, accepts the current pin, and
    /// waits for the coordinate labels to replace the placeholder.
    private func selectTarget() {
        let targetRow = app.buttons["targetRow"]
        revealInEditorForm(targetRow, "targetRow")
        targetRow.tap()

        let mapSave = app.buttons["checkpointSaveButton"]
        XCTAssertTrue(mapSave.waitForExistence(timeout: 10), "checkpointSaveButton should appear in the map picker toolbar")
        mapSave.tap()

        XCTAssertTrue(
            app.staticTexts["targetLatitudeLabel"].waitForExistence(timeout: 5),
            "targetLatitudeLabel should appear in the Target row after the map picker saves"
        )
        XCTAssertTrue(
            app.staticTexts["targetLongitudeLabel"].exists,
            "targetLongitudeLabel should appear in the Target row after the map picker saves"
        )
        XCTAssertFalse(
            app.staticTexts["SelectNewTargetLabel"].exists,
            "SelectNewTargetLabel placeholder should be replaced once a target is selected"
        )
    }

    /// Taps the editor's toolbar save button.
    private func tapEditorSave() {
        let saveButton = app.buttons["flightEditorSaveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "flightEditorSaveButton should be in the editor toolbar")
        saveButton.tap()
    }

    // MARK: - Field entry

    func testMissionNameEntry() throws {
        launch()
        openNewFlightEditor()

        let missionField = app.textFields["missionNameField"]
        missionField.tap()
        missionField.typeText("Operation Sunrise")
        XCTAssertEqual(missionField.value as? String, "Operation Sunrise", "missionNameField should hold the typed mission name")
    }

    func testSwitchTimeTypeToHack() throws {
        launch()
        openNewFlightEditor()

        let segmented = app.segmentedControls["timeTypeSegmentedControl"]
        XCTAssertTrue(segmented.waitForExistence(timeout: 5), "timeTypeSegmentedControl should exist in the editor")
        let totSegment = segmented.buttons["TOT"]
        let hackSegment = segmented.buttons["Hack"]
        XCTAssertTrue(totSegment.isSelected, "A new flight should default to the TOT segment")
        XCTAssertTrue(hackSegment.exists, "Hack segment should exist")
        hackSegment.tap()
        XCTAssertTrue(hackSegment.isSelected, "Hack segment should be selected after tapping it")
        XCTAssertFalse(totSegment.isSelected, "TOT segment should be deselected after choosing Hack")
    }

    // MARK: - Go Fly

    func testGoFlyIsDisabledUntilNameAndTargetAreSet() throws {
        launch()
        openNewFlightEditor()

        let goFly = app.buttons["goFlyButton"]
        revealInEditorForm(goFly, "goFlyButton")
        XCTAssertFalse(goFly.isEnabled, "goFlyButton should be disabled with no mission name and no target")

        enterMissionName("Gated Mission")
        revealInEditorForm(goFly, "goFlyButton")
        XCTAssertFalse(goFly.isEnabled, "goFlyButton should stay disabled while no target is selected")

        selectTarget()
        revealInEditorForm(goFly, "goFlyButton")
        XCTAssertTrue(goFly.isEnabled, "goFlyButton should become enabled once a name and target are set")
    }

    func testSelectTargetAndGoFly() throws {
        launch()
        openNewFlightEditor()

        enterMissionName("Go Fly Mission")
        selectTarget()

        let goFly = app.buttons["goFlyButton"]
        revealInEditorForm(goFly, "goFlyButton")
        XCTAssertTrue(goFly.isEnabled, "goFlyButton should be enabled with a name and target")
        goFly.tap()

        let flightRoot = app.otherElements["flightViewRoot"]
        XCTAssertTrue(flightRoot.waitForExistence(timeout: 5), "Go Fly should present FlightView (flightViewRoot)")
        XCTAssertFalse(app.staticTexts["flightViewFallbackMessage"].exists, "Go Fly must not show the fallback cover for a valid mission")

        let endFlight = app.buttons["endFlightButton"]
        XCTAssertTrue(endFlight.waitForExistence(timeout: 5), "endFlightButton should be in FlightView's bottom bar")
        XCTAssertTrue(app.buttons["editTOTButton"].exists, "A TOT mission should show editTOTButton")
        endFlight.tap()

        // The confirmation dialog is a system action sheet; its buttons carry
        // their titles only.
        let dialog = app.sheets.firstMatch
        XCTAssertTrue(dialog.waitForExistence(timeout: 5), "Tapping End Flight should show the End Flight? confirmation dialog")
        let confirm = dialog.buttons["End Flight"]
        XCTAssertTrue(confirm.exists, "The confirmation dialog should offer an End Flight button")
        confirm.tap()

        // The editor's Form may still be scrolled to the Go Fly row, which puts the
        // mission-name cell out of the virtualized list, so check the navigation bar.
        XCTAssertTrue(
            app.navigationBars["Flight Editor"].waitForExistence(timeout: 5),
            "Confirming End Flight should dismiss FlightView and return to the editor"
        )
        XCTAssertFalse(flightRoot.exists, "flightViewRoot should be gone after ending the flight")
    }

    // MARK: - Validation

    func testValidationError_MissingMissionTitle_WhenTargetSelected() throws {
        launch()
        openNewFlightEditor()

        selectTarget()
        tapEditorSave()

        let validationAlert = app.alerts["Validation"]
        XCTAssertTrue(validationAlert.waitForExistence(timeout: 5), "Saving with a target but no mission name should show the Validation alert")
        validationAlert.buttons["OK"].tap()
        XCTAssertFalse(validationAlert.waitForExistence(timeout: 1), "Validation alert should be dismissed after tapping OK")
        XCTAssertEqual(flightRows.count, 0, "A rejected save must not create a flightRow_ element")
    }

    func testValidationError_MissingTarget_WhenTitleEntered() throws {
        launch()
        openNewFlightEditor()

        enterMissionName("Test Mission")
        tapEditorSave()

        let validationAlert = app.alerts["Validation"]
        XCTAssertTrue(validationAlert.waitForExistence(timeout: 5), "Saving with a name but no target should show the Validation alert")
        validationAlert.buttons["OK"].tap()
        XCTAssertFalse(validationAlert.waitForExistence(timeout: 1), "Validation alert should be dismissed after tapping OK")
        XCTAssertEqual(flightRows.count, 0, "A rejected save must not create a flightRow_ element")
    }

    // MARK: - Create and edit round trips

    func testCreateFlightAndVerifyInList() throws {
        launch()
        openNewFlightEditor()

        enterMissionName("Mission Alpha")
        selectTarget()
        tapEditorSave()

        waitForCount(1, of: flightRows, "Saving a new flight should produce exactly one flightRow_ element")
        XCTAssertTrue(
            flightRowButton(named: "Mission Alpha").waitForExistence(timeout: 5),
            "The new flightRowButton_ should be labelled with the saved mission name"
        )
    }

    func testEditExistingFlightAndVerifyUpdates() throws {
        launch(seeded: true)

        waitForCount(2, of: flightRows, "The seeded store should show both UI F1 and UI F2 rows")

        let originalRow = flightRowButton(named: "UI F1")
        XCTAssertTrue(originalRow.waitForExistence(timeout: 5), "A flightRowButton_ labelled UI F1 should be in the seeded list")
        originalRow.tap()

        let missionField = app.textFields["missionNameField"]
        XCTAssertTrue(missionField.waitForExistence(timeout: 5), "Tapping a row should push the editor (missionNameField)")
        let originalName = "UI F1"
        XCTAssertEqual(missionField.value as? String, originalName, "The editor should be pre-filled with the seeded mission name")

        // Place the caret after the existing text (tapping the far right of a
        // short field lands past its last character), delete it, and retype.
        missionField.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        missionField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: originalName.count))
        missionField.typeText("UI F1 Renamed\n")
        XCTAssertEqual(missionField.value as? String, "UI F1 Renamed", "missionNameField should hold the new name")

        // Seed flights are hack-time; switch this one to TOT.
        let segmented = app.segmentedControls["timeTypeSegmentedControl"]
        XCTAssertTrue(segmented.waitForExistence(timeout: 5), "timeTypeSegmentedControl should exist in the editor")
        let hackSegment = segmented.buttons["Hack"]
        let totSegment = segmented.buttons["TOT"]
        XCTAssertTrue(hackSegment.isSelected, "A seeded hack-time flight should open with the Hack segment selected")
        totSegment.tap()
        XCTAssertTrue(totSegment.isSelected, "TOT segment should be selected after tapping it")

        tapEditorSave()

        XCTAssertTrue(
            flightRowButton(named: "UI F1 Renamed").waitForExistence(timeout: 5),
            "The edited flight's flightRowButton_ should show the renamed mission"
        )
        XCTAssertFalse(flightRowButton(named: originalName).exists, "No flightRowButton_ should still be labelled UI F1")
        XCTAssertEqual(flightRows.count, 2, "Editing must not change the number of flightRow_ elements")
        XCTAssertTrue(flightRowButton(named: "UI F2").exists, "The untouched UI F2 row should still be present")
    }
}
