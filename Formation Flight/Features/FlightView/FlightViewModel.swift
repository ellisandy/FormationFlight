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
        self.missionDate = flight.missionDate
        self.hackTime = flight.hackTime

        // B-23: only a ToT mission starts with a ToT. A hack mission's ToT is set by
        // startHack(); the editor may still have written a missionDate (B-14), and that
        // must not show up as a ToT before Hack! is pressed.
        if self.missionType == .tot {
            self.tot = flight.missionDate
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
        self.missionDate = missionDate
        self.hackTime = hackTime

        if self.missionType == .tot {
            self.tot = missionDate
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
    
    /// Anchors the ToT to the moment "Hack!" is pressed. Reads the clock directly rather than
    /// the timer-sampled `currentTime` (B-09): that sample is nil before the first tick and up
    /// to a second stale afterwards, in an app whose tolerances are whole seconds. The press
    /// is truncated to the second so the ToT sits on the same whole-second basis as the
    /// Time / ETE / ETA readouts (B-40).
    func startHack() {
        guard let _hackTime = hackTime else { return }
        let pressed = Self.floorToSecond(now())
        tot = pressed.addingTimeInterval(_hackTime)
    }
    
    // MARK: - Location Updates
    func onLocationUpdate() {
        AppLogger.viewModel.debug("Location update received from LocationProvider")
        updateInstruments()
    }
    
    // MARK: - Update Pipelines
    /// Whole-second policy (B-40): Time, ETE and ETA are each shown truncated to the second
    /// (`Formatting.timeHHmmss` / `durationHMS` both drop fractions). If the clock and ETE were
    /// kept fractional and truncated independently at display time, the Time and ETE readouts
    /// could add up to one second less than the ETA readout. So the pipeline truncates (never
    /// rounds) at the source: the clock is floored to the second, ETE is floored to the second,
    /// and ETA is derived from those two floored values. Delta then inherits the same basis.
    private func updateTimings() {
        let wallClock = now()
        let flooredClock = Self.floorToSecond(wallClock)
        self.currentTime = flooredClock

        // Set ETE, truncated to a whole second so that it matches what durationHMS displays.
        if let gs = self.currentGroundSpeed?.converted(to: .metersPerSecond),
           let dist = self.distance?.converted(to: .meters),
           gs.value > 0 {
            let rawETE = dist.value / gs.value // seconds
            self.ete = rawETE.isFinite ? rawETE.rounded(.down) : nil
        } else {
            self.ete = nil
        }

        // Set ETA from the floored clock and the truncated ETE so Time + ETE == ETA on screen.
        if let ete = self.ete {
            self.eta = flooredClock.addingTimeInterval(ete)
        } else {
            self.eta = nil
        }

        // Set Required Ground Speed (B-24). Distance only changes with a fix, but the time
        // left to ToT shrinks every second, so the value is recomputed here on every tick
        // from the cached distance rather than only inside the location callback. Uses the
        // floored clock so the time remaining is on the same whole-second basis as ToT.
        if let dist = self.distance, let tot = self.tot,
           let rgs = computeRequiredGroundSpeed(distance: dist, arrivalTime: tot, now: flooredClock) {
            self.requiredGroundSpeed = rgs.converted(to: .knots)
        } else {
            self.requiredGroundSpeed = nil
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

        // Required ground speed is not computed here (B-24): it depends on the time left to
        // ToT, which changes every second, so `updateTimings()` derives it from the cached
        // distance on each tick. This callback only refreshes what the fix itself provides.
    }
    
    // MARK: - Helpers
    /// Drops the sub-second part of `date` (B-40 whole-second policy).
    private static func floorToSecond(_ date: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate.rounded(.down))
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

