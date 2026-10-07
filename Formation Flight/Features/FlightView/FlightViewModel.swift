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
    @Published var statusColor: Status = .unknown
    
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
    /// Source of the current wall-clock time. Defaults to `Date()`; tests inject a
    /// fixed clock so ETA/delta arithmetic is exact and status boundaries can be
    /// asserted without tolerances (B-29).
    private let now: () -> Date
    /// Marked `nonisolated(unsafe)` solely so `deinit` (which is nonisolated under
    /// Swift 6) can cancel a still-live timer as a safety net. All other access is
    /// from MainActor-isolated methods, and the view's `.onDisappear` -> `stop()`
    /// is the primary teardown path.
    nonisolated(unsafe) private var timerToken: AnyCancellableLike?

    // MARK: - Initialization
    init(flight: Flight,
         settings: Settings,
         locationProvider: LocationProviding = LocationProvider.shared,
         timerScheduler: TimerScheduling = DefaultTimerScheduler(),
         now: @escaping () -> Date = { Date() }) {
        self.settings = settings
        self.locationProvider = locationProvider
        self.timerScheduler = timerScheduler
        self.now = now

        // Derived Data
        self.missionName = flight.missionName
        self.target = CLLocationCoordinate2D(latitude: flight.target?.latitude ?? 0.0, longitude: flight.target?.longitude ?? 0.0)
        self.missionType = flight.missionType
        
        if let missionDate = flight.missionDate {
            self.tot = missionDate
        }
    }
    
    init(missionName: String = "",
         target: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0),
         missionType: MissionType = .tot,
         missionDate: Date? = nil,
         hackTime: TimeInterval? = nil,
         settings: Settings = Settings.empty(),
         locationProvider: LocationProviding = LocationProvider.shared,
         timerScheduler: TimerScheduling = DefaultTimerScheduler(),
         now: @escaping () -> Date = { Date() }) {
        self.settings = settings
        self.locationProvider = locationProvider
        self.timerScheduler = timerScheduler
        self.now = now

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
    }

    /// Safety net only: if a started VM is released without `stop()`, make sure the
    /// repeating timer does not outlive it. `deinit` is nonisolated under Swift 6, so
    /// it must not touch `locationProvider` (MainActor state); clearing the delegate
    /// and stopping GPS is the job of `stop()`, called from `FlightView.onDisappear`.
    deinit {
        timerToken?.cancel()
    }

    // MARK: - Lifecycle
    /// Begins live updates: wires the location delegate, starts GPS monitoring, and
    /// schedules the 1 Hz timing refresh. Idempotent; a second call is a no-op.
    func start() {
        guard timerToken == nil else { return }
        locationProvider.updateDelegate = { [weak self] in
            self?.onLocationUpdate()
        }
        locationProvider.startMonitoring()
        currentTime = now()
        timerToken = timerScheduler.scheduleRepeating(interval: 1.0) { [weak self] in
            self?.updateTimings()
        }
    }

    /// Ends live updates: cancels the timer, detaches from the location provider,
    /// and stops GPS monitoring. Safe to call when not started.
    func stop() {
        guard timerToken != nil else { return }
        timerToken?.cancel()
        timerToken = nil
        locationProvider.updateDelegate = nil
        locationProvider.stopMonitoring()
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
    
    // MARK: - Update Pipelines
    private func updateTimings() {
        self.currentTime = now()

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
            let reference = self.currentTime ?? now()
            self.eta = reference.addingTimeInterval(ete)
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
        
        // Map absolute delta (seconds) to status using settings tolerances: <= yellow = good, <= red = bad, > red = reallyBad.
        // With no delta (no fix, no speed, or no ToT) there is nothing to judge, so fall back to .unknown
        // rather than leaving a stale colour on screen.
        if let _delta = delta {
            let absDelta = abs(_delta)

            if absDelta <= Double(settings.yellowTolerance) {
                statusColor = .good
            } else if absDelta <= Double(settings.redTolerance) {
                statusColor = .bad
            } else {
                statusColor = .reallyBad
            }
        } else {
            statusColor = .unknown
        }
    }
    
    private func updateInstruments() {
        guard let _currentLocation = locationProvider.currentLocation else {
            AppLogger.viewModel.debug("No current location available in updateInstruments")
            return
        }
        
        // Set Current Ground Speed
        if locationProvider.speed.value > 0 {
            currentGroundSpeed = locationProvider.speed
        } else {
            currentGroundSpeed = nil
        }
        
        // Set Distance to Final
        self.distance = _currentLocation.distance(from: CLLocation(latitude: target.latitude, longitude: target.longitude))
        
        // Set Bearing to Final
        AppLogger.viewModel.debug("Calculating bearing from current location to target")
        self.bearing = _currentLocation.getBearing(to: CLLocation(latitude: target.latitude, longitude: target.longitude))
        
        // Set Historical Track
        self.track = locationProvider.course
        
        // If track is within tolerance of bearing, calculate the required ground speed.
        if let _track = self.track, let _bearing = self.bearing, let _tot = self.tot {
            
            if let _distance = self.distance {
                if let rgs = computeRequiredGroundSpeed(distance: _distance, arrivalTime: _tot, now: now()) {
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

