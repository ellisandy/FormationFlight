import Foundation
import Testing
@testable import Formation_Flight
import FormationFlightCore

/// Records what the mirror hands WatchConnectivity.
@MainActor
private final class FakeWatchSession: WatchSessioning {
    struct ContextFailed: Error {}

    var availability: WatchSessionAvailability = .available
    var isReachable = true
    var failContext = false
    var stateDidChange: (@MainActor () -> Void)?

    private(set) var messages: [WatchMessage] = []
    private(set) var contexts: [WatchMessage] = []

    func sendMessage(_ message: WatchMessage) { messages.append(message) }

    func updateApplicationContext(_ message: WatchMessage) throws {
        if failContext { throw ContextFailed() }
        contexts.append(message)
    }

    /// Simulates activation completing (or the watch state changing).
    func change(availability: WatchSessionAvailability, isReachable: Bool? = nil) {
        self.availability = availability
        if let isReachable { self.isReachable = isReachable }
        stateDidChange?()
    }
}

/// When the watch mirror sends messages and application contexts (F-02).
@Suite("WatchMirror")
@MainActor
struct WatchMirrorTests {
    private static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// Closing at 10 m/s so Δ stays constant: nothing visible changes from tick to tick.
    private func steady(at offset: TimeInterval, isEnded: Bool = false) -> FlightSnapshot {
        let sentAt = Self.start.addingTimeInterval(offset)
        return FlightSnapshot(sentAt: sentAt, missionName: "RAZOR", missionType: .tot,
                              tot: Self.start.addingTimeInterval(100), hackTime: nil,
                              isHackPending: false, fixTime: sentAt, distance: 1000 - 10 * offset,
                              groundSpeed: 10, track: nil, bearing: nil, turnDirection: nil,
                              isFixStale: false, yellowTolerance: 5, redTolerance: 10,
                              speedUnit: .kts, distanceUnit: .nm, isEnded: isEnded)
    }

    @Test("Every snapshot goes by message to a reachable watch; the context follows the policy")
    func reachableTicks() {
        let fake = FakeWatchSession()
        let mirror = WatchMirror(session: fake)
        for offset in 0...6 {
            mirror.flightDidUpdate(steady(at: TimeInterval(offset)))
        }
        #expect(fake.messages == (0...6).map { .snapshot(steady(at: TimeInterval($0))) })
        // First snapshot, then the 5 s keep-alive.
        #expect(fake.contexts == [.snapshot(steady(at: 0)), .snapshot(steady(at: 5))])
    }

    @Test("An unreachable watch still gets the application context, but no messages")
    func unreachable() {
        let fake = FakeWatchSession()
        fake.isReachable = false
        let mirror = WatchMirror(session: fake)
        mirror.flightDidUpdate(steady(at: 0))
        mirror.flightDidEmit(Callout(.turnIn(.left)))
        #expect(fake.messages.isEmpty)
        #expect(fake.contexts == [.snapshot(steady(at: 0))])
    }

    @Test("A visible change refreshes the context at once")
    func visibleChange() {
        let fake = FakeWatchSession()
        let mirror = WatchMirror(session: fake)
        mirror.flightDidUpdate(steady(at: 0))
        var stale = steady(at: 1)
        stale.isFixStale = true
        mirror.flightDidUpdate(stale)
        #expect(fake.contexts == [.snapshot(steady(at: 0)), .snapshot(stale)])
    }

    @Test("Callouts go by message, stamped with their tick's send time")
    func callouts() {
        let fake = FakeWatchSession()
        let mirror = WatchMirror(session: fake)
        mirror.flightDidUpdate(steady(at: 3))
        mirror.flightDidEmit(Callout(.countdown(secondsToToT: 10)))
        #expect(fake.messages.last == .callout(Callout(.countdown(secondsToToT: 10)),
                                               emittedAt: Self.start.addingTimeInterval(3)))
        // Never as context: a late cue would be wrong.
        #expect(fake.contexts == [.snapshot(steady(at: 3))])
    }

    @Test("A callout before any snapshot is dropped")
    func calloutWithoutSnapshot() {
        let fake = FakeWatchSession()
        let mirror = WatchMirror(session: fake)
        mirror.flightDidEmit(Callout(.gpsLost))
        #expect(fake.messages.isEmpty)
    }

    @Test("The ended snapshot always goes as the context, and nothing after the end")
    func end() {
        let fake = FakeWatchSession()
        let mirror = WatchMirror(session: fake)
        mirror.flightDidUpdate(steady(at: 0))
        let ended = steady(at: 1, isEnded: true)
        mirror.flightDidUpdate(ended)
        mirror.flightDidEnd()
        mirror.flightDidUpdate(steady(at: 2))
        mirror.flightDidEmit(Callout(.gpsLost))
        #expect(fake.contexts == [.snapshot(steady(at: 0)), .snapshot(ended)])
        #expect(fake.messages.last == .snapshot(ended))
    }

    @Test("While activating, only the latest snapshot is held and sent once active")
    func pendingUntilActivated() {
        let fake = FakeWatchSession()
        fake.availability = .pending
        let mirror = WatchMirror(session: fake)
        mirror.flightDidUpdate(steady(at: 0))
        mirror.flightDidUpdate(steady(at: 1))
        mirror.flightDidEmit(Callout(.rollOut))
        #expect(fake.messages.isEmpty)
        #expect(fake.contexts.isEmpty)

        fake.change(availability: .available)
        #expect(fake.contexts == [.snapshot(steady(at: 1))])
        #expect(fake.messages == [.snapshot(steady(at: 1))])

        // Nothing is sent twice on a later state change.
        fake.change(availability: .available, isReachable: false)
        #expect(fake.contexts.count == 1)
    }

    @Test("A flight that ended while activating still delivers its end")
    func endWhilePending() {
        let fake = FakeWatchSession()
        fake.availability = .pending
        let mirror = WatchMirror(session: fake)
        let ended = steady(at: 1, isEnded: true)
        mirror.flightDidUpdate(steady(at: 0))
        mirror.flightDidUpdate(ended)
        mirror.flightDidEnd()
        fake.change(availability: .available)
        #expect(fake.contexts == [.snapshot(ended)])
    }

    @Test("With no paired watch or no companion app nothing is sent")
    func unavailable() {
        let fake = FakeWatchSession()
        fake.availability = .unavailable
        let mirror = WatchMirror(session: fake)
        mirror.flightDidUpdate(steady(at: 0))
        mirror.flightDidEmit(Callout(.gpsLost))
        #expect(fake.messages.isEmpty)
        #expect(fake.contexts.isEmpty)

        let pendingFake = FakeWatchSession()
        pendingFake.availability = .pending
        let pendingMirror = WatchMirror(session: pendingFake)
        pendingMirror.flightDidUpdate(steady(at: 0))
        pendingFake.change(availability: .unavailable)
        #expect(pendingFake.contexts.isEmpty)
    }

    @Test("A failed context update is retried on the next tick")
    func contextFailureRetries() {
        let fake = FakeWatchSession()
        fake.failContext = true
        let mirror = WatchMirror(session: fake)
        mirror.flightDidUpdate(steady(at: 0))
        fake.failContext = false
        mirror.flightDidUpdate(steady(at: 1))
        #expect(fake.contexts == [.snapshot(steady(at: 1))])
    }

    @Test("A released mirror leaves the session's state handler harmless")
    func releasedMirror() {
        let fake = FakeWatchSession()
        fake.availability = .pending
        var mirror: WatchMirror? = WatchMirror(session: fake)
        mirror?.flightDidUpdate(steady(at: 0))
        mirror = nil
        fake.change(availability: .available)
        #expect(mirror == nil)
        #expect(fake.contexts.isEmpty)
    }
}
