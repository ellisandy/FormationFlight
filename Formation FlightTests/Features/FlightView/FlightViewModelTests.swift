import Foundation
import Combine
import CoreLocation
import Testing
@testable import Formation_Flight

// Protocol-based mock for LocationProviding used by FlightViewModel.
// This is a standalone class that conforms to the protocol; it does not subclass the
// production LocationProvider, so every stored property here is plain test state.
// `LocationProviding` is a MainActor protocol (B-27), so the mock is MainActor too.
@MainActor
final class MockLocationProvider: LocationProviding {
    var authroizationStatus: CLAuthorizationStatus?

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

    func startMonitoring() {
        startMonitoringCallCount += 1
    }

    /// Convenience to set location-related fields and optionally notify the delegate.
    func setLocation(location: CLLocation?,
                     speed: Measurement<UnitSpeed> = Measurement(value: 0, unit: .metersPerSecond),
                     course: Measurement<UnitAngle>? = nil,
                     notify: Bool = false) {
        self.currentLocation = location
        self.speed = speed
        if let course { self.course = course }
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

        // Required GS = distance / time remaining, with time remaining taken from the injected clock.
        let rgs = try #require(vm.requiredGroundSpeed)
        let expectedMps = distance.converted(to: .meters).value / 60
        #expect(abs(rgs.converted(to: .metersPerSecond).value - expectedMps) < 1e-6)
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
        #expect(abs(rgs.converted(to: .metersPerSecond).value - expectedMps) < 1e-6)
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
}
