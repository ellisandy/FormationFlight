//
//  Formation_Flight_Watch_Watch_AppUITests.swift
//  Formation Flight Watch Watch AppUITests
//
//  F-02: the watch companion's screens, driven by the app's UI-test scenarios
//  (`-uiTestScenario <name>`, see `WatchScenario`): there is no iPhone in a UI test, so the
//  app plays a fixed flight built relative to launch time instead of using WatchConnectivity.
//

import XCTest

/// The app's accessibility identifiers (`WatchAccessibilityID`); the UI test target cannot
/// import the app, so they are repeated here.
private enum WatchID {
    static let idleScreen = "watch.screen.idle"
    static let endedScreen = "watch.screen.ended"
    static let awaitingHackScreen = "watch.screen.awaitingHack"
    static let activeScreen = "watch.screen.active"
    static let staleScreen = "watch.screen.stale"
    static let idleMessage = "watch.idle.message"
    static let endedMessage = "watch.ended.message"
    static let awaitingHackTitle = "watch.awaitingHack.title"
    static let awaitingHackMessage = "watch.awaitingHack.message"
    static let hackTime = "watch.hackTime"
    static let banner = "watch.banner"
    static let countdown = "watch.countdown"
    static let delta = "watch.delta"
    static let ete = "watch.ete"
    static let requiredGroundSpeed = "watch.reqGS"
    static let groundSpeed = "watch.gs"
    static let staleBadge = "watch.stale.badge"
    static let staleInstruction = "watch.stale.instruction"
    static let staleAge = "watch.stale.age"
}

@MainActor
final class WatchFlightUITests: XCTestCase {
    private var app: XCUIApplication!

    /// Long enough for a cold launch on a busy simulator; elements normally appear in under 1 s.
    private let launchTimeout: TimeInterval = 15

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app?.terminate()
        app = nil
    }

    // MARK: Helpers

    private func launch(_ scenario: String?, extraArguments: [String] = []) {
        if let scenario {
            app.launchArguments = ["-uiTestScenario", scenario]
        }
        app.launchArguments += extraArguments
        app.launch()
    }

    /// Any element with `identifier`, whatever SwiftUI exposes it as.
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @discardableResult
    private func waitFor(_ identifier: String, timeout: TimeInterval? = nil,
                         file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let element = element(identifier)
        XCTAssertTrue(element.waitForExistence(timeout: timeout ?? launchTimeout),
                      "\(identifier) did not appear", file: file, line: line)
        return element
    }

    private func value(of identifier: String) -> String? {
        element(identifier).value as? String
    }

    // MARK: Launch

    /// A plain launch (no scenario, no phone running a flight) shows the idle screen.
    func testLaunchWithoutScenarioShowsIdle() {
        launch(nil)
        let message = waitFor(WatchID.idleMessage)
        XCTAssertEqual(message.label, "Start a flight on your iPhone")
    }

    func testLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launchArguments = ["-uiTestScenario", "idle"]
            app.launch()
        }
    }

    // MARK: Scenarios

    func testIdle() {
        launch("idle")
        waitFor(WatchID.idleScreen)
        XCTAssertEqual(waitFor(WatchID.idleMessage).label, "Start a flight on your iPhone")
        XCTAssertFalse(element(WatchID.countdown).exists)
        XCTAssertFalse(element(WatchID.delta).exists)
    }

    func testAwaitingHack() {
        launch("awaitingHack")
        waitFor(WatchID.awaitingHackScreen)
        XCTAssertEqual(waitFor(WatchID.awaitingHackTitle).label, "AWAITING HACK")
        XCTAssertEqual(element(WatchID.awaitingHackMessage).label, "Press Hack! on iPhone")
        XCTAssertEqual(value(of: WatchID.hackTime), "4:30")
        // No ToT yet, so nothing to count down to and no Δ.
        XCTAssertFalse(element(WatchID.countdown).exists)
        XCTAssertFalse(element(WatchID.delta).exists)
    }

    func testOnTime() {
        launch("onTime")
        waitFor(WatchID.activeScreen)
        let delta = waitFor(WatchID.delta)
        // The pretend phone ticks on its own second boundaries, so Δ can read ±1 s at the
        // instant of the query; all three readings are inside the 5 s tolerance.
        let onTimeLabels = ["On time", "Early by 1 second", "Late by 1 second"]
        XCTAssertTrue(onTimeLabels.contains(delta.label), "unexpected Δ label \(delta.label)")
        XCTAssertTrue(element(WatchID.countdown).exists)
        XCTAssertEqual(element(WatchID.ete).label, "ETE")
        XCTAssertEqual(value(of: WatchID.requiredGroundSpeed)?.hasSuffix("kt"), true)
        XCTAssertEqual(value(of: WatchID.groundSpeed), "194 kt")
        XCTAssertFalse(element(WatchID.staleBadge).exists)
    }

    func testEarlyTurningShowsTurnCaption() {
        launch("early")
        waitFor(WatchID.activeScreen)
        let delta = waitFor(WatchID.delta)
        XCTAssertTrue(delta.label.hasPrefix("Early by"), "Δ label \(delta.label)")
        // The ETE row's value carries the modelled turn caption, e.g. "17:12, TURN 0:45 L".
        let ete = value(of: WatchID.ete) ?? ""
        XCTAssertTrue(ete.contains(", TURN "), "ETE value \(ete)")
    }

    func testLateWithCallout() {
        launch("lateWithCallout")
        waitFor(WatchID.activeScreen)
        let delta = waitFor(WatchID.delta)
        XCTAssertTrue(delta.label.hasPrefix("Late by"), "Δ label \(delta.label)")
        // The scenario re-sends the cue every 3 s, inside the 4 s banner time, so it stays up.
        let banner = waitFor(WatchID.banner)
        XCTAssertTrue(banner.label.contains("Increase, 196."), "banner label \(banner.label)")
    }

    func testStalePhoneSilentHidesMeasuredReadouts() {
        launch("stalePhoneSilent")
        waitFor(WatchID.staleScreen)
        XCTAssertEqual(waitFor(WatchID.staleBadge).label, "STALE")
        XCTAssertEqual(element(WatchID.staleInstruction).label, "Open Formation Flight on iPhone")
        let age = element(WatchID.staleAge).label
        XCTAssertTrue(age.hasPrefix("Updated") && age.hasSuffix("ago"), "age label \(age)")
        // Nothing measured is shown as if live.
        XCTAssertFalse(element(WatchID.delta).exists)
        XCTAssertEqual(value(of: WatchID.ete), "--:--")
        XCTAssertEqual(value(of: WatchID.requiredGroundSpeed), "--")
        XCTAssertEqual(value(of: WatchID.groundSpeed), "--")
        // The ToT countdown keeps running: it counts to a fixed time.
        XCTAssertTrue(element(WatchID.countdown).exists)
    }

    func testStaleGPSLost() {
        launch("staleGPSLost")
        waitFor(WatchID.staleScreen)
        XCTAssertEqual(waitFor(WatchID.staleBadge).label, "STALE")
        XCTAssertEqual(element(WatchID.staleInstruction).label, "Waiting for GPS on iPhone")
        XCTAssertFalse(element(WatchID.delta).exists)
        XCTAssertEqual(value(of: WatchID.groundSpeed), "--")
    }

    func testEnded() {
        launch("ended")
        waitFor(WatchID.endedScreen)
        XCTAssertEqual(waitFor(WatchID.endedMessage).label, "Flight ended")
        XCTAssertFalse(element(WatchID.countdown).exists)
    }

    // MARK: Live behaviour

    /// The watch ticks on its own clock: the countdown changes within a couple of seconds.
    func testCountdownTicks() {
        launch("onTime")
        let countdown = waitFor(WatchID.countdown)
        let first = countdown.label
        XCTAssertTrue(first.hasPrefix("Time to ToT"), "countdown label \(first)")
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", first),
                                                object: countdown)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed,
                       "countdown stuck at \(first)")
    }

    /// A callout arriving after launch shows its banner.
    func testCalloutArrivesAfterLaunch() {
        launch("calloutAfterLaunch")
        waitFor(WatchID.activeScreen)
        XCTAssertFalse(element(WatchID.banner).exists, "banner before the callout was sent")
        let banner = waitFor(WatchID.banner, timeout: 10)
        XCTAssertTrue(banner.label.contains("Roll out now."), "banner label \(banner.label)")
    }

    /// When the phone stops sending, the live screen turns STALE on its own and Δ goes away.
    func testGoesStaleWhenThePhoneFallsSilent() {
        launch("goesStale")
        waitFor(WatchID.delta)
        waitFor(WatchID.staleBadge, timeout: 20)
        XCTAssertEqual(element(WatchID.staleInstruction).label, "Open Formation Flight on iPhone")
        XCTAssertFalse(element(WatchID.delta).exists)
    }

    // MARK: Accessibility

    func testDeltaVoiceOverLabelSaysTheSide() {
        launch("lateWithCallout")
        let delta = waitFor(WatchID.delta)
        XCTAssertTrue(delta.label.hasPrefix("Late by"), "Δ label \(delta.label)")
        XCTAssertTrue(delta.label.contains("second"), "Δ label \(delta.label)")
    }

    /// At an accessibility text size the main readouts are still on screen or a scroll away.
    func testAccessibilityTextSizeKeepsReadoutsReachable() {
        launch("early", extraArguments: ["-UIPreferredContentSizeCategoryName",
                                         "UICTContentSizeCategoryAccessibilityXL"])
        let countdown = waitFor(WatchID.countdown)
        XCTAssertTrue(countdown.isHittable)
        XCTAssertTrue(waitFor(WatchID.delta).exists)
        for identifier in [WatchID.ete, WatchID.requiredGroundSpeed, WatchID.groundSpeed] {
            let readout = element(identifier)
            XCTAssertTrue(readout.exists, "\(identifier) missing")
            var swipes = 0
            while !readout.isHittable && swipes < 8 {
                app.swipeUp()
                swipes += 1
            }
            XCTAssertTrue(readout.isHittable, "\(identifier) not reachable by scrolling")
        }
    }
}
