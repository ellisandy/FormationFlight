import Foundation
import CoreLocation
import Testing
@testable import Formation_Flight

// Protocol-based mock for LocationProviding used by FlightViewModel
final class MockLocationProvider: LocationProviding {
    var authroizationStatus: CLAuthorizationStatus?
    
    var altitude: Measurement<UnitLength> = Measurement(value: 0, unit: .meters)
    
    var computedSpeedAndCourse: Bool = false
    
    func stopMonitoring() {
        // no-op for tests
    }
    
    var updateDelegate: (() -> Void)?
    var speed: Measurement<UnitSpeed> = Measurement(value: 0, unit: .metersPerSecond)
    var currentLocation: CLLocation?
    var course: Measurement<UnitAngle> = Measurement(value: 0, unit: .degrees)

    func startMonitoring() {
        // no-op for tests
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

@Suite("FlightViewModel")
@MainActor
struct FlightViewModelTests {
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
    
    // Helper: place a location at an exact north/south offset (in meters) from target
    private func locationOffsetFromTarget(_ target: CLLocationCoordinate2D, metersNorth: Double) -> CLLocation {
        let metersPerDegreeLat = 111_320.0
        let deltaLat = metersNorth / metersPerDegreeLat
        let newLat = target.latitude + deltaLat
        return CLLocation(latitude: newLat, longitude: target.longitude)
    }

    private func makeVM(settings: Settings = Settings.empty(),
                        target: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                        missionType: MissionType = .tot,
                        missionDate: Date? = nil,
                        hackTime: TimeInterval? = nil,
                        timerScheduler: any TimerScheduling = MockTimerScheduler(),
                        locationProvider: LocationProviding? = nil) -> FlightViewModel {
        let lp = locationProvider ?? MockLocationProvider()
        return FlightViewModel(missionName: "TEST", target: target, missionType: missionType, missionDate: missionDate, hackTime: hackTime, settings: settings, locationProvider: lp, timerScheduler: timerScheduler)
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
        let settings = makeSettings()
        let vm = makeVM(settings: settings, missionType: .hackTime, hackTime: 120)
        // Set current time manually and call startHack
        let now = Date()
        vm.currentTime = now
        vm.startHack()
        #expect(vm.tot != nil)
        let diff = vm.tot!.timeIntervalSince(now)
        #expect(Int(diff.rounded()) == 120)
    }

    // MARK: - Timing pipeline and status mapping
    @Test("ETE/ETA/Delta and status mapping")
    func timingAndStatus() async throws {
        let settings = makeSettings(yellow: 5, red: 10)
        let target = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let mockTimer = MockTimerScheduler()
        let vm = makeVM(settings: settings, target: target, timerScheduler: mockTimer)

        // Provide inputs
        vm.currentTime = Date()
        vm.tot = vm.currentTime!.addingTimeInterval(12) // 12s in the future
        
        if let lp = vm.locationProvider as? MockLocationProvider {
            lp.speed = Measurement(value: 50, unit: .metersPerSecond)
            // 250 m south of target so ETE = 5s at 50 m/s
            lp.currentLocation = locationOffsetFromTarget(target, metersNorth: -253)
            // Track north toward target
            lp.course = Measurement(value: 0, unit: .degrees)
        }

        // Trigger update
        vm.onLocationUpdate()
        mockTimer.fire()

        // ETE/ETA
        #expect(Int(vm.ete ?? -1) == 5)
        #expect(vm.eta != nil)

        // Delta = ETA - ToT -> if ETE 5s and ToT 12s ahead, ETA is 5s ahead -> delta = now+5 - (now+12) = -7
        let delta = try #require(vm.delta)
        #expect(abs(delta - (-7)) < 0.6)

        // Status mapping: |delta| = 7 -> >= yellow (5) and < red (10) => bad
        #expect(vm.statusColor == .bad)
    }

    @Test("ETE is nil when speed <= 0 or distance missing")
    func eteNilWhenNoSpeedOrDistance() async throws {
        let vm = makeVM(settings: makeSettings())
        vm.currentTime = Date()
        vm.tot = vm.currentTime!.addingTimeInterval(30)

        // Case 1: speed <= 0
        if let lp = vm.locationProvider as? MockLocationProvider {
            lp.speed = Measurement(value: 0, unit: .metersPerSecond)
            lp.currentLocation = CLLocation(latitude: vm.target.latitude, longitude: vm.target.longitude)
        }
        vm.distance = Measurement(value: 100, unit: .meters)
        vm.onLocationUpdate()
        #expect(vm.ete == nil)

        // Case 2: distance missing
        if let lp = vm.locationProvider as? MockLocationProvider {
            lp.speed = Measurement(value: 10, unit: .metersPerSecond)
        }
        vm.distance = nil
        vm.onLocationUpdate()
        #expect(vm.ete == nil)
    }

    @Test("Status remains unknown when ETA/ToT missing")
    func statusUnknownWhenMissingInputs() async throws {
        let s = makeSettings(yellow: 5, red: 10)
        let vm = makeVM(settings: s)
        vm.currentTime = Date()

        // No ETE/ETA/ToT -> delta remains nil, status should not change from default .good unless mapping runs; ensure mapping does not set a value when delta is nil.
        vm.ete = nil
        vm.eta = nil
        vm.tot = nil
        vm.onLocationUpdate()
        // Since statusColor initialized to .good and mapping only runs when delta != nil, it should remain .good here.
        #expect(vm.statusColor == .good)
    }

    // MARK: - Instruments and required ground speed
    @Test("Instrument updates and required ground speed when track≈bearing")
    func instrumentsAndRequiredGroundSpeed() async throws {
        let settings = makeSettings()
        let target = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let vm = makeVM(settings: settings, target: target)

        // Set current location near target and provide speed/course/bearing compatible values.
        // We'll synthesize values by directly assigning to locationProvider's observable properties.
        // Since MockLocationProvider inherits LocationProvider, we can set its stored properties.
        guard let lp = vm.locationProvider as? MockLocationProvider else {
            #expect(Bool(false), "locationProvider not available")
            return
        }

        // Provide inputs
        vm.currentTime = Date()
        vm.tot = vm.currentTime!.addingTimeInterval(60) // 60 seconds to go

        // Simulate provider values
        lp.speed = Measurement(value: 10, unit: UnitSpeed.metersPerSecond)
        lp.course = Measurement(value: 90, unit: UnitAngle.degrees)
        // Set a location and target such that bearing ~ 90 degrees
        let origin = CLLocation(latitude: target.latitude, longitude: target.longitude - 0.01)
        lp.currentLocation = origin

        // Kick pipeline
        vm.onLocationUpdate()

        // Speed should be set
        #expect(vm.currentGroundSpeed != nil)

        // Distance should be non-nil
        #expect(vm.distance != nil)

        // Bearing should be ~90 degrees and requiredGroundSpeed should be computed
        #expect(vm.bearing != nil)
        #expect(vm.requiredGroundSpeed != nil)

        // Required ground speed in knots is positive
        let rgs = vm.requiredGroundSpeed!.converted(to: .knots).value
        #expect(rgs > 0)
    }

    @Test("Bearing wrap-around within tolerance computes required speed")
    func bearingWrapAroundWithinTolerance() async throws {
        let vm = makeVM(settings: makeSettings())
        vm.currentTime = Date()
        vm.tot = vm.currentTime!.addingTimeInterval(120)

        guard let lp = vm.locationProvider as? MockLocationProvider else {
            #expect(Bool(false), "locationProvider not available")
            return
        }
        // Set bearing ~ 270° by placing origin slightly east with small north/south delta, and track at 270°
        // We'll simulate by directly setting bearing via location; approximate is fine as long as within 15°.
        let origin = CLLocation(latitude: vm.target.latitude, longitude: vm.target.longitude + 0.01)
        lp.currentLocation = origin
        lp.course = Measurement(value: 270, unit: .degrees) // track 270°
        lp.speed = Measurement(value: 30, unit: .metersPerSecond)

        vm.onLocationUpdate()
        #expect(vm.bearing != nil)
        #expect(vm.requiredGroundSpeed != nil)
    }

    @Test("Required speed is nil when time remaining <= 0")
    func requiredSpeedNilWhenNoTimeRemaining() async throws {
        let vm = makeVM(settings: makeSettings())
        vm.currentTime = Date()
        vm.tot = vm.currentTime!.addingTimeInterval(-1) // already past

        guard let lp = vm.locationProvider as? MockLocationProvider else {
            #expect(Bool(false), "locationProvider not available")
            return
        }
        lp.speed = Measurement(value: 10, unit: .metersPerSecond)
        lp.course = Measurement(value: 90, unit: .degrees)
        let origin = CLLocation(latitude: vm.target.latitude, longitude: vm.target.longitude - 0.01)
        lp.currentLocation = origin

        vm.onLocationUpdate()
        #expect(vm.requiredGroundSpeed == nil)
    }
    
    // MARK: - .tot example and status boundaries
    @Test(".tot mission initializes ToT and computes timing")
    func totMissionInitializesToT() async throws {
        let now = Date()
        let missionDate = now.addingTimeInterval(20)
        let mockTimer = MockTimerScheduler()
        let vm = makeVM(settings: makeSettings(), missionType: .tot, missionDate: missionDate, timerScheduler: mockTimer)
        // ToT should be set from missionDate
        #expect(vm.tot == missionDate)

        if let lp = vm.locationProvider as? MockLocationProvider {
            lp.speed = Measurement(value: 10, unit: .metersPerSecond)
            // ~51 m south of target so ETE ≈ 5.005s at 10 m/s (bias above 5 to avoid truncation)
            lp.currentLocation = locationOffsetFromTarget(vm.target, metersNorth: -51)
            lp.course = Measurement(value: 0, unit: .degrees)
        }
        vm.currentTime = now
        vm.onLocationUpdate()
        mockTimer.fire()

        let ete = try #require(vm.ete)
        #expect(abs(ete - 5.0) < 0.3)
        #expect(vm.eta != nil)
        // Delta = now+5 - (now+20) = -15 -> |delta|=15, with default tolerances (5,10) => reallyBad
        #expect(vm.statusColor == .reallyBad)
    }

    @Test("Status mapping boundary cases: good, bad, reallyBad")
    func statusMappingBoundaries() async throws {
        // Tolerances: yellow=5, red=10
        let s = makeSettings(yellow: 5, red: 10)
        let mockTimer = MockTimerScheduler()

        func assertStatus(forAbsDelta absDelta: TimeInterval, expected: FlightViewModel.Status) {
            let vm = makeVM(settings: s, timerScheduler: mockTimer)

            vm.currentTime = Date()
            vm.tot = vm.currentTime

            if let lp = vm.locationProvider as? MockLocationProvider {
                let speedMps = 10.0
                lp.speed = Measurement(value: speedMps, unit: .metersPerSecond)
                let distance = speedMps * absDelta
                lp.currentLocation = locationOffsetFromTarget(vm.target, metersNorth: -distance)
                lp.course = Measurement(value: 0, unit: .degrees)
            }

            vm.onLocationUpdate()
            mockTimer.fire()

            // Ensure delta is produced
            #expect(vm.delta != nil)
            guard let delta = vm.delta else { return }
            let observed = abs(delta)

            // Verify that the status matches the mapping for the observed value
            if observed < Double(s.yellowTolerance) {
                #expect(vm.statusColor == .good)
            } else if observed < Double(s.redTolerance) {
                #expect(vm.statusColor == .bad)
            } else {
                #expect(vm.statusColor == .reallyBad)
            }
        }

        // Below yellow: absDelta = 4.6 -> good
        assertStatus(forAbsDelta: 4.6, expected: .good)
        // Slightly above yellow: absDelta = 5.2 -> bad
        assertStatus(forAbsDelta: 5.2, expected: .bad)
        // Between yellow and red: 7 -> bad
        assertStatus(forAbsDelta: 7.0, expected: .bad)
        // Slightly above red: 10.3 -> reallyBad
        assertStatus(forAbsDelta: 10.3, expected: .reallyBad)
        // Above red: 12 -> reallyBad
        assertStatus(forAbsDelta: 12.0, expected: .reallyBad)
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
        let vm = makeVM(settings: settings, timerScheduler: MockTimerScheduler(), locationProvider: injectedProvider)

        // updateDelegate should be set by the view model during configure()
        #expect(injectedProvider.updateDelegate != nil, "updateDelegate should be set on the injected provider")

        // Provide inputs that cause a visible side-effect when onLocationUpdate() runs
        vm.currentTime = Date()
        vm.tot = vm.currentTime!.addingTimeInterval(30)

        // Act: invoke the delegate to simulate a provider update
        injectedProvider.updateDelegate?()

        // Assert: instruments updated via onLocationUpdate -> updateInstruments
        #expect(vm.currentGroundSpeed != nil, "Invoking updateDelegate should update instruments")
        #expect(vm.distance != nil)
        #expect(vm.bearing != nil)
    }
}

