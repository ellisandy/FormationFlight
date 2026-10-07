import Foundation
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
        let target = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let vm = makeVM(settings: makeSettings(), target: target, locationProvider: lp, now: fixedClock)

        vm.tot = Self.fixedNow.addingTimeInterval(60) // 60 seconds to go

        // Aircraft ~0.01 deg west of the target, tracking east toward it.
        lp.setLocation(location: CLLocation(latitude: target.latitude, longitude: target.longitude - 0.01),
                       speed: Measurement(value: 10, unit: .metersPerSecond),
                       course: Measurement(value: 90, unit: .degrees))

        vm.onLocationUpdate()

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
        let vm = makeVM(settings: makeSettings(), locationProvider: lp, now: fixedClock)
        vm.tot = Self.fixedNow.addingTimeInterval(120)

        // Aircraft ~0.01 deg east of the target (bearing ~270), tracking west.
        lp.setLocation(location: CLLocation(latitude: vm.target.latitude, longitude: vm.target.longitude + 0.01),
                       speed: Measurement(value: 30, unit: .metersPerSecond),
                       course: Measurement(value: 270, unit: .degrees))

        vm.onLocationUpdate()

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
        let vm = makeVM(settings: makeSettings(), locationProvider: lp, now: fixedClock)
        lp.setLocation(location: CLLocation(latitude: vm.target.latitude, longitude: vm.target.longitude - 0.01),
                       speed: Measurement(value: 10, unit: .metersPerSecond),
                       course: Measurement(value: 90, unit: .degrees))

        // ToT exactly now: zero time remaining.
        vm.tot = Self.fixedNow
        vm.onLocationUpdate()
        #expect(vm.requiredGroundSpeed == nil)

        // ToT already past.
        vm.tot = Self.fixedNow.addingTimeInterval(-1)
        vm.onLocationUpdate()
        #expect(vm.requiredGroundSpeed == nil)

        // ToT in the future: computable again.
        vm.tot = Self.fixedNow.addingTimeInterval(1)
        vm.onLocationUpdate()
        #expect(vm.requiredGroundSpeed != nil)
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

        let ete = try #require(vm.ete)
        #expect(abs(ete - 100) < 1)
        #expect(ete == distance / 10, "ETE must be derived from the reported distance and speed")

        let bearing = try #require(vm.bearing)
        #expect(abs(bearing.converted(to: .degrees).value) < 0.001, "target is due north")

        // ETA follows from the injected clock, so it is exactly now + ETE. Delta is
        // (now + ete) - tot; adding a non-integral ETE to a date of magnitude 8e8 rounds at
        // ~1e-7 s, so compare with a tolerance far below anything the pipeline could get wrong.
        #expect(vm.eta == Self.fixedNow.addingTimeInterval(ete))
        let delta = try #require(vm.delta)
        #expect(abs(delta - (ete - 100)) < 1e-6)
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
}
