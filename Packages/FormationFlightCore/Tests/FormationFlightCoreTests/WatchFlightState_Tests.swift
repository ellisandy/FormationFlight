import Foundation
import Testing
@testable import FormationFlightCore

/// The watch companion's state machine, staleness and haptic rules (F-02).
@Suite("WatchFlightState")
struct WatchFlightStateTests {
    private static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func at(_ offset: TimeInterval) -> Date { Self.start.addingTimeInterval(offset) }

    private func snapshot(at offset: TimeInterval = 0,
                          isHackPending: Bool = false,
                          fixAge: TimeInterval? = 0,
                          isFixStale: Bool = false,
                          isEnded: Bool = false) -> FlightSnapshot {
        let sentAt = at(offset)
        return FlightSnapshot(sentAt: sentAt, missionName: "RAZOR 1",
                              missionType: isHackPending ? .hackTime : .tot,
                              tot: isHackPending ? nil : at(100), hackTime: isHackPending ? 300 : nil,
                              isHackPending: isHackPending,
                              fixTime: fixAge.map { sentAt.addingTimeInterval(-$0) }, distance: 1000,
                              groundSpeed: 10, track: nil, bearing: nil, turnDirection: nil,
                              isFixStale: isFixStale, yellowTolerance: 5, redTolerance: 10,
                              speedUnit: .kts, distanceUnit: .nm, isEnded: isEnded)
    }

    // MARK: Phases

    @Test("With no snapshot the watch is idle")
    func idle() {
        let state = WatchFlightState()
        #expect(state.phase(at: Self.start) == .idle)
        #expect(state.timing(at: Self.start) == nil)
    }

    @Test("A live snapshot is active, a pending hack is awaiting hack")
    func activeAndAwaitingHack() {
        var state = WatchFlightState()
        state.receive(snapshot())
        #expect(state.phase(at: at(1)) == .active)

        var hack = WatchFlightState()
        hack.receive(snapshot(isHackPending: true, fixAge: nil))
        #expect(hack.phase(at: at(1)) == .awaitingHack)
    }

    @Test("The watch ticks locally from the snapshot on its own clock")
    func ticksLocally() throws {
        var state = WatchFlightState()
        state.receive(snapshot())
        let timing = try #require(state.timing(at: at(3.5)))
        #expect(timing.timeToToT == 97)
    }

    @Test("Silence from the phone beyond the threshold is STALE, exactly at it is not")
    func phoneSilent() {
        var state = WatchFlightState()
        state.receive(snapshot())
        #expect(state.phase(at: at(TimingEngine.staleFixThreshold)) == .active)
        #expect(state.phase(at: at(TimingEngine.staleFixThreshold + 1)) == .stale(.phoneSilent(since: Self.start)))
    }

    @Test("A stale fix from a phone still talking is STALE for the fix")
    func fixLost() {
        var state = WatchFlightState()
        state.receive(snapshot(fixAge: 20, isFixStale: true))
        #expect(state.phase(at: at(1)) == .stale(.fixLost(since: at(-20))))
    }

    @Test("A stale pending hack is STALE, not awaiting hack")
    func staleHack() {
        var state = WatchFlightState()
        state.receive(snapshot(isHackPending: true, fixAge: nil))
        #expect(state.phase(at: at(16)) == .stale(.phoneSilent(since: Self.start)))
    }

    @Test("An ended flight shows ended briefly, then idle")
    func endedThenIdle() {
        var state = WatchFlightState()
        state.receive(snapshot())
        state.receive(snapshot(at: 1, isEnded: true))
        #expect(state.phase(at: at(2)) == .ended)
        #expect(state.phase(at: at(1 + WatchFlightState.endedDisplayDuration)) == .idle)
    }

    @Test("An abandoned flight (phone silent for half an hour) returns to idle")
    func abandoned() {
        var state = WatchFlightState()
        state.receive(snapshot())
        #expect(state.phase(at: at(WatchFlightState.abandonedAfter)) == .stale(.phoneSilent(since: Self.start)))
        #expect(state.phase(at: at(WatchFlightState.abandonedAfter + 1)) == .idle)
    }

    // MARK: Ordering

    @Test("Only a strictly newer snapshot wins")
    func newestWins() {
        var state = WatchFlightState()
        var result = state.receive(snapshot(at: 5))
        #expect(result)
        result = state.receive(snapshot(at: 3))
        #expect(!result)
        result = state.receive(snapshot(at: 5))
        #expect(!result)
        #expect(state.snapshot?.sentAt == at(5))
        result = state.receive(snapshot(at: 6))
        #expect(result)
        #expect(state.snapshot?.sentAt == at(6))
    }

    @Test("A late application context with the ended flight does not resurrect it")
    func lateContextAfterEnd() {
        var state = WatchFlightState()
        state.receive(snapshot(at: 10, isEnded: true))
        let result = state.receive(snapshot(at: 8))
        #expect(!result)
        #expect(state.phase(at: at(11)) == .ended)
    }

    @Test("A new flight after an ended one is taken")
    func newFlightAfterEnd() {
        var state = WatchFlightState()
        state.receive(snapshot(at: 0, isEnded: true))
        state.receive(snapshot(at: 60))
        #expect(state.phase(at: at(61)) == .active)
    }

    // MARK: Callouts and haptics

    @Test("A fresh cue plays its haptic and shows its banner for the banner duration")
    func freshCue() {
        var state = WatchFlightState()
        state.receive(snapshot(at: 10))
        let cue = Callout(.turnIn(.left))
        let result = state.receive(cue, emittedAt: at(10), at: at(10.5))
        #expect(result == .start)
        #expect(state.banner(at: at(11)) == cue)
        #expect(state.banner(at: at(10.5 + WatchFlightState.calloutBannerDuration)) == nil)
    }

    @Test("A cue older than the limit is dropped, banner and haptic both")
    func oldCue() {
        var state = WatchFlightState()
        state.receive(snapshot(at: 10))
        var result = state.receive(Callout(.rollOut), emittedAt: at(10), at: at(10 + WatchFlightState.maxCalloutAge))
        #expect(result == .stop)
        result = state.receive(Callout(.gpsLost), emittedAt: at(11), at: at(11 + WatchFlightState.maxCalloutAge + 0.1))
        #expect(result == nil)
        // The late GPS cue did not replace the roll-out banner.
        #expect(state.banner(at: at(15)) == Callout(.rollOut))
    }

    @Test("Duplicates and out-of-order cues stay silent")
    func duplicates() {
        var state = WatchFlightState()
        state.receive(snapshot(at: 10))
        let cue = Callout(.countdown(secondsToToT: 10))
        var result = state.receive(cue, emittedAt: at(10), at: at(10))
        #expect(result == .notification)
        result = state.receive(cue, emittedAt: at(10), at: at(10.2))
        #expect(result == nil)
        result = state.receive(Callout(.countdown(secondsToToT: 30)), emittedAt: at(9), at: at(10.3))
        #expect(result == nil)
        #expect(state.banner(at: at(10.3)) == cue)
    }

    @Test("No haptic once the phone has gone silent, or with no flight, or after the end")
    func silentWhenStale() {
        var none = WatchFlightState()
        var result = none.receive(Callout(.gpsLost), emittedAt: Self.start, at: Self.start)
        #expect(result == nil)

        var silent = WatchFlightState()
        silent.receive(snapshot())
        result = silent.receive(Callout(.gpsLost), emittedAt: at(16), at: at(16))
        #expect(result == nil)

        var ended = WatchFlightState()
        ended.receive(snapshot(isEnded: true))
        result = ended.receive(Callout(.countdown(secondsToToT: 0)), emittedAt: Self.start, at: Self.start)
        #expect(result == nil)
    }

    @Test("GPS lost still taps the wrist even though its snapshot has a stale fix")
    func gpsLostWithStaleFix() {
        var state = WatchFlightState()
        state.receive(snapshot(at: 20, fixAge: 16, isFixStale: true))
        let result = state.receive(Callout(.gpsLost), emittedAt: at(20), at: at(20.4))
        #expect(result == .failure)
        #expect(state.banner(at: at(21)) == Callout(.gpsLost))
    }

    @Test("The end of the flight clears the banner")
    func endClearsBanner() {
        var state = WatchFlightState()
        state.receive(snapshot(at: 10))
        _ = state.receive(Callout(.rollOut), emittedAt: at(10), at: at(10))
        state.receive(snapshot(at: 11, isEnded: true))
        #expect(state.banner(at: at(11)) == nil)
    }

    @Test("Messages feed the same rules")
    func messages() {
        var state = WatchFlightState()
        let result = state.receive(.snapshot(snapshot()), at: Self.start)
        #expect(result == nil)
        let haptic = state.receive(.callout(Callout(.drift(seconds: 7, relation: .late)), emittedAt: Self.start),
                                   at: at(1))
        #expect(haptic == .directionUp)
    }
}
