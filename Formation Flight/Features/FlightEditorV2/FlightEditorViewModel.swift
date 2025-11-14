import Foundation
import CoreLocation
import MapKit
import Combine

final class FlightEditorViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    // MARK: - Published State
    @Published var useTOT: Bool = true
    @Published var timeEntry: Date = Date()
    @Published var flightTitle: String = ""
    @Published var windDirection: String = "" // degrees magnetic/true as needed
    @Published var windSpeed: String = "" // knots
    @Published var selectedCheckpoint: String = ""
    @Published var selectedCoordinateDescription: String? = nil
    @Published var selectedCoordinate: CLLocationCoordinate2D? = nil
    @Published var currentCoordinate: CLLocationCoordinate2D? = nil
    @Published var hackDurationSeconds: Int = 0 // total seconds for Hack time

    // MARK: - Data
    let checkpoints: [String] = [
        "Start", "CP1", "CP2", "IP", "Target"
    ]

    // MARK: - Location
    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func requestLocationIfNeeded() {
        locationManager.requestWhenInUseAuthorization()
        if let coord = locationManager.location?.coordinate {
            currentCoordinate = coord
        }
    }

    // MARK: - Time Helpers
    var hourComponent: Int {
        get { Calendar.current.component(.hour, from: timeEntry) }
        set { updateTimeComponent(.hour, value: max(0, min(23, newValue))) }
    }

    var minuteComponent: Int {
        get { Calendar.current.component(.minute, from: timeEntry) }
        set { updateTimeComponent(.minute, value: max(0, min(59, newValue))) }
    }

    var secondComponent: Int {
        get { Calendar.current.component(.second, from: timeEntry) }
        set { updateTimeComponent(.second, value: max(0, min(59, newValue))) }
    }

    private func updateTimeComponent(_ component: Calendar.Component, value: Int) {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: timeEntry)
        switch component {
        case .hour: comps.hour = value
        case .minute: comps.minute = value
        case .second: comps.second = value
        default: break
        }
        if let d = cal.date(from: comps) { timeEntry = d }
    }

    // MARK: - Checkpoint Helpers
    func applyCheckpointSelection(name: String?, coordinate: CLLocationCoordinate2D?) {
        selectedCoordinateDescription = name
        selectedCheckpoint = name ?? ""
        selectedCoordinate = coordinate
    }
}

extension FlightEditorViewModel {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Update current coordinate when permission changes
        if let coord = manager.location?.coordinate {
            currentCoordinate = coord
        }
    }
}
