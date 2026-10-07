import Foundation
import CoreLocation
import MapKit
import Combine

@MainActor
final class FlightEditorViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    // MARK: - Published State
    @Published var useTOT: Bool = true
    @Published var timeEntry: Date = Date()
    @Published var missionName: String = ""
    @Published var selectedTargetLocation: CLLocationCoordinate2D? = nil
    @Published var currentLocation: CLLocationCoordinate2D? = nil
    @Published var hackDurationSeconds: Int = 0 // total seconds for Hack time
    
    // MARK: - Location
    private let locationManager = CLLocationManager()
    
    // MARK: Flight
    var flight: Flight?
    var isEditing: Bool { flight != nil }
    
    // MARK: Dirty tracking (B-21)

    /// The editable fields, captured so Cancel can tell whether anything changed.
    ///
    /// `CLLocationCoordinate2D` is not `Equatable`, so the target is stored as two doubles.
    private struct Snapshot: Equatable {
        var useTOT: Bool
        var missionName: String
        var hackDurationSeconds: Int
        var timeEntry: Date
        var targetLatitude: Double?
        var targetLongitude: Double?
    }

    /// The state the editor opened with. Always overwritten at the end of `init` and
    /// `mapToValues`, so the initial value is irrelevant.
    private var baseline = Snapshot(useTOT: true, missionName: "", hackDurationSeconds: 0,
                                    timeEntry: .distantPast, targetLatitude: nil, targetLongitude: nil)

    private var currentSnapshot: Snapshot {
        Snapshot(useTOT: useTOT,
                 missionName: missionName,
                 hackDurationSeconds: hackDurationSeconds,
                 timeEntry: timeEntry,
                 targetLatitude: selectedTargetLocation?.latitude,
                 targetLongitude: selectedTargetLocation?.longitude)
    }

    /// `true` when any editable field differs from the flight as loaded, or from the pristine
    /// new-flight state. Cancel asks before discarding only when this is `true`.
    var isDirty: Bool { currentSnapshot != baseline }

    // MARK: Flight View
    @Published var isFlightViewPresented: Bool = false

    // MARK: Validation
    /// User-facing message set when `presentFlightView()` is refused because the mission is invalid.
    @Published var validationMessage: String?

    /// The mission type the segmented control currently selects.
    var missionType: MissionType { useTOT ? .tot : .hackTime }

    /// `missionDate` as it should be persisted: only a TOT mission carries one (B-14).
    var missionDateToSave: Date? { useTOT ? timeEntry : nil }

    /// `hackTime` as it should be persisted: only a hack mission carries one (B-14).
    var hackTimeToSave: TimeInterval? { useTOT ? nil : TimeInterval(hackDurationSeconds) }

    /// The first failing Go Fly rule as a user-facing message, or `nil` when the mission can be flown.
    ///
    /// Delegates to `FlightValidation`, the same rules `Flight.validFlight()` applies on save, so
    /// Go Fly and Save can never disagree about what is flyable.
    var goFlyValidationMessage: String? {
        FlightValidation.message(missionName: missionName,
                                 missionType: missionType,
                                 missionDate: missionDateToSave,
                                 hackTime: hackTimeToSave,
                                 hasTarget: selectedTargetLocation != nil)
    }

    /// `true` when all Go Fly validation rules pass.
    var canGoFly: Bool { goFlyValidationMessage == nil }

    // MARK: - Hack Duration Guarding (B-34)

    /// Upper bound for an editable hack duration: 24 hours in seconds.
    nonisolated static let maxHackDurationSeconds = 86_400

    /// Converts a hack time in seconds to a whole number of seconds safe for the editor.
    ///
    /// `Int(Double)` traps on non-finite input, so `nan` and `±infinity` return `nil`
    /// (treated as "no hack time"). Finite values are clamped to
    /// `0...maxHackDurationSeconds` before converting.
    nonisolated static func hackDurationSeconds(from value: Double) -> Int? {
        guard value.isFinite else { return nil }
        let clamped = min(max(value, 0), Double(maxHackDurationSeconds))
        return Int(clamped)
    }

    func mapToValues(flight: Flight) {
        if flight.missionType == .tot {
            useTOT = true
        } else {
            useTOT = false
        }
        missionName = flight.missionName
        if let targetCoord = flight.target?.getCLLocation().coordinate {
            selectedTargetLocation = targetCoord
        }
        
        if let hackDuration = flight.hackTime.flatMap(Self.hackDurationSeconds(from:)) {
            hackDurationSeconds = hackDuration
        }
        
        if let entryDate = flight.missionDate {
            timeEntry = entryDate
        }

        // The mapped flight is the new "unchanged" state.
        baseline = currentSnapshot
    }

    public init(flight selectedFlight: Flight? = nil) {
        self.flight = selectedFlight
        super.init()
        locationManager.delegate = self

        if let selectedFlight {
            mapToValues(flight: selectedFlight)
        } else {
            baseline = currentSnapshot
        }
    }
    
    func requestLocationIfNeeded() {
        locationManager.requestWhenInUseAuthorization()
        if let coord = locationManager.location?.coordinate {
            currentLocation = coord
        }
    }
    
    // MARK: - Time Helpers
    var hourComponent: Int {
        get { timeEntry.hour }
        set { timeEntry = timeEntry.updatingHour(to: newValue) }
    }
    
    var minuteComponent: Int {
        get { timeEntry.minute }
        set { timeEntry = timeEntry.updatingMinute(to: newValue) }
    }
    
    var secondComponent: Int {
        get { timeEntry.second }
        set { timeEntry = timeEntry.updatingSecond(to: newValue) }
    }
    
    // Note: updateTimeComponent no longer needed due to Date extension
    
    // MARK: - Checkpoint Helpers
    func applyTargetSelection(coordinate: CLLocationCoordinate2D?) {
        selectedTargetLocation = coordinate
    }
    
    func presentFlightView() {
        if let message = goFlyValidationMessage {
            validationMessage = message
            return
        }
        validationMessage = nil
        isFlightViewPresented = true
    }
    
    func dismissFlightView() {
        isFlightViewPresented = false
    }
}

