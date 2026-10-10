import Foundation
import CoreLocation
import Testing
@testable import Formation_Flight
import FormationFlightCore

/// Records everything a mirror is sent, in order.
@MainActor
private final class FakeMirror: FlightMirroring {
    enum Message: Equatable {
        case update(FlightSnapshot)
        case callout(Callout)
        case end
    }

    private(set) var messages: [Message] = []

    var snapshots: [FlightSnapshot] {
        messages.compactMap { if case .update(let s) = $0 { s } else { nil } }
    }
    var callouts: [Callout] {
        messages.compactMap { if case .callout(let c) = $0 { c } else { nil } }
    }
    var endCount: Int { messages.filter { $0 == .end }.count }

    func flightDidUpdate(_ snapshot: FlightSnapshot) { messages.append(.update(snapshot)) }
    func flightDidEmit(_ callout: Callout) { messages.append(.callout(callout)) }
    func flightDidEnd() { messages.append(.end) }
}

/// The watch / Live Activity hook on `FlightViewModel`: snapshots per tick and on Hack!, the
/// same callouts the banner gets, and the end of the flight.
@Suite("FlightViewModel mirrors")
@MainActor
struct FlightViewModelMirrorTests {
    private static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private static let target = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

    private func makeVM(missionType: MissionType = .tot,
                        missionDate: Date? = start.addingTimeInterval(61),
                        hackTime: TimeInterval? = nil,
                        mirrors: [any FlightMirroring],
                        timer: MockTimerScheduler,
                        provider: MockLocationProvider = MockLocationProvider(),
                        clock: MutableClock) -> FlightViewModel {
        var settings = Settings.empty()
        settings.yellowTolerance = 5
        settings.redTolerance = 10
        settings.speedUnit = .mph
        let vm = FlightViewModel(missionName: "RAZOR",
                                 target: Self.target,
                                 missionType: missionType,
                                 missionDate: missionDate,
                                 hackTime: hackTime,
                                 settings: settings,
                                 locationProvider: provider,
                                 timerScheduler: timer,
                                 mirrors: mirrors,
                                 now: { clock.now })
        vm.start()
        return vm
    }

    /// A fix `meters` south of the target, flying north at `speed` m/s.
    private func sendFix(_ provider: MockLocationProvider, meters: Double = 2000, speed: Double = 50,
                         at time: Date) {
        let location = CLLocation(latitude: Self.target.latitude - meters / 111_320, longitude: Self.target.longitude)
        provider.setLocation(location: location,
                             speed: Measurement(value: speed, unit: .metersPerSecond),
                             course: Measurement(value: 0, unit: .degrees),
                             fixTime: time,
                             notify: true)
    }

    @Test("Every tick sends a snapshot whose local recomputation matches the screen")
    func snapshotPerTickMatchesScreen() throws {
        let clock = MutableClock(Self.start.addingTimeInterval(0.25))
        let timer = MockTimerScheduler()
        let provider = MockLocationProvider()
        let mirror = FakeMirror()
        let vm = makeVM(missionDate: Self.start.addingTimeInterval(500), mirrors: [mirror], timer: timer,
                        provider: provider, clock: clock)

        sendFix(provider, at: clock.now)
        timer.fire()
        clock.advance(by: 1)
        timer.fire()

        #expect(mirror.snapshots.count == 2)
        let snapshot = try #require(mirror.snapshots.last)
        #expect(snapshot.sentAt == clock.now)
        #expect(snapshot.missionName == "RAZOR")
        #expect(snapshot.missionType == .tot)
        #expect(snapshot.tot == vm.tot)
        #expect(!snapshot.isHackPending)
        #expect(!snapshot.isFixStale)
        #expect(!snapshot.isEnded)
        #expect(snapshot.speedUnit == .mph)
        #expect(snapshot.yellowTolerance == 5)
        #expect(snapshot.redTolerance == 10)
        #expect(snapshot.groundSpeed == 50)
        #expect(snapshot.track == 0)

        // The receiver ticking at the send time shows what the phone shows.
        let timing = snapshot.timing(at: snapshot.sentAt)
        #expect(timing.currentTime == vm.currentTime)
        #expect(timing.ete == vm.ete)
        #expect(timing.eta == vm.eta)
        #expect(timing.delta == vm.delta)
        #expect(timing.status == vm.statusColor)
        #expect(timing.turnDuration == vm.turnDuration)
        #expect(timing.requiredGroundSpeed.map { Measurement(value: $0, unit: UnitSpeed.metersPerSecond).converted(to: .knots) }
                == vm.requiredGroundSpeed)
        #expect(vm.ete != nil)
    }

    @Test("Hack! sends a snapshot immediately with the new ToT")
    func hackSendsImmediately() throws {
        let clock = MutableClock(Self.start)
        let timer = MockTimerScheduler()
        let mirror = FakeMirror()
        let vm = makeVM(missionType: .hackTime, missionDate: nil, hackTime: 90, mirrors: [mirror],
                        timer: timer, clock: clock)

        timer.fire()
        #expect(mirror.snapshots.last?.isHackPending == true)
        #expect(mirror.snapshots.last?.tot == nil)

        clock.advance(by: 2.5)
        vm.startHack()
        #expect(mirror.snapshots.count == 2)
        let snapshot = try #require(mirror.snapshots.last)
        #expect(!snapshot.isHackPending)
        #expect(snapshot.hackTime == 90)
        #expect(snapshot.tot == Self.start.addingTimeInterval(92))
        #expect(snapshot.tot == vm.tot)
    }

    @Test("Mirrors get the same callout as the banner, after that tick's snapshot")
    func calloutsForwarded() throws {
        let clock = MutableClock(Self.start)
        let timer = MockTimerScheduler()
        let mirror = FakeMirror()
        let vm = makeVM(mirrors: [mirror], timer: timer, clock: clock)

        timer.fire()
        clock.advance(by: 1)
        timer.fire()

        let callout = try #require(vm.activeCallout)
        #expect(callout.event == .countdown(secondsToToT: 60))
        #expect(mirror.callouts == [callout])
        // Tick 1 snapshot, tick 2 snapshot, then tick 2's callout.
        #expect(mirror.messages.count == 3)
        if case .update = mirror.messages[1] {} else { Issue.record("the tick's snapshot should precede its callout") }
        #expect(mirror.messages.last == .callout(callout))
    }

    @Test("A stale fix is flagged and its speed and track are not sent (B-07)")
    func staleFixInSnapshot() throws {
        let clock = MutableClock(Self.start)
        let timer = MockTimerScheduler()
        let provider = MockLocationProvider()
        let mirror = FakeMirror()
        // Held for the whole test: a released VM cancels its timer in deinit, so fire() would do nothing.
        let vm = makeVM(mirrors: [mirror], timer: timer, provider: provider, clock: clock)

        sendFix(provider, at: clock.now)
        clock.advance(by: TimingEngine.staleFixThreshold + 1)
        withExtendedLifetime(vm) { timer.fire() }

        let snapshot = try #require(mirror.snapshots.last)
        #expect(snapshot.isFixStale)
        #expect(snapshot.isStale(at: snapshot.sentAt))
        #expect(snapshot.groundSpeed == nil)
        #expect(snapshot.track == nil)
        #expect(snapshot.distance != nil)
        #expect(snapshot.fixTime == Self.start)
    }

    @Test("stop() sends a final ended snapshot then ends, once, to every mirror")
    func stopEndsMirrors() {
        let clock = MutableClock(Self.start)
        let timer = MockTimerScheduler()
        let first = FakeMirror()
        let second = FakeMirror()
        let vm = makeVM(mirrors: [first, second], timer: timer, clock: clock)

        vm.stop()
        vm.stop()
        for mirror in [first, second] {
            #expect(mirror.endCount == 1)
            #expect(mirror.messages.count == 2)
            #expect(mirror.snapshots.last?.isEnded == true)
            #expect(mirror.messages.last == .end)
        }
    }

    @Test("Without mirrors nothing changes for the screen")
    func noMirrors() {
        let clock = MutableClock(Self.start)
        let timer = MockTimerScheduler()
        let vm = makeVM(mirrors: [], timer: timer, clock: clock)
        timer.fire()
        #expect(vm.currentTime == Self.start)
        vm.stop()
    }
}
