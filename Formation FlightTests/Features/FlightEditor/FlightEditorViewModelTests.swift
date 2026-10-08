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

    // MARK: - Shared validation rules (B-14)
    //
    // Go Fly and Save must agree: the editor's message for a failure is the same string
    // `Flight.validFlight()` produces for a model in the same state, so one wording exists
    // per rule and the string catalog carries each only once.

    @Test
    func testGoFlyMessageMatchesValidFlightForZeroHack() throws {
        let vm = FlightEditorViewModel()
        vm.missionName = "Hack Mission"
        vm.applyTargetSelection(coordinate: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0))
        vm.useTOT = false
        vm.hackDurationSeconds = 0

        let flight = Flight(missionName: "Hack Mission", missionType: .hackTime, missionDate: nil,
                            target: Target(longitude: -122.0, latitude: 37.0), hackTime: 0)

        let editorMessage = try #require(vm.goFlyValidationMessage)
        let modelMessage = try #require(flight.validFlight().message)
        #expect(editorMessage == modelMessage)
    }

    @Test
    func testGoFlyMessageMatchesValidFlightForEmptyName() throws {
        let vm = FlightEditorViewModel()
        vm.missionName = ""
        vm.applyTargetSelection(coordinate: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0))

        let flight = Flight(missionName: "", missionType: .tot, missionDate: Date().addingTimeInterval(600),
                            target: Target(longitude: -122.0, latitude: 37.0), hackTime: nil)

        let editorMessage = try #require(vm.goFlyValidationMessage)
        let modelMessage = try #require(flight.validFlight().message)
        #expect(editorMessage == modelMessage)
    }

    @Test
    func testGoFlyMessageMatchesValidFlightForMissingTarget() throws {
        let vm = FlightEditorViewModel()
        vm.missionName = "Mission"

        let flight = Flight(missionName: "Mission", missionType: .tot, missionDate: Date().addingTimeInterval(600),
                            target: Target(longitude: 0, latitude: 0), hackTime: nil)
        flight.target = nil

        let editorMessage = try #require(vm.goFlyValidationMessage)
        let modelMessage = try #require(flight.validFlight().message)
        #expect(editorMessage == modelMessage)
    }

    @Test
    func testGoFlyMessageMatchesValidFlightForPastTOT() throws {
        let past = Date().addingTimeInterval(-3_600)
        let vm = FlightEditorViewModel()
        vm.missionName = "Late"
        vm.applyTargetSelection(coordinate: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0))
        vm.useTOT = true
        vm.timeEntry = past

        let flight = Flight(missionName: "Late", missionType: .tot, missionDate: past,
                            target: Target(longitude: -122.0, latitude: 37.0), hackTime: nil)

        #expect(vm.canGoFly == false)
        let editorMessage = try #require(vm.goFlyValidationMessage)
        let modelMessage = try #require(flight.validFlight().message)
        #expect(editorMessage == modelMessage)
        #expect(editorMessage.localizedCaseInsensitiveContains("past"))
    }

    @Test
    func testPresentFlightViewPastTOT_DoesNotPresent() throws {
        let vm = FlightEditorViewModel()
        vm.missionName = "Late"
        vm.applyTargetSelection(coordinate: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0))
        vm.timeEntry = Date().addingTimeInterval(-3_600)

        vm.presentFlightView()

        #expect(vm.isFlightViewPresented == false)
        #expect(vm.validationMessage != nil)
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

    // MARK: - Dirty tracking (B-21)
    //
    // Cancel asks "Discard changes?" only when something differs from the state the editor
    // opened with: the pristine new-flight defaults, or the loaded flight's values.

    @Test
    func testNewEditorIsNotDirty() {
        let vm = FlightEditorViewModel()
        #expect(vm.isDirty == false)
    }

    @Test
    func testTypingANameMakesTheEditorDirty() {
        let vm = FlightEditorViewModel()
        vm.missionName = "D"
        #expect(vm.isDirty == true)
        vm.missionName = ""
        #expect(vm.isDirty == false)
    }

    @Test
    func testChangingTimeTypeMakesTheEditorDirty() {
        let vm = FlightEditorViewModel()
        vm.useTOT = false
        #expect(vm.isDirty == true)
    }

    @Test
    func testChangingHackDurationMakesTheEditorDirty() {
        let vm = FlightEditorViewModel()
        vm.hackDurationSeconds = 30
        #expect(vm.isDirty == true)
    }

    @Test
    func testChangingTimeEntryMakesTheEditorDirty() {
        let vm = FlightEditorViewModel()
        vm.timeEntry = vm.timeEntry.addingTimeInterval(60)
        #expect(vm.isDirty == true)
    }

    @Test
    func testSelectingATargetMakesTheEditorDirty() {
        let vm = FlightEditorViewModel()
        vm.applyTargetSelection(coordinate: CLLocationCoordinate2D(latitude: 1, longitude: 2))
        #expect(vm.isDirty == true)
        vm.applyTargetSelection(coordinate: nil)
        #expect(vm.isDirty == false)
    }

    @Test
    func testEditorLoadedFromFlightIsNotDirtyUntilAFieldChanges() {
        let target = Target(longitude: -122.0, latitude: 37.0)
        let flight = Flight(missionName: "Loaded", missionType: .hackTime, missionDate: nil, target: target, hackTime: 300)

        let vm = FlightEditorViewModel(flight: flight)
        #expect(vm.isDirty == false)

        vm.hackDurationSeconds = 301
        #expect(vm.isDirty == true)
        vm.hackDurationSeconds = 300
        #expect(vm.isDirty == false)

        vm.applyTargetSelection(coordinate: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.5))
        #expect(vm.isDirty == true)
    }

    @Test
    func testMapToValuesResetsTheDirtyBaseline() {
        let vm = FlightEditorViewModel()
        vm.missionName = "Typed"
        #expect(vm.isDirty == true)

        let flight = Flight(missionName: "Mapped", missionType: .tot,
                            missionDate: Date().addingTimeInterval(600),
                            target: Target(longitude: 0, latitude: 0), hackTime: nil)
        vm.mapToValues(flight: flight)

        #expect(vm.isDirty == false)
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

    // MARK: - Location access (B-16)
    //
    // The editor reads authorization and the current fix from the shared `LocationProviding`
    // instead of owning a second `CLLocationManager`, and collapses the Core Location status
    // pair into `LocationAccess` so the view can show a banner for denied / imprecise access.

    private func makeProvider(status: CLAuthorizationStatus,
                              accuracy: CLAccuracyAuthorization = .fullAccuracy,
                              location: CLLocation? = nil) -> MockLocationProvider {
        let provider = MockLocationProvider()
        provider.authorizationStatus = status
        provider.accuracyAuthorization = accuracy
        provider.currentLocation = location
        return provider
    }

    @Test
    func testRequestLocationWhenNotDetermined_AsksProviderOnceAndStaysNotDetermined() {
        let provider = makeProvider(status: .notDetermined)
        let vm = FlightEditorViewModel(locationProvider: provider)

        vm.requestLocationIfNeeded()

        #expect(provider.requestWhenInUseAuthorizationCallCount == 1)
        #expect(vm.locationAccess == .notDetermined)
        #expect(vm.currentLocation == nil)
    }

    @Test
    func testRequestLocationWhenAuthorizedWithPreciseFix_CopiesCoordinateWithoutAsking() throws {
        let fix = CLLocation(latitude: 51.5, longitude: -0.12)
        let provider = makeProvider(status: .authorizedWhenInUse, accuracy: .fullAccuracy, location: fix)
        let vm = FlightEditorViewModel(locationProvider: provider)

        vm.requestLocationIfNeeded()

        #expect(provider.requestWhenInUseAuthorizationCallCount == 0)
        #expect(vm.locationAccess == .authorized)
        let coordinate = try #require(vm.currentLocation)
        #expect(coordinate.latitude == 51.5)
        #expect(coordinate.longitude == -0.12)
    }

    @Test
    func testRequestLocationWhenDenied_ReportsDeniedWithoutAsking() {
        let provider = makeProvider(status: .denied)
        let vm = FlightEditorViewModel(locationProvider: provider)

        vm.requestLocationIfNeeded()

        #expect(provider.requestWhenInUseAuthorizationCallCount == 0)
        #expect(vm.locationAccess == .denied)
    }

    @Test
    func testRequestLocationWhenRestricted_ReportsDenied() {
        let provider = makeProvider(status: .restricted)
        let vm = FlightEditorViewModel(locationProvider: provider)

        vm.requestLocationIfNeeded()

        #expect(provider.requestWhenInUseAuthorizationCallCount == 0)
        #expect(vm.locationAccess == .denied)
    }

    @Test
    func testRequestLocationWhenAuthorizedButImprecise_ReportsReducedAccuracy() {
        let provider = makeProvider(status: .authorizedWhenInUse, accuracy: .reducedAccuracy)
        let vm = FlightEditorViewModel(locationProvider: provider)

        vm.requestLocationIfNeeded()

        #expect(provider.requestWhenInUseAuthorizationCallCount == 0)
        #expect(vm.locationAccess == .reducedAccuracy)
    }

    /// The user may flip the switch in Settings and come back; the view calls this when the
    /// scene becomes active again, so it must pick up the new status without a fresh request.
    @Test
    func testRefreshLocationAccessTracksProviderChanges() {
        let provider = makeProvider(status: .denied)
        let vm = FlightEditorViewModel(locationProvider: provider)
        vm.requestLocationIfNeeded()
        #expect(vm.locationAccess == .denied)

        provider.authorizationStatus = .authorizedWhenInUse
        vm.refreshLocationAccess()

        #expect(vm.locationAccess == .authorized)
        #expect(provider.requestWhenInUseAuthorizationCallCount == 0)
    }
}
