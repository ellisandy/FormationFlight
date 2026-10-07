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
    
    // MARK: Flight View
    @Published var isFlightViewPresented: Bool = false

    // MARK: Validation
    /// User-facing message set when `presentFlightView()` is refused because the mission is invalid.
    @Published var validationMessage: String?

    /// The first failing Go Fly rule as a user-facing message, or `nil` when the mission can be flown.
    var goFlyValidationMessage: String? {
        if missionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(localized: "Please enter a mission name.",
                          comment: "Validation message when a flight has no mission name")
        }
        if selectedTargetLocation == nil {
            return String(localized: "Please enter a valid target location.",
                          comment: "Validation message when a flight has no target selected")
        }
        if !useTOT && hackDurationSeconds <= 0 {
            return String(localized: "Please enter a hack time.",
                          comment: "Validation message when a hack-time mission has a zero hack duration")
        }
        return nil
    }

    /// `true` when all Go Fly validation rules pass.
    var canGoFly: Bool { goFlyValidationMessage == nil }

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
        
        if let hackDuration = flight.hackTime.map({ Int($0) }) {
            hackDurationSeconds = hackDuration
        }
        
        if let entryDate = flight.missionDate {
            timeEntry = entryDate
        }
    }
    
    public init(flight selectedFlight: Flight? = nil) {
        self.flight = selectedFlight
        super.init()
        locationManager.delegate = self
        
        if flight != nil {
            mapToValues(flight: flight!)
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

