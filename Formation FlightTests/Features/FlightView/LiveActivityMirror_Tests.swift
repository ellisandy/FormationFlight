import Foundation
import Testing
@testable import Formation_Flight
import FormationFlightCore

/// Records the ActivityKit calls the mirror makes, in order.
@MainActor
private final class FakeLiveActivities: LiveActivityControlling {
    enum Call: Equatable {
        case endAll
        case start(FlightActivityAttributes, FlightActivityContent, staleDate: Date)
        case update(FlightActivityContent, staleDate: Date)
        case end(FlightActivityContent?)
    }

    struct StartFailed: Error {}

    var areActivitiesEnabled = true
    var failStart = false
    private(set) var calls: [Call] = []

    var updates: [FlightActivityContent] {
        calls.compactMap { if case .update(let c, _) = $0 { c } else { nil } }
    }

    func endAll() async { calls.append(.endAll) }

    func start(attributes: FlightActivityAttributes, content: FlightActivityContent, staleDate: Date) throws {
        if failStart { throw StartFailed() }
        calls.append(.start(attributes, content, staleDate: staleDate))
    }

    func update(_ content: FlightActivityContent, staleDate: Date) async {
        calls.append(.update(content, staleDate: staleDate))
    }

    func end(_ content: FlightActivityContent?) async { calls.append(.end(content)) }
}

/// When the Live Activity mirror starts, updates and ends the activity (F-02).
@Suite("LiveActivityMirror")
@MainActor
struct LiveActivityMirrorTests {
    private static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// 1000 m out at 10 m/s, ETE 100 s, ToT `totOffset` s after `start`.
    private func snapshot(at offset: TimeInterval = 0,
                          totOffset: TimeInterval = 100,
                          groundSpeed: Double = 10,
                          isEnded: Bool = false) -> FlightSnapshot {
        let sentAt = Self.start.addingTimeInterval(offset)
        return FlightSnapshot(sentAt: sentAt, missionName: "RAZOR", missionType: .tot,
                              tot: Self.start.addingTimeInterval(totOffset), hackTime: nil,
                              isHackPending: false, fixTime: sentAt, distance: 1000,
                              groundSpeed: groundSpeed, track: nil, bearing: nil, turnDirection: nil,
                              isFixStale: false, yellowTolerance: 5, redTolerance: 10,
                              speedUnit: .kts, distanceUnit: .nm, isEnded: isEnded)
    }

    /// Keeps Δ constant over time: the aircraft closes 10 m/s while the clock runs.
    private func steady(at offset: TimeInterval) -> FlightSnapshot {
        var s = snapshot(at: offset)
        s.distance = 1000 - 10 * offset
        return s
    }

    @Test("The first snapshot ends leftovers and then starts one activity")
    func startsOnFirstSnapshot() async {
        let fake = FakeLiveActivities()
        let mirror = LiveActivityMirror(controller: fake)
        let first = snapshot()
        mirror.flightDidUpdate(first)
        await mirror.waitForPendingWork()

        let content = FlightActivityContent(snapshot: first)
        #expect(fake.calls == [
            .endAll,
            .start(FlightActivityAttributes(missionName: "RAZOR", missionType: .tot), content,
                   staleDate: Self.start.addingTimeInterval(LiveActivityPolicy.staleAfter)),
        ])
    }

    @Test("Live Activities turned off: nothing is requested, ever")
    func disabled() async {
        let fake = FakeLiveActivities()
        fake.areActivitiesEnabled = false
        let mirror = LiveActivityMirror(controller: fake)
        mirror.flightDidUpdate(snapshot())
        mirror.flightDidEmit(Callout(.gpsLost))
        mirror.flightDidUpdate(snapshot(at: 1, totOffset: 90))
        mirror.flightDidEnd()
        await mirror.waitForPendingWork()
        #expect(fake.calls.isEmpty)
    }

    @Test("A failed request stops the mirror; later ticks send nothing")
    func failedStart() async {
        let fake = FakeLiveActivities()
        fake.failStart = true
        let mirror = LiveActivityMirror(controller: fake)
        mirror.flightDidUpdate(snapshot())
        await mirror.waitForPendingWork()
        mirror.flightDidUpdate(snapshot(at: 1, totOffset: 90))
        await mirror.waitForPendingWork()
        #expect(fake.calls == [.endAll])
    }

    @Test("Unchanged ticks are held back to the keep-alive interval")
    func keepAlive() async {
        let fake = FakeLiveActivities()
        let mirror = LiveActivityMirror(controller: fake)
        for second in 0...10 {
            mirror.flightDidUpdate(steady(at: TimeInterval(second)))
        }
        await mirror.waitForPendingWork()
        // Started at 0, keep-alives at 5 and 10.
        #expect(fake.updates.map(\.updatedAt) == [5, 10].map { Self.start.addingTimeInterval($0) })
    }

    @Test("A change in Δ is sent on the tick it happens")
    func deltaChangeSentAtOnce() async {
        let fake = FakeLiveActivities()
        let mirror = LiveActivityMirror(controller: fake)
        mirror.flightDidUpdate(steady(at: 0))
        var slower = steady(at: 1)
        slower.groundSpeed = 9 // ETE grows: later
        mirror.flightDidUpdate(slower)
        await mirror.waitForPendingWork()
        #expect(fake.updates.count == 1)
        #expect((fake.updates.first?.delta ?? 0) > 0)
    }

    @Test("Each callout is sent at once and cleared after the display window")
    func calloutShownThenCleared() async throws {
        let fake = FakeLiveActivities()
        let mirror = LiveActivityMirror(controller: fake)
        mirror.flightDidUpdate(steady(at: 0))
        mirror.flightDidUpdate(steady(at: 1))
        mirror.flightDidEmit(Callout(.countdown(secondsToToT: 60)))
        await mirror.waitForPendingWork()
        let shown = try #require(fake.updates.last)
        #expect(shown.cue == .countdown(secondsToToT: 60))
        #expect(shown.cueAt == Self.start.addingTimeInterval(1))

        let window = Int(LiveActivityPolicy.cueDisplayDuration)
        for second in 2...(1 + window) {
            mirror.flightDidUpdate(steady(at: TimeInterval(second)))
        }
        await mirror.waitForPendingWork()
        let cleared = try #require(fake.updates.last)
        #expect(cleared.cue == nil)
        #expect(cleared.updatedAt == Self.start.addingTimeInterval(TimeInterval(1 + window)))
    }

    @Test("End Flight ends the activity with the final snapshot's content")
    func endsWithFlight() async throws {
        let fake = FakeLiveActivities()
        let mirror = LiveActivityMirror(controller: fake)
        mirror.flightDidUpdate(steady(at: 0))
        let final = snapshot(at: 3, totOffset: 90, isEnded: true)
        mirror.flightDidUpdate(final)
        mirror.flightDidEnd()
        await mirror.waitForPendingWork()
        #expect(fake.calls.last == .end(FlightActivityContent(snapshot: final)))
        // The ended snapshot is not sent as an update of its own.
        #expect(fake.updates.isEmpty)

        // Nothing after the end.
        mirror.flightDidUpdate(steady(at: 4))
        mirror.flightDidEmit(Callout(.gpsLost))
        mirror.flightDidEnd()
        await mirror.waitForPendingWork()
        #expect(fake.calls.filter { if case .end = $0 { true } else { false } }.count == 1)
        #expect(fake.updates.isEmpty)
    }

    @Test("Ending a flight that never sent a snapshot does nothing")
    func endWithoutStart() async {
        let fake = FakeLiveActivities()
        let mirror = LiveActivityMirror(controller: fake)
        mirror.flightDidEnd()
        await mirror.waitForPendingWork()
        #expect(fake.calls.isEmpty)
    }

    @Test("The queued end still runs if the mirror is released straight after")
    func endSurvivesRelease() async {
        let fake = FakeLiveActivities()
        var mirror: LiveActivityMirror? = LiveActivityMirror(controller: fake)
        mirror?.flightDidUpdate(steady(at: 0))
        mirror?.flightDidEnd()
        mirror = nil
        // Let the detached chain drain.
        for _ in 0..<50 { await Task.yield() }
        #expect(fake.calls.count == 3)
        if case .end = fake.calls.last {} else { Issue.record("expected the end call last, got \(fake.calls)") }
    }

    @Test("UI-test and screenshot runs get no mirrors")
    func noMirrorsUnderUITests() {
        #expect(FlightMirrors.makeDefault(arguments: ["app", "-uiTestsResetStore"]).isEmpty)
        #expect(FlightMirrors.makeDefault(arguments: ["app", "-uiTestsSeedFlights"]).isEmpty)
        let mirrors = FlightMirrors.makeDefault(arguments: ["app"])
        #expect(mirrors.count == 2)
        #expect(mirrors.contains { $0 is LiveActivityMirror })
        #expect(mirrors.contains { $0 is WatchMirror })
    }
}
