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
        isFlightViewPresented = true
    }
    
    func dismissFlightView() {
        isFlightViewPresented = false
    }
}

