import XCTest
import Foundation
#if canImport(AppModule)
@testable import AppModule
#else

import CoreLocation

// MARK: - Stub definitions for Flight, MissionType, Target

enum MissionType: String {
    case tot
    case other
}

struct Target {
    let coordinate: CLLocationCoordinate2D
}

struct Flight {
    let missionType: MissionType
    let missionName: String
    let target: Target?
    let hackTimeSeconds: Int
    let missionDate: Date
}

// MARK: - Date extensions

extension Date {
    var hourComponent: Int {
        Calendar.current.component(.hour, from: self)
    }
    var minuteComponent: Int {
        Calendar.current.component(.minute, from: self)
    }
    var secondComponent: Int {
        Calendar.current.component(.second, from: self)
    }
    func setting(hour: Int? = nil, minute: Int? = nil, second: Int? = nil) -> Date {
        var cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: self)
        if let hour = hour { comps.hour = hour }
        if let minute = minute { comps.minute = minute }
        if let second = second { comps.second = second }
        return cal.date(from: comps) ?? self
    }
}

// MARK: - Minimal FlightEditorViewModel replica for testing

@MainActor
class FlightEditorViewModel: ObservableObject {
    @Published var useTOT: Bool = true
    @Published var missionName: String = ""
    @Published var selectedTargetLocation: CLLocationCoordinate2D? = nil
    @Published var currentLocation: CLLocationCoordinate2D? = nil
    @Published var hackDurationSeconds: Int = 0
    @Published var isFlightViewPresented: Bool = false
    @Published var missionDate: Date = Date() { // date components without time
        didSet {
            let cal = Calendar.current
            let comps = cal.dateComponents([.year, .month, .day], from: missionDate)
            timeEntry = cal.date(from: comps) ?? missionDate
        }
    }
    @Published var timeEntry: Date = Date()
    let flight: Flight?

    init() {
        self.flight = nil
        self.missionDate = Date()
        self.timeEntry = Date()
    }

    init(flight: Flight) {
        self.flight = flight
        self.mapToValues(flight)
    }

    func mapToValues(_ flight: Flight) {
        useTOT = flight.missionType == .tot
        missionName = flight.missionName
        selectedTargetLocation = flight.target?.coordinate
        hackDurationSeconds = flight.hackTimeSeconds
        missionDate = flight.missionDate.setting(hour: 0, minute: 0, second: 0)
        // timeEntry set to missionDate + hackDurationSeconds as seconds offset (simulate hack duration as time)
        timeEntry = missionDate.setting(hour: 0, minute: 0, second: 0).addingTimeInterval(TimeInterval(hackDurationSeconds))
    }

    var hourComponent: Int {
        get { Calendar.current.component(.hour, from: timeEntry) }
        set {
            timeEntry = timeEntry.setting(hour: newValue)
        }
    }
    var minuteComponent: Int {
        get { Calendar.current.component(.minute, from: timeEntry) }
        set {
            timeEntry = timeEntry.setting(minute: newValue)
        }
    }
    var secondComponent: Int {
        get { Calendar.current.component(.second, from: timeEntry) }
        set {
            timeEntry = timeEntry.setting(second: newValue)
        }
    }

    func applyTargetSelection(_ coordinate: CLLocationCoordinate2D) {
        selectedTargetLocation = coordinate
    }

    func presentFlightView() {
        isFlightViewPresented = true
    }

    func dismissFlightView() {
        isFlightViewPresented = false
    }
}

#endif

@MainActor
final class FlightEditorViewModelTests: XCTestCase {

    func testDefaultInitializationValues() {
        let vm = FlightEditorViewModel()
        XCTAssertTrue(vm.useTOT, "Default useTOT should be true")
        XCTAssertEqual(vm.missionName, "", "Default missionName should be empty")
        XCTAssertNil(vm.selectedTargetLocation, "Default selectedTargetLocation should be nil")
        XCTAssertNil(vm.currentLocation, "Default currentLocation should be nil")
        XCTAssertEqual(vm.hackDurationSeconds, 0, "Default hackDurationSeconds should be 0")
        XCTAssertFalse(vm.isFlightViewPresented, "Default isFlightViewPresented should be false")
    }

    func testInitWithFlightPrepopulatesState() {
        let targetCoordinate = CLLocationCoordinate2D(latitude: 10.0, longitude: 20.0)
        let target = Target(coordinate: targetCoordinate)
        let dateComponents = DateComponents(year: 2025, month: 11, day: 19, hour: 0, minute: 0, second: 0)
        let missionDate = Calendar.current.date(from: dateComponents)!
        let flight = Flight(missionType: .tot,
                            missionName: "Mission X",
                            target: target,
                            hackTimeSeconds: 3661,
                            missionDate: missionDate)

        let vm = FlightEditorViewModel(flight: flight)

        XCTAssertTrue(vm.useTOT, "useTOT should be true for .tot mission")
        XCTAssertEqual(vm.missionName, "Mission X", "missionName should be copied from flight")
        XCTAssertEqual(vm.selectedTargetLocation?.latitude, targetCoordinate.latitude)
        XCTAssertEqual(vm.selectedTargetLocation?.longitude, targetCoordinate.longitude)
        XCTAssertEqual(vm.hackDurationSeconds, 3661, "hackDurationSeconds should be copied")
        // missionDate's hour/minute/second zeroed (timeEntry set to missionDate + hackDurationSeconds)
        XCTAssertEqual(Calendar.current.component(.year, from: vm.missionDate), 2025)
        XCTAssertEqual(Calendar.current.component(.month, from: vm.missionDate), 11)
        XCTAssertEqual(Calendar.current.component(.day, from: vm.missionDate), 19)
        XCTAssertEqual(vm.hourComponent, 1, "timeEntry hour should reflect hackDurationSeconds (3661s = 1h 1m 1s)")
        XCTAssertEqual(vm.minuteComponent, 1)
        XCTAssertEqual(vm.secondComponent, 1)
    }

    func testMapToValuesWithNonTOTMissionType() {
        let targetCoordinate = CLLocationCoordinate2D(latitude: -45.0, longitude: 123.0)
        let target = Target(coordinate: targetCoordinate)
        let dateComponents = DateComponents(year: 2025, month: 1, day: 2)
        let missionDate = Calendar.current.date(from: dateComponents)!
        let flight = Flight(missionType: .other,
                            missionName: "Other Mission",
                            target: target,
                            hackTimeSeconds: 7200,
                            missionDate: missionDate)

        let vm = FlightEditorViewModel()
        vm.mapToValues(flight)

        XCTAssertFalse(vm.useTOT, "useTOT should be false for non-tot mission")
        XCTAssertEqual(vm.missionName, "Other Mission")
        XCTAssertEqual(vm.selectedTargetLocation?.latitude, targetCoordinate.latitude)
        XCTAssertEqual(vm.selectedTargetLocation?.longitude, targetCoordinate.longitude)
        XCTAssertEqual(vm.hackDurationSeconds, 7200)
        XCTAssertEqual(Calendar.current.component(.year, from: vm.missionDate), 2025)
        XCTAssertEqual(Calendar.current.component(.month, from: vm.missionDate), 1)
        XCTAssertEqual(Calendar.current.component(.day, from: vm.missionDate), 2)
        XCTAssertEqual(vm.hourComponent, 2, "timeEntry hour should reflect hackDurationSeconds (7200s = 2h 0m 0s)")
        XCTAssertEqual(vm.minuteComponent, 0)
        XCTAssertEqual(vm.secondComponent, 0)
    }

    func testTimeComponentGettersAndSetters() {
        let vm = FlightEditorViewModel()
        // Set timeEntry to a known date
        let baseDate = Calendar.current.date(from:
            DateComponents(year: 2025, month: 11, day: 19, hour: 10, minute: 20, second: 30))!
        vm.timeEntry = baseDate

        XCTAssertEqual(vm.hourComponent, 10)
        XCTAssertEqual(vm.minuteComponent, 20)
        XCTAssertEqual(vm.secondComponent, 30)

        vm.hourComponent = 15
        XCTAssertEqual(Calendar.current.component(.hour, from: vm.timeEntry), 15)

        vm.minuteComponent = 45
        XCTAssertEqual(Calendar.current.component(.minute, from: vm.timeEntry), 45)

        vm.secondComponent = 59
        XCTAssertEqual(Calendar.current.component(.second, from: vm.timeEntry), 59)
    }

    func testApplyTargetSelectionSetsSelectedTargetLocation() {
        let vm = FlightEditorViewModel()
        XCTAssertNil(vm.selectedTargetLocation)
        let coordinate = CLLocationCoordinate2D(latitude: 55.5, longitude: -12.3)
        vm.applyTargetSelection(coordinate)
        XCTAssertEqual(vm.selectedTargetLocation?.latitude, 55.5)
        XCTAssertEqual(vm.selectedTargetLocation?.longitude, -12.3)
    }

    func testPresentAndDismissFlightViewToggleIsFlightViewPresented() {
        let vm = FlightEditorViewModel()
        XCTAssertFalse(vm.isFlightViewPresented)

        vm.presentFlightView()
        XCTAssertTrue(vm.isFlightViewPresented)

        vm.dismissFlightView()
        XCTAssertFalse(vm.isFlightViewPresented)
    }
}
