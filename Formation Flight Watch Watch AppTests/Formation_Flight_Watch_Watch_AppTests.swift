//
//  Formation_Flight_Watch_Watch_AppTests.swift
//  Formation Flight Watch Watch AppTests
//
//  F-02: the watch app's shell over `WatchFlightState`. The state machine, staleness and
//  haptic rules themselves are covered by the package's `WatchFlightStateTests`.
//

// Compiled only once the target links FormationFlightCore (see Formation_Flight_WatchApp.swift).
#if canImport(FormationFlightCore)
import Foundation
import Testing
import WatchKit
import FormationFlightCore
@testable import Formation_Flight_Watch_Watch_App

@MainActor
struct WatchFlightModelTests {
    private static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func snapshot(at offset: TimeInterval = 0, isFixStale: Bool = false) -> FlightSnapshot {
        let sentAt = Self.start.addingTimeInterval(offset)
        return FlightSnapshot(sentAt: sentAt, missionName: "RAZOR 1", missionType: .tot,
                              tot: Self.start.addingTimeInterval(93), hackTime: nil, isHackPending: false,
                              fixTime: sentAt.addingTimeInterval(isFixStale ? -20 : 0), distance: 1000,
                              groundSpeed: 10, track: nil, bearing: nil, turnDirection: nil,
                              isFixStale: isFixStale, yellowTolerance: 5, redTolerance: 10,
                              speedUnit: .kts, distanceUnit: .nm)
    }

    @Test func playsTheCueHapticOnce() {
        var played: [CueHaptic] = []
        let model = WatchFlightModel(clock: { Self.start }, playHaptic: { played.append($0) })
        model.receive(.snapshot(snapshot()))
        model.receive(.callout(Callout(.turnIn(.right)), emittedAt: Self.start))
        model.receive(.callout(Callout(.turnIn(.right)), emittedAt: Self.start))
        #expect(played == [.start])
    }

    @Test func haptics() {
        #expect(CueHaptic.click.hapticType == .click)
        #expect(CueHaptic.directionUp.hapticType == .directionUp)
        #expect(CueHaptic.failure.hapticType == .failure)
    }

    @Test func activeDisplay() {
        var state = WatchFlightState()
        state.receive(snapshot())
        let display = WatchFlightDisplay(state: state, now: Self.start)
        #expect(display.phase == .active)
        #expect(display.countdownText == "1:33")
        #expect(display.deltaText == "+0:07")
        #expect(display.relationWord == "LATE")
        #expect(display.status == .bad)
        #expect(display.eteText == "1:40")
        #expect(display.currentSpeedText == "19 kt")
    }

    @Test func staleDisplayBlanksMeasuredReadouts() {
        var state = WatchFlightState()
        state.receive(snapshot())
        let now = Self.start.addingTimeInterval(42)
        let display = WatchFlightDisplay(state: state, now: now)
        #expect(display.isStale)
        #expect(display.deltaText == "--:--")
        #expect(display.relationWord == nil)
        #expect(display.eteText == "--:--")
        #expect(display.currentSpeedText == "--")
        #expect(display.requiredSpeedText == "--")
        // The ToT countdown keeps running: it counts to a fixed time.
        #expect(display.countdownText == "0:51")
        #expect(display.staleInstruction == "Open Formation Flight on iPhone")
        #expect(display.staleAgeText(at: now) == "Updated 0:42 ago")
    }

    @Test func alwaysOnCountdownIsMinutesOnly() {
        var state = WatchFlightState()
        state.receive(snapshot())
        #expect(WatchFlightDisplay(state: state, now: Self.start).countdownMinutesText == "2 min")
        #expect(WatchFlightDisplay(state: state, now: Self.start.addingTimeInterval(40)).countdownMinutesText == "<1 min")
    }
}
#endif
