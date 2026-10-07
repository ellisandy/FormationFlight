import Testing
import Foundation
import CoreLocation
@testable import Formation_Flight

@Suite("FlightEditorViewModelTests")
@MainActor
final class FlightEditorViewModelTests {

    @Test
    func testDefaultInitializationValues() {
        let vm = FlightEditorViewModel()
        #expect(vm.useTOT == true)
        #expect(vm.missionName == "")
        #expect(vm.selectedTargetLocation == nil)
        #expect(vm.currentLocation == nil)
        #expect(vm.hackDurationSeconds == 0)
        #expect(vm.isFlightViewPresented == false)
    }

    @Test
    func testTimeComponentGettersAndSetters() {
        let vm = FlightEditorViewModel()
        // Set timeEntry to a known date
        let baseDate = Calendar.current.date(from:
            DateComponents(year: 2025, month: 11, day: 19, hour: 10, minute: 20, second: 30))!
        vm.timeEntry = baseDate

        #expect(vm.hourComponent == 10)
        #expect(vm.minuteComponent == 20)
        #expect(vm.secondComponent == 30)

        vm.hourComponent = 15
        #expect(Calendar.current.component(.hour, from: vm.timeEntry) == 15)

        vm.minuteComponent = 45
        #expect(Calendar.current.component(.minute, from: vm.timeEntry) == 45)

        vm.secondComponent = 59
        #expect(Calendar.current.component(.second, from: vm.timeEntry) == 59)
    }

    /// B-04 regression coverage: the editor's hour setter must accept midnight (0) and
    /// clamp an out-of-range 24 to 23 on the same day, matching the picker's 0...23 wheel.
    @Test
    func testHourComponentAcceptsMidnightAndClampsTwentyFour() throws {
        let vm = FlightEditorViewModel()
        let calendar = Calendar.current
        vm.timeEntry = try #require(calendar.date(from:
            DateComponents(year: 2025, month: 6, day: 15, hour: 12, minute: 20, second: 30)))

        vm.hourComponent = 0
        #expect(vm.hourComponent == 0)
        #expect(calendar.component(.hour, from: vm.timeEntry) == 0)
        #expect(calendar.component(.day, from: vm.timeEntry) == 15)

        vm.hourComponent = 23
        #expect(vm.hourComponent == 23)
        #expect(calendar.component(.day, from: vm.timeEntry) == 15)

        vm.hourComponent = 24
        #expect(vm.hourComponent == 23)
        #expect(calendar.component(.day, from: vm.timeEntry) == 15)
    }

    @Test
    func testApplyTargetSelectionSetsSelectedTargetLocation() {
        let vm = FlightEditorViewModel()
        #expect(vm.selectedTargetLocation == nil)
        let coordinate = CLLocationCoordinate2D(latitude: 55.5, longitude: -12.3)
        vm.applyTargetSelection(coordinate: coordinate)
        let selected = try! #require(vm.selectedTargetLocation)
        #expect(selected.latitude == 55.5)
        #expect(selected.longitude == -12.3)
    }

    @Test
    func testPresentAndDismissFlightViewToggleIsFlightViewPresented() {
        let vm = FlightEditorViewModel()
        vm.missionName = "Valid Mission"
        vm.applyTargetSelection(coordinate: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0))
        #expect(vm.isFlightViewPresented == false)

        vm.presentFlightView()
        #expect(vm.isFlightViewPresented == true)

        vm.dismissFlightView()
        #expect(vm.isFlightViewPresented == false)
    }

    // MARK: - Go Fly validation (B-02)

    @Test
    func testPresentFlightViewWithDefaultState_DoesNotPresentAndSetsValidationMessage() {
        let vm = FlightEditorViewModel()
        #expect(vm.canGoFly == false)
        #expect(vm.goFlyValidationMessage != nil)

        vm.presentFlightView()

        #expect(vm.isFlightViewPresented == false)
        #expect(vm.validationMessage != nil)
    }

    @Test
    func testPresentFlightViewWithNameButNoTarget_DoesNotPresentAndMentionsTarget() throws {
        let vm = FlightEditorViewModel()
        vm.missionName = "Named Mission"
        #expect(vm.canGoFly == false)

        vm.presentFlightView()

        #expect(vm.isFlightViewPresented == false)
        let message = try #require(vm.validationMessage)
        #expect(message.localizedCaseInsensitiveContains("target"))
    }

    @Test
    func testPresentFlightViewWithTargetButEmptyName_DoesNotPresent() throws {
        let vm = FlightEditorViewModel()
        vm.applyTargetSelection(coordinate: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0))
        #expect(vm.canGoFly == false)

        vm.presentFlightView()

        #expect(vm.isFlightViewPresented == false)
        let message = try #require(vm.validationMessage)
        #expect(message.localizedCaseInsensitiveContains("name"))
    }

    @Test
    func testPresentFlightViewWithWhitespaceOnlyName_DoesNotPresent() {
        let vm = FlightEditorViewModel()
        vm.missionName = "   "
        vm.applyTargetSelection(coordinate: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0))
        #expect(vm.canGoFly == false)

        vm.presentFlightView()

        #expect(vm.isFlightViewPresented == false)
        #expect(vm.validationMessage != nil)
    }

    @Test
    func testPresentFlightViewHackMissionWithZeroHackDuration_DoesNotPresent() throws {
        let vm = FlightEditorViewModel()
        vm.missionName = "Hack Mission"
        vm.applyTargetSelection(coordinate: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0))
        vm.useTOT = false
        vm.hackDurationSeconds = 0
        #expect(vm.canGoFly == false)

        vm.presentFlightView()

        #expect(vm.isFlightViewPresented == false)
        let message = try #require(vm.validationMessage)
        #expect(message.localizedCaseInsensitiveContains("hack"))
    }

    @Test
    func testPresentFlightViewValidTOTMission_PresentsAndClearsValidationMessage() {
        let vm = FlightEditorViewModel()
        vm.missionName = "TOT Mission"
        vm.applyTargetSelection(coordinate: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0))
        vm.useTOT = true
        // A TOT mission with a zero hack duration is still valid; timeEntry is always set.
        vm.hackDurationSeconds = 0
        #expect(vm.canGoFly == true)
        #expect(vm.goFlyValidationMessage == nil)

        vm.presentFlightView()

        #expect(vm.isFlightViewPresented == true)
        #expect(vm.validationMessage == nil)
    }

    @Test
    func testPresentFlightViewValidHackMission_Presents() {
        let vm = FlightEditorViewModel()
        vm.missionName = "Hack Mission"
        vm.applyTargetSelection(coordinate: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0))
        vm.useTOT = false
        vm.hackDurationSeconds = 90
        #expect(vm.canGoFly == true)

        vm.presentFlightView()

        #expect(vm.isFlightViewPresented == true)
        #expect(vm.validationMessage == nil)
    }

    @Test
    func testCanGoFlyTracksStateChanges() {
        let vm = FlightEditorViewModel()
        #expect(vm.canGoFly == false)

        vm.missionName = "Mission"
        #expect(vm.canGoFly == false)

        vm.applyTargetSelection(coordinate: CLLocationCoordinate2D(latitude: 1.0, longitude: 2.0))
        #expect(vm.canGoFly == true)

        vm.useTOT = false
        #expect(vm.canGoFly == false)

        vm.hackDurationSeconds = 30
        #expect(vm.canGoFly == true)

        vm.applyTargetSelection(coordinate: nil)
        #expect(vm.canGoFly == false)
    }

    @Test
    func testValidationFailureDoesNotPresentButLaterValidAttemptDoes() {
        let vm = FlightEditorViewModel()
        vm.presentFlightView()
        #expect(vm.isFlightViewPresented == false)
        #expect(vm.validationMessage != nil)

        vm.missionName = "Mission"
        vm.applyTargetSelection(coordinate: CLLocationCoordinate2D(latitude: 1.0, longitude: 2.0))
        vm.presentFlightView()

        #expect(vm.isFlightViewPresented == true)
        #expect(vm.validationMessage == nil)
    }

    @Test
    func testMapToValuesWithTOTFlight_MapsAllFields() async {
        let target = Target(longitude: 20.0, latitude: 10.0)
        let missionDate = Calendar.current.date(from: DateComponents(year: 2025, month: 11, day: 19, hour: 1, minute: 2, second: 3))!
        let flight = Flight(missionName: "Mission X", missionType: .tot, missionDate: missionDate, target: target, hackTime: 3661)

        let vm = FlightEditorViewModel()
        vm.mapToValues(flight: flight)

        #expect(vm.useTOT == true)
        #expect(vm.missionName == "Mission X")
        let selected = try! #require(vm.selectedTargetLocation)
        #expect(selected.latitude == target.latitude)
        #expect(selected.longitude == target.longitude)
        #expect(vm.hackDurationSeconds == 3661)
        // Verify timeEntry matches missionDate components
        let cal = Calendar.current
        #expect(cal.component(.year, from: vm.timeEntry) == 2025)
        #expect(cal.component(.month, from: vm.timeEntry) == 11)
        #expect(cal.component(.day, from: vm.timeEntry) == 19)
        #expect(vm.hourComponent == 1)
        #expect(vm.minuteComponent == 2)
        #expect(vm.secondComponent == 3)
    }

    @Test
    func testMapToValuesWithHackTimeFlight_SetsUseTOTFalse() async {
        let target = Target(longitude: -122.0, latitude: 37.0)
        let flight = Flight(missionName: "Hack Mission", missionType: .hackTime, missionDate: nil, target: target, hackTime: 5400)

        let vm = FlightEditorViewModel()
        // Prime with different values to ensure mapping overwrites appropriately
        vm.useTOT = true
        vm.missionName = "Old"
        vm.hackDurationSeconds = 0
        vm.timeEntry = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: 0, minute: 0, second: 0))!

        vm.mapToValues(flight: flight)

        #expect(vm.useTOT == false)
        #expect(vm.missionName == "Hack Mission")
        let selected = try! #require(vm.selectedTargetLocation)
        #expect(selected.latitude == target.latitude)
        #expect(selected.longitude == target.longitude)
        #expect(vm.hackDurationSeconds == 5400)
    }

    @Test
    func testMapToValuesWithNilTarget_SetsSelectedTargetLocationNil() async {
        let missionDate = Calendar.current.date(from: DateComponents(year: 2024, month: 6, day: 1, hour: 8, minute: 0, second: 0))!
        // Create a flight with a temporary target, then set target to nil before mapping
        let tempTarget = Target(longitude: 0, latitude: 0)
        let flight = Flight(missionName: "No Target", missionType: .tot, missionDate: missionDate, target: tempTarget, hackTime: nil)
        flight.target = nil

        let vm = FlightEditorViewModel()
        vm.mapToValues(flight: flight)

        #expect(vm.selectedTargetLocation == nil)
    }

    @Test
    func testMapToValuesWithNilHackTime_DoesNotChangeHackDurationSeconds() async {
        let target = Target(longitude: 50.0, latitude: 40.0)
        let missionDate = Calendar.current.date(from: DateComponents(year: 2023, month: 12, day: 25, hour: 9, minute: 30, second: 45))!
        let flight = Flight(missionName: "Nil Hack", missionType: .tot, missionDate: missionDate, target: target, hackTime: nil)

        let vm = FlightEditorViewModel()
        vm.hackDurationSeconds = 123
        vm.mapToValues(flight: flight)

        #expect(vm.hackDurationSeconds == 123)
    }

    // MARK: - Hack time guarding (B-34)
    //
    // Chosen behaviour: a non-finite stored `hackTime` (`nan`, `±infinity`) is treated as
    // absent, so `hackDurationSeconds` is left unchanged (the default 0 then fails Go Fly
    // validation with "Please enter a hack time" rather than flying a bogus duration).
    // Finite values are clamped to 0...86_400 seconds (24 hours).

    @Test
    func testMapToValuesWithInfiniteHackTime_DoesNotTrapAndLeavesDurationUnchanged() async {
        let flight = Flight(missionName: "Inf", missionType: .hackTime, missionDate: nil,
                            target: Target(longitude: 0, latitude: 0), hackTime: .infinity)

        let vm = FlightEditorViewModel()
        vm.hackDurationSeconds = 42
        vm.mapToValues(flight: flight)

        #expect(vm.hackDurationSeconds == 42)
    }

    @Test
    func testMapToValuesWithNaNHackTime_DoesNotTrapAndLeavesDurationUnchanged() async {
        let flight = Flight(missionName: "NaN", missionType: .hackTime, missionDate: nil,
                            target: Target(longitude: 0, latitude: 0), hackTime: .nan)

        let vm = FlightEditorViewModel()
        vm.hackDurationSeconds = 42
        vm.mapToValues(flight: flight)

        #expect(vm.hackDurationSeconds == 42)
    }

    @Test
    func testMapToValuesWithHugeHackTime_ClampsToOneDay() async {
        let flight = Flight(missionName: "Huge", missionType: .hackTime, missionDate: nil,
                            target: Target(longitude: 0, latitude: 0), hackTime: 1e12)

        let vm = FlightEditorViewModel()
        vm.mapToValues(flight: flight)

        #expect(vm.hackDurationSeconds == 86_400)
    }

    @Test
    func testMapToValuesWithNegativeHackTime_ClampsToZero() async {
        let flight = Flight(missionName: "Negative", missionType: .hackTime, missionDate: nil,
                            target: Target(longitude: 0, latitude: 0), hackTime: -30)

        let vm = FlightEditorViewModel()
        vm.hackDurationSeconds = 42
        vm.mapToValues(flight: flight)

        #expect(vm.hackDurationSeconds == 0)
    }

    @Test
    func testMapToValuesWithNilMissionDate_DoesNotChangeTimeEntry() async {
        let target = Target(longitude: 10.0, latitude: 20.0)
        let flight = Flight(missionName: "Nil Date", missionType: .tot, missionDate: nil, target: target, hackTime: 10)

        let vm = FlightEditorViewModel()
        let original = Calendar.current.date(from: DateComponents(year: 2022, month: 1, day: 2, hour: 3, minute: 4, second: 5))!
        vm.timeEntry = original

        vm.mapToValues(flight: flight)

        #expect(vm.timeEntry == original)
        #expect(vm.hourComponent == 3)
        #expect(vm.minuteComponent == 4)
        #expect(vm.secondComponent == 5)
    }
}
