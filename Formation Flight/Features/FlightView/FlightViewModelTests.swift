import Foundation
import CoreLocation
import Testing
@testable import Formation_Flight

// Lightweight mock for LocationProvider used by FlightViewModel
final class MockLocationProvider: LocationProvider {
    override init() {
        super.init()
    }

    override func startMonitoring() {
        // no-op for tests
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

    private func makeVM(settings: Settings = Settings.empty(),
                        target: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                        missionType: MissionType = .tot,
                        missionDate: Date? = nil,
                        hackTime: TimeInterval? = nil) -> FlightViewModel {
        let lp = MockLocationProvider()
        return FlightViewModel(missionName: "TEST", target: target, missionType: missionType, missionDate: missionDate, hackTime: hackTime, settings: settings, locationProvider: lp)
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
        var settings = makeSettings()
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
        var settings = makeSettings(yellow: 5, red: 10)
        let target = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let vm = makeVM(settings: settings, target: target)

        // Provide inputs
        vm.currentTime = Date()
        vm.tot = vm.currentTime!.addingTimeInterval(12) // 12s in the future
        vm.currentGroundSpeed = Measurement(value: 50, unit: UnitSpeed.metersPerSecond)
        vm.distance = Measurement(value: 250, unit: UnitLength.meters) // ETE = 5s

        // Trigger update
        vm.onLocationUpdate()

        // ETE/ETA
        #expect(Int(vm.ete ?? -1) == 5)
        #expect(vm.eta != nil)

        // Delta = ETA - ToT -> if ETE 5s and ToT 12s ahead, ETA is 5s ahead -> delta = now+5 - (now+12) = -7
        #expect(Int(vm.delta ?? 0) == -7)

        // Status mapping: |delta| = 7 -> >= yellow (5) and < red (10) => bad
        #expect(vm.statusColor == .bad)
    }

    // MARK: - Instruments and required ground speed
    @Test("Instrument updates and required ground speed when track≈bearing")
    func instrumentsAndRequiredGroundSpeed() async throws {
        var settings = makeSettings()
        let target = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let vm = makeVM(settings: settings, target: target)

        // Set current location near target and provide speed/course/bearing compatible values.
        // We'll synthesize values by directly assigning to locationProvider's observable properties.
        // Since MockLocationProvider inherits LocationProvider, we can set its stored properties.
        guard let lp = vm.locationProvider as? LocationProvider else {
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
}
