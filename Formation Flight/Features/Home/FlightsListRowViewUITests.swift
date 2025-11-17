//
//  FlightsListRowViewUITests.swift
//  Formation FlightUITests
//
//  Created by Jack Ellis on 12/15/23.
//

import XCTest

final class FlightsListRowViewUITests: XCTestCase {
    
    var app: XCUIApplication!
    private let flightsListIdentifier = "FlightsListTable"
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // If you have launch arguments to make tests deterministic, add them here.
        // app.launchArguments += ["-UITests", "1"]
        app.launch()
        // Wait for root to appear
        XCTAssertTrue(app.otherElements["FlightsListViewRoot"].waitForExistence(timeout: 10))
        _ = app.otherElements["FlightsListViewRoot"].waitForHittable(timeout: 2)
    }
    
    // Helper: ensure at least N rows exist by creating flights if needed
    private func ensureAtLeastRows(_ count: Int) {
        let root = app.otherElements["FlightsListViewRoot"]
        let list = resolveFlightsList(in: root) ?? root
        // If no rows, we’ll tap "Add" and save via the editor (must fill required fields).
        // Your editor requires non-empty title and at least one checkpoint to enable Save.
        // To keep UI tests simple, we’ll create flights only when an empty-state exists,
        // and verify behaviors that don’t require saving (like delete confirmation visibility).
        if !(list.exists) || list.cells.count >= count { return }
        
        // If empty state exists, just create placeholder flights by opening editor and canceling
        // since save requires checkpoints; we’ll focus row UI behaviors that don’t require saved data.
        // If you want to truly insert, consider exposing a debug-only shortcut to preseed data in UI tests.
        while list.cells.count < count {
            let add = app.buttons["addFlightButton"]
            if add.waitForExistence(timeout: 2) {
                add.tap()
                // In editor, try to save minimal valid data (title + one checkpoint)
                let titleField = app.textFields["missionTitleField"]
                if titleField.waitForExistence(timeout: 3) {
                    titleField.tap()
                    titleField.typeText("UI Row Test \(UUID().uuidString.prefix(4))")
                }
                
                // Add a checkpoint
                let newCP = app.buttons["newCheckpointButton"]
                if newCP.waitForExistence(timeout: 3) {
                    newCP.tap()
                    let sheet = app.otherElements["checkpointSheet"]
                    if sheet.waitForExistence(timeout: 3) {
                        let nameField = app.textFields["checkpointNameField"]
                        if nameField.waitForExistence(timeout: 3) {
                            nameField.tap()
                            nameField.typeText("CP \(Int.random(in: 1...999))")
                        }
                        let saveCP = app.buttons["checkpointSaveButton"]
                        if saveCP.waitForExistence(timeout: 2) { saveCP.tap() }
                    }
                }
                
                // Now Save editor
                let save = app.navigationBars.buttons["Save"]
                if save.waitForExistence(timeout: 3) {
                    save.tap()
                } else {
                    // If something failed, cancel to avoid hanging
                    let cancel = app.navigationBars.buttons["Cancel"]
                    if cancel.exists { cancel.tap() }
                }
            } else {
                break
            }
        }
    }
    
    func test_tappingRowButtonPresentsEditor() throws {
        ensureAtLeastRows(1)
        let root = app.otherElements["FlightsListViewRoot"]
        XCTAssertTrue(root.waitForExistence(timeout: 10))
        guard let list = resolveFlightsList(in: root) else {
            XCTFail("Flights list should exist")
            return
        }
        
        let firstCell = list.cells.element(boundBy: 0)
        XCTAssertTrue(firstCell.waitForExistence(timeout: 3), "First flight row should exist")
        
        // Tap the button inside the row (we can also tap the cell content if needed)
        // Prefer the button identifier if present; otherwise tap the cell.
        let rowButton = firstCell.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'flightRowButton_'")).firstMatch
        if rowButton.exists {
            rowButton.tap()
        } else {
            firstCell.tap()
        }
        
        // Editor sheet should appear; we can detect by a known field or toolbar title
        let saveButton = app.navigationBars.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Editor should be presented after tapping row")
        
        // Dismiss the editor to clean up
        let cancelButton = app.navigationBars.buttons["Cancel"]
        if cancelButton.exists { cancelButton.tap() }
    }
    
    func test_swipeRowShowsDeleteAndCancelConfirmationKeepsRow() throws {
        ensureAtLeastRows(2)
        let root = app.otherElements["FlightsListViewRoot"]
        XCTAssertTrue(root.waitForExistence(timeout: 10))
        guard let list = resolveFlightsList(in: root) else {
            XCTFail("Flights list should exist")
            return
        }
        
        let initialCount = list.cells.count
        let firstCell = list.cells.element(boundBy: 0)
        XCTAssertTrue(firstCell.exists)
        
        // Swipe to reveal delete
        firstCell.swipeLeft()
        // Small delay to allow the action to attach
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        
        // Search globally for our custom-identified delete, then fall back to system "Delete"
        var deleteButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'flightRowDelete_'")).firstMatch
        if !deleteButton.exists {
            deleteButton = list.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'flightRowDelete_'")).firstMatch
        }
        if !deleteButton.exists {
            deleteButton = app.buttons["Delete"]
        }
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3), "Delete button not found after swipe")
        deleteButton.tap()
        
        // Confirmation alert should appear
        let alert = app.alerts["Delete Flight?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3), "Delete confirmation alert should appear")
        
        // Cancel deletion
        let cancel = alert.buttons["Cancel"]
        XCTAssertTrue(cancel.exists)
        cancel.tap()
        
        // Row count should remain the same
        XCTAssertEqual(list.cells.count, initialCount, "Canceling delete should keep the row")
    }
    
    func test_swipeRowShowsDeleteAndConfirmRemovesRow() throws {
        ensureAtLeastRows(2)
        let root = app.otherElements["FlightsListViewRoot"]
        XCTAssertTrue(root.waitForExistence(timeout: 10))
        guard let list = resolveFlightsList(in: root) else {
            XCTFail("Flights list should exist")
            return
        }
        
        let initialCount = list.cells.count
        XCTAssertGreaterThanOrEqual(initialCount, 1)
        
        let firstCell = list.cells.element(boundBy: 0)
        XCTAssertTrue(firstCell.exists)
        
        firstCell.swipeLeft()
        // Small delay to allow the action to attach
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        
        // Search globally for our custom-identified delete, then fall back to system "Delete"
        var deleteButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'flightRowDelete_'")).firstMatch
        if !deleteButton.exists {
            deleteButton = list.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'flightRowDelete_'")).firstMatch
        }
        if !deleteButton.exists {
            deleteButton = app.buttons["Delete"]
        }
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3), "Delete button not found after swipe")
        deleteButton.tap()
        
        // Confirm deletion
        let alert = app.alerts["Delete Flight?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        
        let confirm = alert.buttons["Delete"]
        XCTAssertTrue(confirm.exists)
        confirm.tap()
        
        // Expect one fewer row, or empty state if we deleted the last item
        if initialCount > 1 {
            XCTAssertTrue(list.waitForExistence(timeout: 3))
            XCTAssertEqual(list.cells.count, initialCount - 1, "Confirming delete should remove the row")
        } else {
            let emptyState = app.otherElements["emptyStateView"]
            XCTAssertTrue(emptyState.waitForExistence(timeout: 3), "Empty state should appear after deleting the last flight")
        }
    }
}

extension XCUIElement {
    func waitForHittable(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if self.exists && self.isHittable { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return false
    }
}

private extension FlightsListRowViewUITests {
    /// Resolves the flights list as either a table or a collection view scoped to the root.
    func resolveFlightsList(in root: XCUIElement, timeout: TimeInterval = 10) -> XCUIElement? {
        let table = root.tables[flightsListIdentifier]
        if table.waitForExistence(timeout: timeout) { return table }
        let collection = root.collectionViews[flightsListIdentifier]
        if collection.waitForExistence(timeout: timeout) { return collection }
        // Fallback to first match if identifier wasn't set in app code yet
        let firstTable = root.tables.firstMatch
        if firstTable.waitForExistence(timeout: 2) { return firstTable }
        let firstCollection = root.collectionViews.firstMatch
        if firstCollection.waitForExistence(timeout: 2) { return firstCollection }
        return nil
    }
}
