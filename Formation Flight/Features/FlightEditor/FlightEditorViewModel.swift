import Foundation
import CoreLocation
import MapKit
import Combine

@MainActor
final class FlightEditorViewModel: ObservableObject {

    // MARK: - Published State
    @Published var useTOT: Bool = true
    @Published var timeEntry: Date = Date()
    @Published var missionName: String = ""
    @Published var selectedTargetLocation: CLLocationCoordinate2D? = nil
    @Published var currentLocation: CLLocationCoordinate2D? = nil
    @Published var hackDurationSeconds: Int = 0 // total seconds for Hack time
    
    // MARK: - Location
    /// The app-wide location source (B-16). The editor used to own a second
    /// `CLLocationManager` with no delegate, so it never learned the authorization outcome
    /// and could not show the user that location was denied or imprecise.
    let locationProvider: LocationProviding
    /// What the user has granted, as the editor last observed it (B-16). Refreshed by
    /// `requestLocationIfNeeded()` and `refreshLocationAccess()`.
    @Published private(set) var locationAccess: LocationAccess = .notDetermined

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

    public init(flight selectedFlight: Flight? = nil,
                locationProvider: LocationProviding = LocationProvider.shared) {
        self.flight = selectedFlight
        self.locationProvider = locationProvider

        if let selectedFlight {
            mapToValues(flight: selectedFlight)
        } else {
            baseline = currentSnapshot
        }
    }
    
    /// Asks for When-In-Use permission if the user has not been prompted yet, then takes
    /// whatever fix the shared provider already has so the map picker can open nearby.
    ///
    /// Only `.notDetermined` triggers a request: Core Location ignores repeat requests once
    /// a decision exists, and denied/restricted users are routed to Settings by the banner
    /// instead.
    func requestLocationIfNeeded() {
        if locationProvider.authorizationStatus == .notDetermined {
            locationProvider.requestWhenInUseAuthorization()
        }
        refreshLocationAccess()
        if let coord = locationProvider.currentLocation?.coordinate {
            currentLocation = coord
        }
    }

    /// Re-reads the provider's authorization into `locationAccess`.
    ///
    /// The view calls this when the scene becomes active again, because the user may have
    /// changed the permission in Settings and come straight back to the editor.
    func refreshLocationAccess() {
        let access = LocationAccess(authorizationStatus: locationProvider.authorizationStatus,
                                    accuracyAuthorization: locationProvider.accuracyAuthorization)
        if access != locationAccess {
            locationAccess = access
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

/// The editor's view of Core Location permission, collapsed to what the UI needs to show (B-16).
///
/// - `notDetermined`: the system prompt has not been answered; nothing to show yet.
/// - `authorized`: When-In-Use or Always with precise location; nothing to show.
/// - `reducedAccuracy`: granted, but Precise Location is off, so distance and timing are coarse.
/// - `denied`: `.denied` or `.restricted`; the app cannot obtain a fix at all.
enum LocationAccess: Equatable {
    case notDetermined
    case authorized
    case reducedAccuracy
    case denied

    /// Collapses Core Location's two-axis state into the single value the UI switches on.
    ///
    /// Accuracy only matters once location is granted; a denied user with reduced accuracy
    /// is still simply denied. An unknown future status is treated as undetermined so the
    /// banner never nags about a state it does not understand.
    init(authorizationStatus: CLAuthorizationStatus, accuracyAuthorization: CLAccuracyAuthorization) {
        switch authorizationStatus {
        case .notDetermined:
            self = .notDetermined
        case .denied, .restricted:
            self = .denied
        case .authorizedWhenInUse, .authorizedAlways:
            self = accuracyAuthorization == .reducedAccuracy ? .reducedAccuracy : .authorized
        @unknown default:
            self = .notDetermined
        }
    }
}

