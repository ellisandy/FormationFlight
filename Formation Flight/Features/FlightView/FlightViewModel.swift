//
//  FlightViewModel.swift
//  Formation Flight
//
//  Created by Jack Ellis on 11/13/25.
//

import Foundation
@preconcurrency import Combine
import CoreLocation

@MainActor
final class FlightViewModel: ObservableObject {
    // MARK: - Types
    enum Status: Equatable {
        case good
        case bad
        case reallyBad
        case unknown
    }
    
    // MARK: - Published State (Timing)
    @Published var currentTime: Date?
    @Published var ete: TimeInterval?
    @Published var eta: Date?
    @Published var delta: TimeInterval?
    @Published var tot: Date?
    @Published var statusColor: Status = .good
    
    // MARK: - Published State (Instruments)
    @Published var currentGroundSpeed: Measurement<UnitSpeed>?
    @Published var requiredGroundSpeed: Measurement<UnitSpeed>?
    @Published var distance: Measurement<UnitLength>?
    @Published var bearing: Measurement<UnitAngle>? // degrees
    @Published var track: Measurement<UnitAngle>?   // degrees
    
    // MARK: - Published State (Mission Details)
    @Published var missionName: String
    @Published var target: CLLocationCoordinate2D
    
    // MARK: - Dependencies / Model Objects
    var settings: Settings
    var locationProvider: LocationProviding
    var missionType: MissionType
    var missionDate: Date?
    var hackTime: TimeInterval?
    
    // MARK: - UI State
    @Published var isEditingToT: Bool = false
    @Published var isEditingHackTime: Bool = false
    
    // MARK: - Private
    private let timerScheduler: TimerScheduling
    private var timerToken: AnyCancellableLike?
    private let requiredSpeedTrackToleranceDegrees: Double = 15
    
    // MARK: - Initialization
    init(flight: Flight,
         settings: Settings,
         locationProvider: LocationProviding = LocationProvider.shared,
         timerScheduler: TimerScheduling = DefaultTimerScheduler()) {
        self.settings = settings
        self.locationProvider = locationProvider
        self.timerScheduler = timerScheduler
        
        // Derived Data
        self.missionName = flight.missionName
        self.target = CLLocationCoordinate2D(latitude: flight.target?.latitude ?? 0.0, longitude: flight.target?.longitude ?? 0.0)
        self.missionType = flight.missionType
        
        if let missionDate = flight.missionDate {
            self.tot = missionDate
        }
        
        configure()
    }
    
    init(missionName: String = "",
         target: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0),
         missionType: MissionType = .tot,
         missionDate: Date? = nil,
         hackTime: TimeInterval? = nil,
         settings: Settings = Settings.empty(),
         locationProvider: LocationProviding = LocationProvider.shared,
         timerScheduler: TimerScheduling = DefaultTimerScheduler()) {
        self.settings = settings
        self.locationProvider = locationProvider
        self.timerScheduler = timerScheduler
        
        self.missionName = missionName
        self.target = target
        self.missionType = missionType
        
        if self.missionType == .tot {
            if let missionDate {
                self.tot = missionDate
            }
        }
        
        if let hackTime {
            self.hackTime = hackTime
        }
        
        configure()
    }
    
    private func configure() {
        startTimer()
    }
    
    // MARK: - Public API (UI Intents)
    func presentEditHackTime() {
        isEditingHackTime = true
    }
    
    func cancelHackTimeEdit() {
        isEditingHackTime = false
    }
    
    func presentEditToT() {
        isEditingToT = true
    }
    
    func cancelEditToT() {
        isEditingToT = false
    }
    
    func startHack() {
        guard let _hackTime = hackTime, let now = currentTime else { return }
        tot = now.addingTimeInterval(_hackTime)
    }
    
    // MARK: - Location Updates
    func onLocationUpdate() {
        AppLogger.viewModel.debug("Location update received from LocationProvider")
        updateInstruments()
    }
    
    // MARK: - Timer
    private func startTimer() {
        locationProvider.startMonitoring()
        // Schedule 1-second updates using injected scheduler
        timerToken = timerScheduler.scheduleRepeating(interval: 1.0) { [weak self] in
            self?.updateTimings()
        }
    }
    
    // MARK: - Update Pipelines
    private func updateTimings() {
        self.currentTime = Date()

        // Set ETE
        if let gs = self.currentGroundSpeed?.converted(to: .metersPerSecond),
           let dist = self.distance?.converted(to: .meters),
           gs.value > 0 {
            self.ete = dist.value / gs.value // seconds
        } else {
            self.ete = nil
        }
        
        // Set ETA
        if let ete = self.ete {
            let now = self.currentTime ?? Date()
            self.eta = now.addingTimeInterval(ete)
        } else {
            self.eta = nil
        }
        
        // Set Delta
        if let eta = self.eta, let tot = self.tot {
            // Positive delta means ETA is after TOT (late). Negative means early.
            self.delta = eta.timeIntervalSince(tot)
        } else {
            self.delta = nil
        }
        
        // Map absolute delta (seconds) to status using settings tolerances: < yellow = good, < red = bad, >= red = reallyBad.
        if let _delta = delta {
            let absDelta = abs(_delta)
            
            if absDelta < Double(settings.yellowTolerance) {
                statusColor = .good
            } else if absDelta < Double(settings.redTolerance) {
                statusColor = .bad
            } else if absDelta >= Double(settings.redTolerance) {
                statusColor = .reallyBad
            } else {
                statusColor = .unknown
            }
        }
    }
    
    private func updateInstruments() {
        // Set Current Ground Speed
        if locationProvider.speed.value > 0 {
            currentGroundSpeed = locationProvider.speed
        } else {
            currentGroundSpeed = nil
        }
        
        // Set Distance to Final
        self.distance = locationProvider.currentLocation?.distance(from: CLLocation(latitude: target.latitude, longitude: target.longitude))
        
        // Set Bearing to Final
        self.bearing = locationProvider.currentLocation?.getBearing(to: CLLocation(latitude: target.latitude, longitude: target.longitude))
        
        // Set Historical Track
        self.track = locationProvider.course
        
        // If track is within tolerance of bearing, calculate the required ground speed.
        if let _track = self.track, let _bearing = self.bearing, let _tot = self.tot,
           isWithinDegrees(_track, _bearing, tolerance: requiredSpeedTrackToleranceDegrees) {
            
            if let _distance = self.distance {
                if let rgs = computeRequiredGroundSpeed(distance: _distance, arrivalTime: _tot, now: .now) {
                    // Convert to your preferred display unit (knots)
                    self.requiredGroundSpeed = rgs.converted(to: .knots)
                } else {
                    self.requiredGroundSpeed = nil
                }
            } else {
                // Missing inputs; you can choose to clear or keep the previous value
                self.requiredGroundSpeed = nil
            }
        } else {
            self.currentGroundSpeed = nil
            self.requiredGroundSpeed = nil
        }
    }
    
    // MARK: - Helpers
    private func isWithinDegrees(_ a: Measurement<UnitAngle>,
                                 _ b: Measurement<UnitAngle>,
                                 tolerance: Double) -> Bool {
        let aDeg = a.converted(to: .degrees).value
        let bDeg = b.converted(to: .degrees).value
        var diff = abs(aDeg - bDeg).truncatingRemainder(dividingBy: 360)
        if diff > 180 { diff = 360 - diff }
        return diff <= tolerance
    }
    
    private func computeRequiredGroundSpeed(distance: Measurement<UnitLength>,
                                            arrivalTime: Date,
                                            now: Date) -> Measurement<UnitSpeed>? {
        let timeRemaining = arrivalTime.timeIntervalSince(now) // seconds
        guard timeRemaining > 0 else {
            // Already at/after the arrival time; cannot compute a positive required speed
            return nil
        }
        // Convert distance to meters, then speed = meters / second
        let meters = distance.converted(to: .meters).value
        let mps = meters / timeRemaining
        guard mps.isFinite && mps > 0 else { return nil }
        return Measurement(value: mps, unit: UnitSpeed.metersPerSecond)
    }
}

// MARK: - Formatting Helpers
extension FlightViewModel {
    func formatSpeed(_ m: Measurement<UnitSpeed>?) -> String {
        MeasurementFormatters.speedString(m, unitPreference: settings.speedUnit)
    }
    
    func formatDistance(_ m: Measurement<UnitLength>?) -> String {
        MeasurementFormatters.distanceString(m, unitPreference: settings.distanceUnit)
    }
}

