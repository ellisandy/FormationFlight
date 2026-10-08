import Foundation
import Combine
import CoreLocation
import SwiftUI
import Testing
@testable import Formation_Flight

// Protocol-based mock for LocationProviding used by FlightViewModel.
// This is a standalone class that conforms to the protocol; it does not subclass the
// production LocationProvider, so every stored property here is plain test state.
// `LocationProviding` is a MainActor protocol (B-27), so the mock is MainActor too.
@MainActor
final class MockLocationProvider: LocationProviding {
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var accuracyAuthorization: CLAccuracyAuthorization = .fullAccuracy
    // `isLocationDenied` comes from the protocol extension (denied or restricted).
    @available(*, deprecated, renamed: "authorizationStatus")
    var authroizationStatus: CLAuthorizationStatus? {
        authorizationStatus == .notDetermined ? nil : authorizationStatus
    }

    private(set) var requestWhenInUseAuthorizationCallCount = 0

    func requestWhenInUseAuthorization() {
        requestWhenInUseAuthorizationCallCount += 1
    }

    var altitude: Measurement<UnitLength> = Measurement(value: 0, unit: .meters)

    var computedSpeedAndCourse: Bool = false

    private(set) var startMonitoringCallCount = 0
    private(set) var stopMonitoringCallCount = 0

    func stopMonitoring() {
        stopMonitoringCallCount += 1
    }

    var updateDelegate: (() -> Void)?
    var speed: Measurement<UnitSpeed> = Measurement(value: 0, unit: .metersPerSecond)
    var currentLocation: CLLocation?
    var course: Measurement<UnitAngle> = Measurement(value: 0, unit: .degrees)
    var lastFixTimestamp: Date?

    func startMonitoring() {
        startMonitoringCallCount += 1
    }

    /// Convenience to set location-related fields and optionally notify the delegate.
    /// `fixTime` is the fix's own measurement time (`lastFixTimestamp`); left unchanged when nil.
    func setLocation(location: CLLocation?,
                     speed: Measurement<UnitSpeed> = Measurement(value: 0, unit: .metersPerSecond),
                     course: Measurement<UnitAngle>? = nil,
                     fixTime: Date? = nil,
                     notify: Bool = false) {
        self.currentLocation = location
        self.speed = speed
        if let course { self.course = course }
        if let fixTime { self.lastFixTimestamp = fixTime }
        if notify { self.updateDelegate?() }
    }
}

/// A clock the test can move between ticks. Injected as `{ clock.now }` so tests can prove
/// that a value tracks the wall clock (B-09, B-24, B-07) rather than a stale sample of it.
/// MainActor because the view model only ever reads it from MainActor-isolated code.
@MainActor
final class MutableClock {
    var now: Date
    init(_ now: Date) { self.now = now }
    func advance(by seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}

/// Exact tolerance boundaries for `makeSettings(yellow: 5, red: 10)` with ETE fixed at 10 s.
/// Production maps `|Δ| <= yellow → good`, `|Δ| <= red → bad`, otherwise `reallyBad`.
/// Positive Δ is late (ETA after ToT), negative Δ is early.
private let statusBoundaryCases: [(delta: TimeInterval, expected: FlightViewModel.Status)] = [
    (delta: 5, expected: .good),        // == yellow
    (delta: 6, expected: .bad),         // yellow + 1
    (delta: 10, expected: .bad),        // == red
    (delta: 11, expected: .reallyBad),  // red + 1
    (delta: -5, expected: .good),       // == -yellow (early)
    (delta: -6, expected: .bad),        // -(yellow + 1)
    (delta: -10, expected: .bad),       // == -red (early)
    (delta: -11, expected: .reallyBad), // -(red + 1)
]

/// B-40: raw `distance / speed` values (at 10 m/s) and the whole-second ETE they must truncate
/// to. All raw quotients are exact in Double, so only the truncation is under test. File scope,
/// like `statusBoundaryCases`, because the suite is `@MainActor` and `@Test(arguments:)` is
/// evaluated outside the actor.
private let eteTruncationCases: [(distanceMeters: Double, expectedETE: TimeInterval)] = [
    (distanceMeters: 9, expectedETE: 0),       // 0.9 s   -> 0 s, never rounds up to 1
    (distanceMeters: 595, expectedETE: 59),    // 59.5 s  -> 59 s, never rounds up to a minute
    (distanceMeters: 1004, expectedETE: 100),  // 100.4 s -> 100 s
    (distanceMeters: 100, expectedETE: 10),    // already integral: unchanged
]

@Suite("FlightViewModel")
@MainActor
struct FlightViewModelTests {
    /// A fixed instant used as the injected clock (B-29). The value is an integral number of
    /// seconds so that `addingTimeInterval` / `timeIntervalSince` on whole-second offsets are
    /// exact in Double arithmetic and tests can assert `==` rather than tolerances.
    private static let fixedNow = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// Clock closure that always returns `fixedNow`.
    private var fixedClock: () -> Date { { Self.fixedNow } }

    // Helper settings with known tolerances
    private func makeSettings(yellow: Int = 5, red: Int = 10,
                              speedUnit: Settings.SpeedUnit = .kts,
                              distanceUnit: Settings.DistanceUnit = .nm) -> Settings {
        var s = Settings.empty()
        s.yellowTolerance = yellow
        s.redTolerance = red
        s.speedUnit = speedUnit
        s.distanceUnit = distanceUnit
        return s
    }

    /// Places a location due north/south of `target` using a flat-earth 111_320 m/deg
    /// approximation. CoreLocation measures the resulting distance on the WGS84 ellipsoid, so
    /// the distance it reports is slightly *less* than `metersNorth` (about 0.3% at 37.8° N,
    /// where the meridional degree is ~110_990 m). Tests that go through this helper must
    /// therefore use a geodesic tolerance, not an exact comparison.
    private func locationOffsetFromTarget(_ target: CLLocationCoordinate2D, metersNorth: Double) -> CLLocation {
        let metersPerDegreeLat = 111_320.0
        let deltaLat = metersNorth / metersPerDegreeLat
        let newLat = target.latitude + deltaLat
        return CLLocation(latitude: newLat, longitude: target.longitude)
    }

    /// Builds and starts a view model. Pass `now:` to inject a deterministic clock; the
    /// default is the wall clock, which only the lifecycle tests rely on.
    private func makeVM(settings: Settings = Settings.empty(),
                        target: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                        missionType: MissionType = .tot,
                        missionDate: Date? = nil,
                        hackTime: TimeInterval? = nil,
                        timerScheduler: any TimerScheduling = MockTimerScheduler(),
                        locationProvider: LocationProviding? = nil,
                        now: (() -> Date)? = nil) -> FlightViewModel {
        let lp = locationProvider ?? MockLocationProvider()
        let vm = FlightViewModel(missionName: "TEST",
                                 target: target,
                                 missionType: missionType,
                                 missionDate: missionDate,
                                 hackTime: hackTime,
                                 settings: settings,
                                 locationProvider: lp,
                                 timerScheduler: timerScheduler,
                                 now: now ?? { Date() })
        // Lifecycle (B-03): side effects live in start(), not init. Tests built on
        // this helper expect a running VM (delegate wired, timer scheduled).
        vm.start()
        return vm
    }

    /// Sets ground speed and distance directly on the VM (bypassing the location provider)
    /// so that `ete = distance / speed` is exact. 10 m/s and whole-metre multiples of 10
    /// give whole-second ETEs with no floating-point error.
    private func setDirectInputs(_ vm: FlightViewModel, speedMps: Double, distanceMeters: Double) {
        vm.currentGroundSpeed = Measurement(value: speedMps, unit: .metersPerSecond)
        vm.distance = Measurement(value: distanceMeters, unit: .meters)
    }

    // MARK: - UI Intents
    @Test("Edit Hack Time presentation toggles")
    func editHackTimePresentation() async throws {
        let vm = makeVM(settings: makeSettings())
        #expect(vm.isEditingHackTime == false)
        vm.presentEditHackTime()
        #expect(vm.isEditingHackTime == true)
        vm.cancelHackTimeEdit()
        #expect(vm.isEditingHackTime == false)
    }

    @Test("Edit ToT presentation toggles")
    func editToTPresentation() async throws {
        let vm = makeVM(settings: makeSettings())
        #expect(vm.isEditingToT == false)
        vm.presentEditToT()
        #expect(vm.isEditingToT == true)
        vm.cancelEditToT()
        #expect(vm.isEditingToT == false)
    }

    // MARK: - startHack()
    @Test("startHack computes ToT from hack time and current time")
    func startHackComputesToT() async throws {
        let vm = makeVM(settings: makeSettings(), missionType: .hackTime, hackTime: 120, now: fixedClock)
        // start() seeded currentTime from the injected clock.
        #expect(vm.currentTime == Self.fixedNow)

        vm.startHack()

        let tot = try #require(vm.tot)
        #expect(tot == Self.fixedNow.addingTimeInterval(120))
    }

    @Test("startHack anchors to the clock at the button press, even before the first tick")
    func startHackBeforeFirstTickUsesClock() async throws {
        // Built directly, never started: `currentTime` is nil because no tick has sampled it.
        let vm = FlightViewModel(missionName: "HACK",
                                 missionType: .hackTime,
                                 hackTime: 90,
                                 settings: makeSettings(),
                                 locationProvider: MockLocationProvider(),
                                 timerScheduler: MockTimerScheduler(),
                                 now: fixedClock)
        #expect(vm.currentTime == nil)

        vm.startHack()

        // B-09: the press itself is the hack instant. It must not silently no-op because the
        // timer has not fired yet.
        let tot = try #require(vm.tot, "startHack must set ToT even before the first timer tick")
        #expect(tot == Self.fixedNow.addingTimeInterval(90))
    }

    @Test("startHack uses the current clock, not the last timer sample")
    func startHackUsesCurrentClockNotStaleSample() async throws {
        let clock = MutableClock(Self.fixedNow)
        let mockTimer = MockTimerScheduler()
        let vm = makeVM(settings: makeSettings(), missionType: .hackTime, hackTime: 90,
                        timerScheduler: mockTimer, now: { clock.now })
        mockTimer.fire()
        #expect(vm.currentTime == Self.fixedNow)

        // The pilot presses "Hack!" 0.9 s after the last tick. In an app whose tolerances are
        // whole seconds the anchor must be the press, truncated to the second it falls in.
        clock.advance(by: 0.9)
        vm.startHack()
        let tot = try #require(vm.tot)
        #expect(tot == Self.fixedNow.addingTimeInterval(90), "0.9 s truncates to the same second")

        // A full second later the anchor must move with the clock, not stay on the stale sample.
        clock.advance(by: 1.1)
        vm.startHack()
        let laterTot = try #require(vm.tot)
        #expect(laterTot == Self.fixedNow.addingTimeInterval(92))
    }

    // MARK: - Timing pipeline and status mapping
    @Test("ETE/ETA/Delta are exact with an injected clock and map to status")
    func timingAndStatus() async throws {
        let mockTimer = MockTimerScheduler()
        let vm = makeVM(settings: makeSettings(yellow: 5, red: 10), timerScheduler: mockTimer, now: fixedClock)

        vm.tot = Self.fixedNow.addingTimeInterval(12)
        // 250 m at 50 m/s -> ETE exactly 5 s
        setDirectInputs(vm, speedMps: 50, distanceMeters: 250)

        mockTimer.fire()

        #expect(vm.currentTime == Self.fixedNow)
        #expect(vm.ete == 5.0)
        #expect(vm.eta == Self.fixedNow.addingTimeInterval(5))
        // Delta = ETA - ToT = (now + 5) - (now + 12) = -7 (early)
        #expect(vm.delta == -7.0)
        // |delta| = 7: above yellow (5), at or below red (10) => bad
        #expect(vm.statusColor == .bad)
    }

    @Test("Timing pipeline clears to nil/unknown without speed or distance and recovers when both return")
    func eteNilWhenNoSpeedOrDistance() async throws {
        let lp = MockLocationProvider()
        let mockTimer = MockTimerScheduler()
        let vm = makeVM(settings: makeSettings(yellow: 5, red: 10),
                        timerScheduler: mockTimer,
                        locationProvider: lp,
                        now: fixedClock)
        vm.tot = Self.fixedNow.addingTimeInterval(30)

        // Case 1: a fix with zero ground speed. updateInstruments() clears currentGroundSpeed,
        // so the next tick must clear ETE/ETA/delta and report .unknown.
        lp.setLocation(location: locationOffsetFromTarget(vm.target, metersNorth: -1000),
                       speed: Measurement(value: 0, unit: .metersPerSecond),
                       course: Measurement(value: 0, unit: .degrees))
        vm.onLocationUpdate()
        mockTimer.fire()

        #expect(vm.currentGroundSpeed == nil)
        #expect(vm.distance != nil, "a fix was provided, so distance is known even with no speed")
        #expect(vm.ete == nil)
        #expect(vm.eta == nil)
        #expect(vm.delta == nil)
        #expect(vm.statusColor == .unknown)

        // Case 2: speed present but distance missing. updateInstruments() returns early when
        // there is no fix (and leaves state untouched), so set the VM inputs directly.
        setDirectInputs(vm, speedMps: 10, distanceMeters: 100)
        vm.distance = nil
        mockTimer.fire()

        #expect(vm.ete == nil)
        #expect(vm.eta == nil)
        #expect(vm.delta == nil)
        #expect(vm.statusColor == .unknown)

        // Case 3: a valid fix with speed arrives via the provider delegate; the pipeline
        // must compute again. ~1000 m at 10 m/s -> ETE ~100 s; delta ~ +70 s => reallyBad.
        lp.setLocation(location: locationOffsetFromTarget(vm.target, metersNorth: -1000),
                       speed: Measurement(value: 10, unit: .metersPerSecond),
                       course: Measurement(value: 0, unit: .degrees),
                       notify: true)
        mockTimer.fire()

        let ete = try #require(vm.ete)
        #expect(ete > 0)
        #expect(vm.eta != nil)
        let delta = try #require(vm.delta)
        #expect(delta > 10, "delta is far outside the red tolerance by construction")
        #expect(vm.statusColor == .reallyBad)
    }

    @Test("Status is unknown before any delta and returns to unknown when ToT is cleared")
    func statusUnknownWhenMissingInputs() async throws {
        let mockTimer = MockTimerScheduler()
        let vm = makeVM(settings: makeSettings(yellow: 5, red: 10), timerScheduler: mockTimer, now: fixedClock)

        // B-11: a fresh VM has nothing to judge, so it must not claim .good.
        #expect(vm.statusColor == .unknown)

        // A tick with no inputs at all keeps everything nil and the status unknown.
        mockTimer.fire()
        #expect(vm.ete == nil)
        #expect(vm.eta == nil)
        #expect(vm.delta == nil)
        #expect(vm.statusColor == .unknown)

        // Provide ETE inputs but no ToT: ETE/ETA exist, delta does not, status stays unknown.
        setDirectInputs(vm, speedMps: 10, distanceMeters: 100)
        mockTimer.fire()
        #expect(vm.ete == 10.0)
        #expect(vm.eta == Self.fixedNow.addingTimeInterval(10))
        #expect(vm.delta == nil)
        #expect(vm.statusColor == .unknown)

        // Add a ToT: delta becomes computable and the status is judged.
        vm.tot = Self.fixedNow.addingTimeInterval(10)
        mockTimer.fire()
        #expect(vm.delta == 0.0)
        #expect(vm.statusColor == .good)

        // Clear ToT again: the status must fall back to unknown rather than keep the stale colour.
        vm.tot = nil
        mockTimer.fire()
        #expect(vm.delta == nil)
        #expect(vm.statusColor == .unknown)
    }

    // MARK: - Status boundaries (T-02 / B-29)
    @Test("Status at exact tolerance boundaries", arguments: statusBoundaryCases)
    func statusAtExactToleranceBoundary(delta: TimeInterval, expected: FlightViewModel.Status) async throws {
        let mockTimer = MockTimerScheduler()
        let vm = makeVM(settings: makeSettings(yellow: 5, red: 10), timerScheduler: mockTimer, now: fixedClock)

        // 100 m at 10 m/s -> ETE exactly 10 s, so ETA = now + 10.
        setDirectInputs(vm, speedMps: 10, distanceMeters: 100)
        // delta = ETA - ToT  =>  ToT = now + 10 - delta
        vm.tot = Self.fixedNow.addingTimeInterval(10 - delta)

        mockTimer.fire()

        #expect(vm.ete == 10.0)
        #expect(vm.delta == delta)
        #expect(vm.statusColor == expected)
        // B-11: colour alone is not enough; the sign must be spelled out next to the value.
        #expect(vm.deltaLabel == (delta < 0 ? "EARLY" : "LATE"))
    }

    // MARK: - Early/late label (B-11)
    @Test("Delta label reads EARLY, LATE or ON TIME and is nil without a delta")
    func deltaLabelFollowsSignOfDelta() async throws {
        let mockTimer = MockTimerScheduler()
        let vm = makeVM(settings: makeSettings(yellow: 5, red: 10), timerScheduler: mockTimer, now: fixedClock)

        // No inputs: nothing to judge.
        mockTimer.fire()
        #expect(vm.delta == nil)
        #expect(vm.deltaLabel == nil)

        // 100 m at 10 m/s -> ETA = now + 10. ToT = now + 13 -> delta = -3 (early).
        setDirectInputs(vm, speedMps: 10, distanceMeters: 100)
        vm.tot = Self.fixedNow.addingTimeInterval(13)
        mockTimer.fire()
        #expect(vm.delta == -3)
        #expect(vm.deltaLabel == "EARLY")

        // ToT = now + 7 -> delta = +3 (late).
        vm.tot = Self.fixedNow.addingTimeInterval(7)
        mockTimer.fire()
        #expect(vm.delta == 3)
        #expect(vm.deltaLabel == "LATE")

        // ToT = now + 10 -> delta = 0 exactly.
        vm.tot = Self.fixedNow.addingTimeInterval(10)
        mockTimer.fire()
        #expect(vm.delta == 0)
        #expect(vm.deltaLabel == "ON TIME")

        // B-46: a ToT with a fractional second, under a second either way, is ON TIME with
        // an unsigned zero, not "LATE +00:00:00" / "EARLY -00:00:00".
        for (offset, label, shown) in [(9.6, "ON TIME", "00:00:00"), (10.4, "ON TIME", "00:00:00"),
                                       (8.8, "LATE", "+00:00:01"), (11.2, "EARLY", "-00:00:01")] {
            vm.tot = Self.fixedNow.addingTimeInterval(offset)
            mockTimer.fire()
            #expect(vm.deltaLabel == label, "ToT at +\(offset) s")
            #expect(Formatting.signedDurationHMS(vm.delta) == shown, "ToT at +\(offset) s")
        }

        // Losing the ToT loses the delta, and the label must go with it.
        vm.tot = nil
        mockTimer.fire()
        #expect(vm.delta == nil)
        #expect(vm.deltaLabel == nil)
    }

    // MARK: - Instruments and required ground speed
    @Test("Instrument updates compute required ground speed from distance and time to ToT")
    func instrumentsAndRequiredGroundSpeed() async throws {
        let lp = MockLocationProvider()
        let mockTimer = MockTimerScheduler()
        let target = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let vm = makeVM(settings: makeSettings(), target: target, timerScheduler: mockTimer, locationProvider: lp, now: fixedClock)

        vm.tot = Self.fixedNow.addingTimeInterval(60) // 60 seconds to go

        // Aircraft ~0.01 deg west of the target, tracking east toward it.
        lp.setLocation(location: CLLocation(latitude: target.latitude, longitude: target.longitude - 0.01),
                       speed: Measurement(value: 10, unit: .metersPerSecond),
                       course: Measurement(value: 90, unit: .degrees))

        vm.onLocationUpdate()
        // Required GS is a timing readout (B-24): it is refreshed on the 1 Hz tick.
        mockTimer.fire()

        #expect(vm.currentGroundSpeed == lp.speed)
        #expect(vm.track == lp.course)
        let distance = try #require(vm.distance)
        let bearing = try #require(vm.bearing)
        // Due east, allowing for meridian convergence over ~900 m.
        #expect(abs(bearing.converted(to: .degrees).value - 90) < 0.5)

        // Required GS ≈ distance / time remaining (track and bearing are aligned to within
        // meridian convergence, so the turn-aware solver (B-25) adds only a fraction of a
        // degree of turn; its bisection resolves to 1e-4 m/s).
        let rgs = try #require(vm.requiredGroundSpeed)
        let expectedMps = distance.converted(to: .meters).value / 60
        #expect(abs(rgs.converted(to: .metersPerSecond).value - expectedMps) < 1e-3)
        #expect(rgs.converted(to: .knots).value > 0)
    }

    @Test("Required ground speed is computed when approaching from the east")
    func requiredSpeedComputedApproachingFromEast() async throws {
        let lp = MockLocationProvider()
        let mockTimer = MockTimerScheduler()
        let vm = makeVM(settings: makeSettings(), timerScheduler: mockTimer, locationProvider: lp, now: fixedClock)
        vm.tot = Self.fixedNow.addingTimeInterval(120)

        // Aircraft ~0.01 deg east of the target (bearing ~270), tracking west.
        lp.setLocation(location: CLLocation(latitude: vm.target.latitude, longitude: vm.target.longitude + 0.01),
                       speed: Measurement(value: 30, unit: .metersPerSecond),
                       course: Measurement(value: 270, unit: .degrees))

        vm.onLocationUpdate()
        mockTimer.fire()

        let bearing = try #require(vm.bearing)
        #expect(abs(bearing.converted(to: .degrees).value - 270) < 0.5)
        let distance = try #require(vm.distance)
        let rgs = try #require(vm.requiredGroundSpeed)
        let expectedMps = distance.converted(to: .meters).value / 120
        // Aligned within meridian convergence; see instrumentsAndRequiredGroundSpeed.
        #expect(abs(rgs.converted(to: .metersPerSecond).value - expectedMps) < 1e-3)
    }

    @Test("Required speed is nil when time remaining <= 0")
    func requiredSpeedNilWhenNoTimeRemaining() async throws {
        let lp = MockLocationProvider()
        let mockTimer = MockTimerScheduler()
        let vm = makeVM(settings: makeSettings(), timerScheduler: mockTimer, locationProvider: lp, now: fixedClock)
        lp.setLocation(location: CLLocation(latitude: vm.target.latitude, longitude: vm.target.longitude - 0.01),
                       speed: Measurement(value: 10, unit: .metersPerSecond),
                       course: Measurement(value: 90, unit: .degrees))

        // ToT exactly now: zero time remaining.
        vm.tot = Self.fixedNow
        vm.onLocationUpdate()
        mockTimer.fire()
        #expect(vm.requiredGroundSpeed == nil)

        // ToT already past.
        vm.tot = Self.fixedNow.addingTimeInterval(-1)
        vm.onLocationUpdate()
        mockTimer.fire()
        #expect(vm.requiredGroundSpeed == nil)

        // ToT in the future: computable again.
        vm.tot = Self.fixedNow.addingTimeInterval(1)
        vm.onLocationUpdate()
        mockTimer.fire()
        #expect(vm.requiredGroundSpeed != nil)
    }

    @Test("Required ground speed tracks the clock between location callbacks")
    func requiredSpeedTracksClockWithoutLocationCallback() async throws {
        let clock = MutableClock(Self.fixedNow)
        let mockTimer = MockTimerScheduler()
        let vm = makeVM(settings: makeSettings(), timerScheduler: mockTimer, now: { clock.now })

        // 1000 m to run with 100 s to go -> exactly 10 m/s. Set directly so the geodesic
        // distance does not enter into it; only the time-remaining arithmetic is under test.
        vm.distance = Measurement(value: 1000, unit: .meters)
        vm.tot = Self.fixedNow.addingTimeInterval(100)
        mockTimer.fire()

        let first = try #require(vm.requiredGroundSpeed, "B-24: Req GS must be computed on the tick")
        #expect(first.converted(to: .metersPerSecond).value == 10)

        // 50 s later with no new fix: half the time left, so twice the speed required. Before
        // B-24 this value was frozen at whatever the last location callback computed.
        clock.advance(by: 50)
        mockTimer.fire()

        let second = try #require(vm.requiredGroundSpeed)
        #expect(second.converted(to: .metersPerSecond).value == 20)

        // At and past ToT there is no positive speed that gets there in time.
        clock.advance(by: 50)
        mockTimer.fire()
        #expect(vm.requiredGroundSpeed == nil)
    }

    // MARK: - .tot mission
    @Test(".tot mission initializes ToT from missionDate and computes exact timing")
    func totMissionInitializesToT() async throws {
        let missionDate = Self.fixedNow.addingTimeInterval(20)
        let mockTimer = MockTimerScheduler()
        let vm = makeVM(settings: makeSettings(yellow: 5, red: 10),
                        missionType: .tot,
                        missionDate: missionDate,
                        timerScheduler: mockTimer,
                        now: fixedClock)
        // ToT should be set from missionDate
        #expect(vm.tot == missionDate)

        // 50 m at 10 m/s -> ETE exactly 5 s
        setDirectInputs(vm, speedMps: 10, distanceMeters: 50)
        mockTimer.fire()

        #expect(vm.ete == 5.0)
        #expect(vm.eta == Self.fixedNow.addingTimeInterval(5))
        // Delta = (now + 5) - (now + 20) = -15 -> |delta| = 15 > red (10) => reallyBad
        #expect(vm.delta == -15.0)
        #expect(vm.statusColor == .reallyBad)
    }

    // MARK: - Location-driven integration
    @Test("Location update drives distance, bearing and ETE through the full pipeline")
    func locationUpdateDrivesDistanceAndETE() async throws {
        let lp = MockLocationProvider()
        let mockTimer = MockTimerScheduler()
        let vm = makeVM(settings: makeSettings(), timerScheduler: mockTimer, locationProvider: lp, now: fixedClock)
        vm.tot = Self.fixedNow.addingTimeInterval(100)

        // 1000 m south (flat-earth) at 10 m/s, tracking north.
        lp.setLocation(location: locationOffsetFromTarget(vm.target, metersNorth: -1000),
                       speed: Measurement(value: 10, unit: .metersPerSecond),
                       course: Measurement(value: 0, unit: .degrees),
                       notify: true)
        mockTimer.fire()

        // Geodesic tolerance, not clock slop: `locationOffsetFromTarget` uses 111_320 m/deg, while
        // CoreLocation measures on WGS84 where a degree of latitude at 37.8 N is ~110_990 m
        // (~0.3% shorter). A spherical-earth measurement (111_195 m/deg) would be ~0.1% shorter.
        // 1% comfortably covers either model while still catching a unit or sign mistake.
        let distance = try #require(vm.distance).converted(to: .meters).value
        #expect(abs(distance - 1000) < 10)

        // ETE is the whole-second truncation of distance / speed (B-40). The geodesic shortfall
        // above (~997 m -> 99.7 s) plus truncation lands on exactly 99 s, so the window is
        // "within 1 s" inclusive: 1 % geodesic slack on the distance plus up to 1 s of truncation.
        let ete = try #require(vm.ete)
        #expect(abs(ete - 100) <= 1)
        #expect(ete == (distance / 10).rounded(.down), "ETE must be the truncated distance / speed")

        let bearing = try #require(vm.bearing)
        #expect(abs(bearing.converted(to: .degrees).value) < 0.001, "target is due north")

        // ETA follows from the injected clock, so it is exactly now + ETE. With the clock and
        // ETE both integral (B-40) the delta (now + ete) - tot is exact too, so no tolerance.
        #expect(vm.eta == Self.fixedNow.addingTimeInterval(ete))
        #expect(vm.delta == ete - 100)
    }

    // MARK: - Display consistency: Time + ETE == ETA (B-40)

    /// A clock 0.7 s into a second. Realistic: the 1 Hz timer never fires on a whole second.
    private static let fractionalNow = Date(timeIntervalSinceReferenceDate: 800_000_000.7)
    /// `fractionalNow` with the sub-second part dropped; what the pilot sees as "Time".
    private static let fractionalNowFloor = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test("Time, ETE and ETA are truncated to whole seconds so the displayed readouts add up")
    func displayedTimePlusETEEqualsETA() async throws {
        let mockTimer = MockTimerScheduler()
        let vm = makeVM(settings: makeSettings(yellow: 5, red: 10),
                        timerScheduler: mockTimer,
                        now: { Self.fractionalNow })
        // ToT on the whole second the truncated ETA lands on, so delta must be exactly 0.
        vm.tot = Date(timeIntervalSinceReferenceDate: 800_000_059)
        // 595 m at 10 m/s -> raw ETE 59.5 s (exact in Double), which must truncate to 59 s.
        setDirectInputs(vm, speedMps: 10, distanceMeters: 595)

        mockTimer.fire()

        // Truncate, never round: Time drops the .7, ETE drops the .5, and ETA is built from
        // those two truncated values rather than from the raw ones (which would give
        // 800_000_060.2 and display one second later than Time + ETE).
        #expect(vm.currentTime == Self.fractionalNowFloor)
        #expect(vm.ete == 59)
        #expect(vm.eta == Date(timeIntervalSinceReferenceDate: 800_000_059))
        #expect(vm.delta == 0)
        #expect(vm.statusColor == .good)

        // The on-screen contract: the Time readout plus the ETE readout is the ETA readout.
        #expect(Formatting.durationHMS(vm.ete) == "00:00:59")
        let shownTime = try #require(vm.currentTime)
        let shownETE = try #require(vm.ete)
        #expect(Formatting.timeHHmmss(vm.eta)
                == Formatting.timeHHmmss(shownTime.addingTimeInterval(shownETE.rounded(.down))),
                "Time + ETE must render as the same second as ETA")
    }

    @Test("ETE is truncated to a whole second and ETA is derived from the truncated clock and ETE",
          arguments: eteTruncationCases)
    func eteTruncatesToWholeSecond(distanceMeters: Double, expectedETE: TimeInterval) async throws {
        let mockTimer = MockTimerScheduler()
        let vm = makeVM(settings: makeSettings(yellow: 5, red: 10),
                        timerScheduler: mockTimer,
                        now: { Self.fractionalNow })
        setDirectInputs(vm, speedMps: 10, distanceMeters: distanceMeters)

        mockTimer.fire()

        #expect(vm.currentTime == Self.fractionalNowFloor)
        #expect(vm.ete == expectedETE)
        #expect(vm.eta == Self.fractionalNowFloor.addingTimeInterval(expectedETE))
    }

    // MARK: - Midnight crossing (tests #13)
    @Test("ToT shortly after midnight is compared on absolute dates and renders as 00:00:10")
    func totCrossingMidnight() async throws {
        // Build both instants in the current calendar/time zone: Formatting.timeHHmmss formats in
        // the current time zone, so the expected string is only "00:00:10" if the date is built
        // the same way. Round to whole seconds so the delta arithmetic is exact.
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let lateTonightRaw = try #require(calendar.date(bySettingHour: 23, minute: 59, second: 50, of: startOfToday))
        let lateTonight = Date(timeIntervalSinceReferenceDate: lateTonightRaw.timeIntervalSinceReferenceDate.rounded())
        let tot = lateTonight.addingTimeInterval(20) // 00:00:10 tomorrow

        let mockTimer = MockTimerScheduler()
        let vm = makeVM(settings: makeSettings(yellow: 5, red: 10),
                        missionType: .tot,
                        missionDate: tot,
                        timerScheduler: mockTimer,
                        now: { lateTonight })

        // 200 m at 10 m/s -> ETE exactly 20 s, landing exactly on ToT across the day boundary.
        setDirectInputs(vm, speedMps: 10, distanceMeters: 200)
        mockTimer.fire()

        #expect(Formatting.timeHHmmss(vm.currentTime) == "23:59:50")
        #expect(Formatting.timeHHmmss(vm.tot) == "00:00:10")
        #expect(vm.ete == 20.0)
        #expect(vm.eta == tot)
        #expect(vm.delta == 0.0)
        #expect(vm.statusColor == .good)
    }

    // MARK: - Default tolerances (B-05)
    /// Drives the timing pipeline with the fixed clock so that `delta == absDelta` exactly
    /// (speed 10 m/s, distance `10 * absDelta` m, ToT = now) and returns the resulting status.
    private func statusForAbsDelta(_ absDelta: TimeInterval, settings: Settings) -> FlightViewModel.Status {
        let mockTimer = MockTimerScheduler()
        let vm = makeVM(settings: settings, timerScheduler: mockTimer, now: fixedClock)

        vm.tot = Self.fixedNow
        setDirectInputs(vm, speedMps: 10, distanceMeters: 10 * absDelta)

        mockTimer.fire()

        #expect(vm.delta == absDelta)
        return vm.statusColor
    }

    @Test("Settings.empty() tolerances treat a small 3 s delta as good")
    func defaultSettingsSmallDeltaIsGood() async throws {
        // B-05: with the shipped 0/0 tolerances, |delta| = 3 s fell straight through to reallyBad
        // because `absDelta <= 0` was the only path to .good. A fresh install must be forgiving
        // of a few seconds of drift.
        #expect(statusForAbsDelta(3, settings: Settings.empty()) == .good)
    }

    @Test("Settings.empty() tolerances map 20 s to bad and 45 s to reallyBad")
    func defaultSettingsMidAndLargeDelta() async throws {
        // Regression coverage for the chosen defaults (yellow 10 s, red 30 s).
        #expect(statusForAbsDelta(20, settings: Settings.empty()) == .bad)
        #expect(statusForAbsDelta(45, settings: Settings.empty()) == .reallyBad)
    }

    @Test("updateDelegate is wired to onLocationUpdate and invokable")
    func updateDelegateIsWired() async throws {
        let injectedProvider = MockLocationProvider()
        // Preconfigure provider state before injecting into the VM
        let presetSpeed: Measurement<UnitSpeed> = Measurement(value: 10, unit: .metersPerSecond)
        let presetCourse: Measurement<UnitAngle> = Measurement(value: 0, unit: .degrees)
        // We don't have vm yet, so set a placeholder location; we'll overwrite after vm is created
        injectedProvider.setLocation(location: CLLocation(latitude: 0, longitude: 0),
                                     speed: presetSpeed,
                                     course: presetCourse,
                                     notify: false)

        let settings = makeSettings()
        let vm = makeVM(settings: settings, timerScheduler: MockTimerScheduler(), locationProvider: injectedProvider, now: fixedClock)

        // updateDelegate is installed by start(), which makeVM calls.
        #expect(injectedProvider.updateDelegate != nil, "updateDelegate should be set on the injected provider")

        // Provide inputs that cause a visible side-effect when onLocationUpdate() runs
        vm.tot = Self.fixedNow.addingTimeInterval(30)

        // Act: invoke the delegate to simulate a provider update
        injectedProvider.updateDelegate?()

        // Assert: instruments updated via onLocationUpdate -> updateInstruments
        #expect(vm.currentGroundSpeed != nil, "Invoking updateDelegate should update instruments")
        #expect(vm.distance != nil)
        #expect(vm.bearing != nil)
    }

    // MARK: - Lifecycle (B-03)

    /// Builds a VM directly (no `start()`), so tests can observe init in isolation.
    /// Uses the wall clock deliberately: `stopTearsDown` relies on a real clock to prove a
    /// post-stop tick does not advance `currentTime`.
    private func makeUnstartedVM(provider: MockLocationProvider,
                                 timer: MockTimerScheduler,
                                 target: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)) -> FlightViewModel {
        FlightViewModel(missionName: "LIFECYCLE",
                        target: target,
                        missionType: .tot,
                        missionDate: Date().addingTimeInterval(60),
                        settings: makeSettings(),
                        locationProvider: provider,
                        timerScheduler: timer)
    }

    @Test("init has no side effects")
    func initHasNoSideEffects() async throws {
        let provider = MockLocationProvider()
        let timer = MockTimerScheduler()

        let vm = makeUnstartedVM(provider: provider, timer: timer)
        _ = vm

        #expect(provider.updateDelegate == nil, "init must not install itself as the provider delegate")
        #expect(provider.startMonitoringCallCount == 0, "init must not start GPS monitoring")
        #expect(timer.scheduleCallCount == 0, "init must not schedule the 1 Hz timer")
    }

    @Test("second VM does not hijack the provider delegate before start")
    func secondVMDoesNotHijackDelegate() async throws {
        let provider = MockLocationProvider()
        let target = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

        let vmA = makeUnstartedVM(provider: provider, timer: MockTimerScheduler(), target: target)
        vmA.start()

        // A throwaway instance, as happens when the fullScreenCover closure re-evaluates.
        let vmB = makeUnstartedVM(provider: provider, timer: MockTimerScheduler(), target: target)

        provider.setLocation(location: locationOffsetFromTarget(target, metersNorth: -500),
                             speed: Measurement(value: 10, unit: .metersPerSecond),
                             course: Measurement(value: 0, unit: .degrees),
                             notify: false)
        provider.updateDelegate?()

        #expect(vmA.distance != nil, "the started VM must still receive location updates")
        #expect(vmB.distance == nil, "an unstarted VM must not receive location updates")
    }

    @Test("stop tears down timer, delegate, and monitoring")
    func stopTearsDown() async throws {
        let provider = MockLocationProvider()
        let timer = MockTimerScheduler()
        let vm = makeUnstartedVM(provider: provider, timer: timer)

        vm.start()
        vm.stop()

        #expect(timer.isCancelled, "stop must cancel the timer token")
        #expect(provider.updateDelegate == nil, "stop must clear the provider delegate")
        #expect(provider.stopMonitoringCallCount == 1, "stop must stop GPS monitoring exactly once")

        // A timer tick after stop must not drive the clock.
        let frozen = vm.currentTime
        timer.fire()
        #expect(vm.currentTime == frozen, "timer must be inert after stop")
    }

    @Test("VM deallocates after stop")
    func viewModelDeallocatesAfterStop() async throws {
        let provider = MockLocationProvider()
        let timer = MockTimerScheduler()

        func makeStartStopAndRelease() -> FlightViewModel? {
            weak var weakVM: FlightViewModel?
            autoreleasepool {
                let vm = makeUnstartedVM(provider: provider, timer: timer)
                vm.start()
                vm.stop()
                weakVM = vm
            }
            return weakVM
        }

        let survivor = makeStartStopAndRelease()
        #expect(survivor == nil, "nothing may retain the VM once it has been stopped and released")
    }

    @Test("start is idempotent")
    func startIsIdempotent() async throws {
        let provider = MockLocationProvider()
        let timer = MockTimerScheduler()
        let vm = makeUnstartedVM(provider: provider, timer: timer)

        vm.start()
        vm.start()

        #expect(timer.scheduleCallCount == 1, "a second start must not schedule a second timer")
        #expect(provider.startMonitoringCallCount == 1, "a second start must not restart monitoring")
        #expect(provider.updateDelegate != nil)
        #expect(vm.currentTime != nil, "start must seed the clock so the UI shows a time before the first tick")
    }

    // MARK: - init(flight:) (B-23)
    /// Builds a VM from a persisted `Flight` the way `Go Fly` does. Constructing a `Flight`
    /// without a container is fine for a read-only model, as `FlightTests` already relies on.
    private func makeVM(from flight: Flight) -> FlightViewModel {
        FlightViewModel(flight: flight,
                        settings: makeSettings(),
                        locationProvider: MockLocationProvider(),
                        timerScheduler: MockTimerScheduler(),
                        now: fixedClock)
    }

    @Test("init(flight:) copies hackTime for a hack mission and leaves ToT nil")
    func initFromHackFlightCopiesHackTime() async throws {
        // A saved hack mission. `missionDate` is populated too, as the editor currently writes
        // both fields regardless of type (B-14); it must not leak into `tot` for a hack mission.
        let flight = Flight(missionName: "Hack Sortie",
                            missionType: .hackTime,
                            missionDate: Self.fixedNow.addingTimeInterval(600),
                            target: Target(longitude: -122.4194, latitude: 37.7749),
                            hackTime: 90)

        let vm = makeVM(from: flight)

        #expect(vm.missionType == .hackTime)
        #expect(vm.hackTime == 90, "the hack wheel and startHack() both read hackTime")
        #expect(vm.tot == nil, "a hack mission has no ToT until Hack! is pressed")
        #expect(vm.missionDate == Self.fixedNow.addingTimeInterval(600))
        #expect(vm.missionName == "Hack Sortie")
        #expect(vm.target.latitude == 37.7749)
        #expect(vm.target.longitude == -122.4194)
    }

    @Test("init(flight:) seeds ToT and missionDate from a .tot flight")
    func initFromTOTFlightSeedsToT() async throws {
        let missionDate = Self.fixedNow.addingTimeInterval(300)
        let flight = Flight(missionName: "TOT Sortie",
                            missionType: .tot,
                            missionDate: missionDate,
                            target: Target(longitude: -122.4194, latitude: 37.7749),
                            hackTime: nil)

        let vm = makeVM(from: flight)

        #expect(vm.missionType == .tot)
        #expect(vm.tot == missionDate)
        #expect(vm.missionDate == missionDate)
        #expect(vm.hackTime == nil)
    }

    // MARK: - Stale fix (B-07)
    @Test("Speed-derived readouts blank out once the newest fix is older than the stale threshold")
    func staleFixBlanksSpeedDerivedReadouts() async throws {
        #expect(FlightViewModel.staleFixThreshold == 15)

        let clock = MutableClock(Self.fixedNow)
        let lp = MockLocationProvider()
        let mockTimer = MockTimerScheduler()
        let vm = makeVM(settings: makeSettings(yellow: 5, red: 10),
                        timerScheduler: mockTimer,
                        locationProvider: lp,
                        now: { clock.now })
        vm.tot = Self.fixedNow.addingTimeInterval(1000)

        let tenMps = Measurement(value: 10, unit: UnitSpeed.metersPerSecond)
        let north = Measurement(value: 0, unit: UnitAngle.degrees)

        // Fix at t0: everything computes.
        lp.setLocation(location: locationOffsetFromTarget(vm.target, metersNorth: -1000),
                       speed: tenMps, course: north, notify: true)
        mockTimer.fire()
        #expect(vm.currentGroundSpeed == tenMps)
        #expect(vm.statusColor != .unknown)

        // t0 + 14 s with no new fix: still inside the threshold, readouts intact.
        clock.now = Self.fixedNow.addingTimeInterval(FlightViewModel.staleFixThreshold - 1)
        mockTimer.fire()
        #expect(vm.currentGroundSpeed == tenMps)
        #expect(vm.track == north)
        #expect(vm.ete != nil)
        #expect(vm.statusColor != .unknown)

        // t0 + 16 s: the fix is stale. Speed and everything derived from it must blank so the
        // pilot sees placeholders rather than an ETE counting down on a frozen number. Position
        // is still the last known, so distance and bearing stay.
        clock.now = Self.fixedNow.addingTimeInterval(FlightViewModel.staleFixThreshold + 1)
        mockTimer.fire()
        #expect(vm.currentGroundSpeed == nil)
        #expect(vm.track == nil)
        #expect(vm.ete == nil)
        #expect(vm.eta == nil)
        #expect(vm.delta == nil)
        #expect(vm.deltaLabel == nil)
        #expect(vm.statusColor == .unknown)
        #expect(vm.distance != nil, "last known position is still meaningful")
        #expect(vm.bearing != nil, "last known position is still meaningful")

        // A fresh fix brings the readouts back.
        lp.setLocation(location: locationOffsetFromTarget(vm.target, metersNorth: -900),
                       speed: tenMps, course: north, notify: true)
        mockTimer.fire()
        #expect(vm.currentGroundSpeed == tenMps)
        #expect(vm.track == north)
        #expect(vm.ete != nil)
        #expect(vm.statusColor != .unknown)
    }

    // MARK: - Published mutable state (B-18)
    @Test("Assigning hackTime, missionType and settings publishes a change")
    func mutableModelStateIsPublished() async throws {
        let vm = makeVM(settings: makeSettings(), missionType: .hackTime, hackTime: 60, now: fixedClock)

        var emissions = 0
        let subscription = vm.objectWillChange.sink { _ in emissions += 1 }
        defer { subscription.cancel() }

        // B-18: the in-flight hack wheel binds to `hackTime`; without `@Published` the view is
        // never told the value changed and the wheel can snap back to the old value.
        vm.hackTime = 45
        #expect(emissions == 1, "hackTime assignment must emit objectWillChange")

        vm.missionType = .tot
        #expect(emissions == 2, "missionType assignment must emit objectWillChange")

        vm.settings = makeSettings(yellow: 1, red: 2)
        #expect(emissions == 3, "settings assignment must emit objectWillChange")
    }

    // MARK: - Hack mission before "Hack!" (B-08)
    @Test("Hack mission before Hack! keeps current ground speed and only blanks required speed")
    func hackMissionBeforeHackKeepsCurrentGroundSpeed() async throws {
        let lp = MockLocationProvider()
        let vm = makeVM(settings: makeSettings(), missionType: .hackTime, hackTime: 120, locationProvider: lp, now: fixedClock)
        // No "Hack!" yet, so there is no ToT to compute a required speed against.
        #expect(vm.tot == nil)

        lp.setLocation(location: locationOffsetFromTarget(vm.target, metersNorth: -1000),
                       speed: Measurement(value: 10, unit: .metersPerSecond),
                       course: Measurement(value: 0, unit: .degrees),
                       notify: true)

        // B-08: the GPS just reported 10 m/s; the pilot must see it even though the clock has
        // not been hacked. Only the required speed depends on ToT.
        #expect(vm.currentGroundSpeed == Measurement(value: 10, unit: .metersPerSecond))
        #expect(vm.requiredGroundSpeed == nil)
        #expect(vm.distance != nil)
        #expect(vm.track != nil)
    }

    // MARK: - Turn-in model (B-25)

    /// Places the aircraft `meters` away from `target` so that the bearing from aircraft to
    /// target is `bearingDegrees` (flat-earth offsets; the tests read back the VM's own
    /// distance and bearing rather than assuming these are exact).
    private func location(fromTarget target: CLLocationCoordinate2D, bearingDegrees: Double, meters: Double) -> CLLocation {
        let metersPerDegreeLat = 111_320.0
        let metersPerDegreeLon = metersPerDegreeLat * cos(target.latitude.degreesToRadians)
        // The aircraft sits on the reciprocal bearing from the target.
        let back = bearingDegrees + 180
        let dLat = meters * cos(back.degreesToRadians) / metersPerDegreeLat
        let dLon = meters * sin(back.degreesToRadians) / metersPerDegreeLon
        return CLLocation(latitude: target.latitude + dLat, longitude: target.longitude + dLon)
    }

    @Test("ETE with the target abeam includes the standard-rate turn onto it")
    func eteIncludesTurnOntoTarget() async throws {
        let lp = MockLocationProvider()
        let mockTimer = MockTimerScheduler()
        let vm = makeVM(settings: makeSettings(), timerScheduler: mockTimer, locationProvider: lp, now: fixedClock)
        vm.tot = Self.fixedNow.addingTimeInterval(600)

        // Flying north at 100 m/s with the target 8 km due east.
        lp.setLocation(location: location(fromTarget: vm.target, bearingDegrees: 90, meters: 8_000),
                       speed: Measurement(value: 100, unit: .metersPerSecond),
                       course: Measurement(value: 0, unit: .degrees),
                       notify: true)
        mockTimer.fire()

        let distance = try #require(vm.distance?.converted(to: .meters).value)
        let bearing = try #require(vm.bearing?.converted(to: .degrees).value)
        let expected = try #require(TurnToTarget.solve(distance: distance, bearing: bearing, track: 0, groundSpeed: 100))
        let ete = try #require(vm.ete)
        #expect(ete == expected.totalTime.rounded(.down))
        // The turn is what makes ETE exceed the straight-line figure.
        #expect(ete > (distance / 100).rounded(.down))
        #expect(vm.turnDuration == expected.turnDuration.rounded(.down))
        #expect(vm.turnDirection == nil, "two fixes with the same course are straight flight")
    }

    @Test("Aligned with the target the turn model reduces to distance over speed")
    func eteAlignedMatchesDirectTo() async throws {
        let lp = MockLocationProvider()
        let mockTimer = MockTimerScheduler()
        let vm = makeVM(settings: makeSettings(), timerScheduler: mockTimer, locationProvider: lp, now: fixedClock)

        lp.setLocation(location: locationOffsetFromTarget(vm.target, metersNorth: -1_000),
                       speed: Measurement(value: 10, unit: .metersPerSecond),
                       course: Measurement(value: 0, unit: .degrees),
                       notify: true)
        mockTimer.fire()

        let distance = try #require(vm.distance?.converted(to: .meters).value)
        #expect(vm.ete == (distance / 10).rounded(.down))
        #expect(vm.turnDuration == nil)
    }

    @Test("Required ground speed solves the turn-then-straight path for the time remaining")
    func requiredSpeedIsTurnAware() async throws {
        let lp = MockLocationProvider()
        let mockTimer = MockTimerScheduler()
        let vm = makeVM(settings: makeSettings(), timerScheduler: mockTimer, locationProvider: lp, now: fixedClock)
        vm.tot = Self.fixedNow.addingTimeInterval(200)

        lp.setLocation(location: location(fromTarget: vm.target, bearingDegrees: 90, meters: 8_000),
                       speed: Measurement(value: 100, unit: .metersPerSecond),
                       course: Measurement(value: 0, unit: .degrees),
                       notify: true)
        mockTimer.fire()

        let distance = try #require(vm.distance?.converted(to: .meters).value)
        let bearing = try #require(vm.bearing?.converted(to: .degrees).value)
        let required = try #require(vm.requiredGroundSpeed?.converted(to: .metersPerSecond).value)
        let expected = try #require(TurnToTarget.requiredGroundSpeed(distance: distance, bearing: bearing, track: 0,
                                                                     timeRemaining: 200))
        #expect(abs(required - expected) < 1e-6)
        // Flying that speed along the modelled path lands exactly on ToT.
        let check = try #require(TurnToTarget.solve(distance: distance, bearing: bearing, track: 0, groundSpeed: required))
        #expect(abs(check.totalTime - 200) < 0.01)
        #expect(required > distance / 200, "turning costs time, so the required speed exceeds direct-to")
    }

    @Test("An orbit in progress is continued rather than reversed")
    func continuesDetectedOrbit() async throws {
        let lp = MockLocationProvider()
        let mockTimer = MockTimerScheduler()
        let clock = MutableClock(Self.fixedNow)
        let vm = makeVM(settings: makeSettings(), timerScheduler: mockTimer, locationProvider: lp, now: { clock.now })
        vm.tot = Self.fixedNow.addingTimeInterval(900)

        // Three fixes a second apart with the course swinging right at standard rate.
        let aircraft = location(fromTarget: vm.target, bearingDegrees: 300, meters: 8_000)
        for course in [354.0, 357.0, 0.0] {
            lp.setLocation(location: aircraft,
                           speed: Measurement(value: 100, unit: .metersPerSecond),
                           course: Measurement(value: course, unit: .degrees),
                           fixTime: clock.now,
                           notify: true)
            clock.advance(by: 1)
        }
        mockTimer.fire()

        #expect(vm.turnDirection == .right)
        let distance = try #require(vm.distance?.converted(to: .meters).value)
        let bearing = try #require(vm.bearing?.converted(to: .degrees).value)
        // The target is 60° to the LEFT, so the shortest turn would be left; the model must
        // keep turning right the long way round because that is the orbit being flown.
        let continued = try #require(TurnToTarget.solve(distance: distance, bearing: bearing, track: 0,
                                                        groundSpeed: 100, preferredDirection: .right))
        let reversed = try #require(TurnToTarget.solve(distance: distance, bearing: bearing, track: 0, groundSpeed: 100))
        #expect(continued.direction == .right)
        #expect(reversed.direction == .left)
        #expect(vm.ete == continued.totalTime.rounded(.down))
        #expect(try #require(vm.ete) > reversed.totalTime.rounded(.down))
    }

    @Test("Required ground speed for a close-in target abeam stays turn-aware (B-42)")
    func requiredSpeedCloseInAbeam() async throws {
        let lp = MockLocationProvider()
        let mockTimer = MockTimerScheduler()
        let vm = makeVM(settings: makeSettings(), timerScheduler: mockTimer, locationProvider: lp, now: fixedClock)
        vm.tot = Self.fixedNow.addingTimeInterval(100)

        // Flying north with the target 2 nm due east and 100 s to ToT. The pre-fix solver
        // showed the direct-to 37 m/s here and the aircraft arrived 13 s late.
        lp.setLocation(location: location(fromTarget: vm.target, bearingDegrees: 90, meters: 3_704),
                       speed: Measurement(value: 40, unit: .metersPerSecond),
                       course: Measurement(value: 0, unit: .degrees),
                       notify: true)
        mockTimer.fire()

        let distance = try #require(vm.distance?.converted(to: .meters).value)
        let bearing = try #require(vm.bearing?.converted(to: .degrees).value)
        let required = try #require(vm.requiredGroundSpeed?.converted(to: .metersPerSecond).value)
        let check = try #require(TurnToTarget.solve(distance: distance, bearing: bearing, track: 0, groundSpeed: required))
        #expect(abs(check.totalTime - 100) < 0.01)
        #expect(required > distance / 100 + 1, "must not fall back to the direct-to figure")
    }

    @Test("The turn detector runs on fix timestamps, not the wall clock (B-44)")
    func turnDetectorUsesFixTimestamps() async throws {
        let target = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let aircraft = location(fromTarget: target, bearingDegrees: 300, meters: 8_000)
        let speed = Measurement<UnitSpeed>(value: 100, unit: .metersPerSecond)

        // Fixes measured a second apart but delivered while the wall clock stands still (a
        // batched delivery): the turn is still seen.
        let lp = MockLocationProvider()
        let vm = makeVM(settings: makeSettings(), target: target, locationProvider: lp, now: fixedClock)
        for (i, course) in [354.0, 357.0, 0.0].enumerated() {
            lp.setLocation(location: aircraft, speed: speed, course: Measurement(value: course, unit: .degrees),
                           fixTime: Self.fixedNow.addingTimeInterval(Double(i)), notify: true)
        }
        #expect(vm.turnDirection == .right)

        // The reverse: the wall clock advances but the fix timestamp is frozen (the same fix
        // delivered again). No new samples, so no turn.
        let lp2 = MockLocationProvider()
        let clock = MutableClock(Self.fixedNow)
        let vm2 = makeVM(settings: makeSettings(), target: target, locationProvider: lp2, now: { clock.now })
        for course in [354.0, 357.0, 0.0] {
            lp2.setLocation(location: aircraft, speed: speed, course: Measurement(value: course, unit: .degrees),
                            fixTime: Self.fixedNow, notify: true)
            clock.advance(by: 1)
        }
        #expect(vm2.turnDirection == nil)
    }

    @Test("Turn duration and direction are published for the ETE caption (B-45)")
    func turnCaptionInputs() async throws {
        let lp = MockLocationProvider()
        let mockTimer = MockTimerScheduler()
        let vm = makeVM(settings: makeSettings(), timerScheduler: mockTimer, locationProvider: lp, now: fixedClock)
        vm.tot = Self.fixedNow.addingTimeInterval(600)

        lp.setLocation(location: location(fromTarget: vm.target, bearingDegrees: 90, meters: 8_000),
                       speed: Measurement(value: 100, unit: .metersPerSecond),
                       course: Measurement(value: 0, unit: .degrees),
                       notify: true)
        mockTimer.fire()

        // Straight flight with the target to the right: the shortest turn-in is right.
        #expect(vm.turnInDirection == .right)
        let caption = try #require(vm.turnCaption)
        #expect(caption.hasPrefix("TURN "))
        #expect(caption.hasSuffix(" R"))
    }

    @Test("Δ caption adds an orbit hint once early by a full standard-rate orbit")
    func deltaCaptionShowsSurplusOrbits() async throws {
        let mockTimer = MockTimerScheduler()
        let vm = makeVM(settings: makeSettings(), timerScheduler: mockTimer, now: fixedClock)
        setDirectInputs(vm, speedMps: 10, distanceMeters: 100)   // ete = 10 s

        vm.tot = Self.fixedNow.addingTimeInterval(10 + 30)       // 30 s early
        mockTimer.fire()
        #expect(vm.delta == -30)
        #expect(vm.deltaLabel == "EARLY")

        vm.tot = Self.fixedNow.addingTimeInterval(10 + 130)      // 130 s early: one orbit fits
        mockTimer.fire()
        #expect(vm.delta == -130)
        #expect(vm.deltaLabel == "EARLY · +1 ORBIT")

        vm.tot = Self.fixedNow.addingTimeInterval(10 + 250)      // 250 s early: two orbits
        mockTimer.fire()
        #expect(vm.deltaLabel == "EARLY · +2 ORBIT")

        vm.tot = Self.fixedNow.addingTimeInterval(10 - 5)        // late: no hint
        mockTimer.fire()
        #expect(vm.deltaLabel == "LATE")
    }
}

// MARK: - InstrumentLayout (B-12)

/// `InstrumentLayout` is the pure half of B-12: the Instruments section was hard-wired to five
/// cards and ignored `settings.instrumentSettings` entirely, so disabling or reordering an
/// instrument in Settings had no effect in flight.
@Suite("InstrumentLayout")
struct InstrumentLayoutTests {
    private func setting(_ type: InFlightInfo, enabled: Bool = true) -> InstrumentSetting {
        InstrumentSetting(type: type, isEnabled: enabled)
    }

    @Test("Disabled instruments are filtered out")
    func disabledInstrumentsAreHidden() throws {
        let settings = [
            setting(.currentGroundSpeed),
            setting(.requiredGroundSpeed, enabled: false),
            setting(.distance),
            setting(.bearing),
            setting(.track, enabled: false),
        ]
        #expect(InstrumentLayout.visibleInstruments(from: settings) == [.currentGroundSpeed, .distance, .bearing])
    }

    @Test("Saved order is preserved")
    func savedOrderIsPreserved() throws {
        let settings = [
            setting(.track),
            setting(.bearing),
            setting(.distance),
            setting(.requiredGroundSpeed),
            setting(.currentGroundSpeed),
        ]
        #expect(InstrumentLayout.visibleInstruments(from: settings)
                == [.track, .bearing, .distance, .requiredGroundSpeed, .currentGroundSpeed])
    }

    @Test("Cases without an instrument card are dropped even when enabled")
    func unsupportedCasesAreDropped() throws {
        let settings = [
            setting(.tot),
            setting(.totDrift),
            setting(.expectedWindsDirection),
            setting(.distance),
            setting(.expectedWindsVelocity),
        ]
        #expect(InstrumentLayout.visibleInstruments(from: settings) == [.distance])
    }

    @Test("No settings means no instruments")
    func emptySettingsShowNothing() throws {
        #expect(InstrumentLayout.visibleInstruments(from: []) == [])
        let allOff = InstrumentLayout.supported.map { setting($0, enabled: false) }
        #expect(InstrumentLayout.visibleInstruments(from: allOff) == [])
    }

    @Test("Defaults show all five cards in the shipped order")
    func defaultSettingsShowAllSupported() throws {
        #expect(InstrumentLayout.visibleInstruments(from: Settings.empty().instrumentSettings)
                == [.currentGroundSpeed, .requiredGroundSpeed, .distance, .bearing, .track])
    }

    @Test("Rows are chunked three then the remainder, in order")
    func rowsChunkThreeThenRemainder() throws {
        let five: [InFlightInfo] = [.currentGroundSpeed, .requiredGroundSpeed, .distance, .bearing, .track]
        #expect(InstrumentLayout.rows(for: five) == [[.currentGroundSpeed, .requiredGroundSpeed, .distance], [.bearing, .track]])

        let four: [InFlightInfo] = [.track, .bearing, .distance, .currentGroundSpeed]
        #expect(InstrumentLayout.rows(for: four) == [[.track, .bearing, .distance], [.currentGroundSpeed]])

        let three: [InFlightInfo] = [.distance, .bearing, .track]
        #expect(InstrumentLayout.rows(for: three) == [[.distance, .bearing, .track]])

        let two: [InFlightInfo] = [.bearing, .track]
        #expect(InstrumentLayout.rows(for: two) == [[.bearing, .track]])

        #expect(InstrumentLayout.rows(for: []).isEmpty)
    }

    @Test("Accessibility text sizes give each card its own row (D-04)")
    func accessibilitySizesUseOneCardPerRow() throws {
        #expect(InstrumentLayout.cardsPerRow(for: .large) == 3)
        #expect(InstrumentLayout.cardsPerRow(for: .xxxLarge) == 3)
        #expect(InstrumentLayout.cardsPerRow(for: .accessibility1) == 1)
        #expect(InstrumentLayout.cardsPerRow(for: .accessibility5) == 1)

        let three: [InFlightInfo] = [.distance, .bearing, .track]
        #expect(InstrumentLayout.rows(for: three, perRow: 1) == [[.distance], [.bearing], [.track]])
        #expect(InstrumentLayout.rows(for: three, perRow: 0) == [[.distance], [.bearing], [.track]])
    }
}
