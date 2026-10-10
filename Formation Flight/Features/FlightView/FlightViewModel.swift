//
//  FlightViewModel.swift
//  Formation Flight
//
//  Created by Jack Ellis on 11/13/25.
//

import Foundation
@preconcurrency import Combine
import CoreLocation
import FormationFlightCore

@MainActor
final class FlightViewModel: ObservableObject {
    // MARK: - Types
    /// The Δ status moved to FormationFlightCore (`TimingStatus`) so the watch and the Live
    /// Activity judge it with the same rule; the alias keeps `FlightViewModel.Status` working
    /// for `StatusStyling` and the views.
    typealias Status = TimingStatus
    
    // MARK: - Published State (Timing)
    @Published var currentTime: Date?
    @Published var ete: TimeInterval?
    @Published var eta: Date?
    @Published var delta: TimeInterval?
    @Published var tot: Date?
    @Published var statusColor: Status = .unknown
    /// Textual early/late indicator shown beside the Δ value (B-11): "EARLY", "LATE",
    /// "ON TIME", or nil when there is no delta to judge.
    @Published private(set) var deltaLabel: String?
    /// Seconds of the ETE spent in the roll-in turn (B-25), nil when ETE is nil or no turn is
    /// needed. Shown in the ETE row's caption (B-45) so the pilot can tell a short turn-in
    /// from a continuation of most of the orbit.
    @Published private(set) var turnDuration: TimeInterval?
    /// Which way the modelled path turns onto the target, nil whenever `turnDuration` is nil.
    /// The detected orbit while turning, otherwise the shorter side.
    @Published private(set) var turnInDirection: TurnToTarget.Direction?
    /// The orbit direction inferred from the GPS track rate, nil when flying straight. The
    /// time-to-target path continues this turn rather than assuming a reversal. Marked on the
    /// Trk card (B-45).
    @Published private(set) var turnDirection: TurnToTarget.Direction?

    /// The callout banner on screen (F-01), cleared `calloutBannerDuration` after it appears.
    @Published private(set) var activeCallout: Callout?
    static let calloutBannerDuration: TimeInterval = 4

    /// ETE row caption (B-45): the turn the ETE assumes, e.g. "TURN 0:45 R"; nil with no turn.
    /// Shared with the watch companion (F-02).
    var turnCaption: String? {
        FlightFormatting.turnCaption(duration: turnDuration, direction: turnInDirection)
    }

    // MARK: - Published State (Instruments)
    @Published var currentGroundSpeed: Measurement<UnitSpeed>?
    @Published var requiredGroundSpeed: Measurement<UnitSpeed>?
    @Published var distance: Measurement<UnitLength>?
    /// Bearing to the target, TRUE north, degrees (B-26 decision, 2026-10-07).
    ///
    /// Both `bearing` and `track` come from GPS geometry and are deliberately left true with no
    /// `°T` label: pilots steer so Trk matches Brg, so the only requirement is that the two share
    /// one reference. Do not convert one of them to magnetic without converting the other.
    @Published var bearing: Measurement<UnitAngle>?
    /// Track over the ground, TRUE north, degrees. Same reference as `bearing`; see above.
    @Published var track: Measurement<UnitAngle>?
    
    // MARK: - Published State (Mission Details)
    @Published var missionName: String
    @Published var target: CLLocationCoordinate2D
    
    // MARK: - Dependencies / Model Objects
    // B-18: the view reads `settings` (units, instrument layout) and `missionType`, and the
    // in-flight hack wheel binds to `hackTime`, so all three must publish or the view can
    // render a stale value after an edit.
    @Published var settings: Settings
    var locationProvider: LocationProviding
    @Published var missionType: MissionType
    var missionDate: Date?
    @Published var hackTime: TimeInterval?
    
    // MARK: - UI State
    @Published var isEditingToT: Bool = false
    @Published var isEditingHackTime: Bool = false
    
    // MARK: - Staleness (B-07)
    /// A fix older than this is no longer trusted for speed-derived readouts. Defined in
    /// FormationFlightCore (`TimingEngine.staleFixThreshold`, 15 s) so mirrors use the same rule.
    static let staleFixThreshold: TimeInterval = TimingEngine.staleFixThreshold
    /// Clock reading at the most recent location callback; nil until the first fix.
    private var lastLocationUpdate: Date?
    /// Tracks the sign of the heading rate across fixes to tell which way we are orbiting (B-25).
    private var turnDetector = TurnDetector()
    /// Seconds of modelled turn left before pointing at the target, unrounded; nil when the
    /// geometry is unknown. Feeds the turn cues (F-01), which need "pointed at it" (0) as a value.
    private var turnRemaining: TimeInterval?

    // MARK: - Callouts (F-01)
    private var calloutEngine = CalloutEngine()
    /// Nil in tests and previews, so they never speak.
    private let speaker: CalloutSpeaking?
    private var calloutShownAt: Date?

    // MARK: - Mirrors (watch companion, Live Activity)
    /// Outputs that mirror the flight elsewhere. Each gets a snapshot every timing tick (and on
    /// Hack!), every callout the banner gets, and the end of the flight. Empty in tests and
    /// previews unless a test injects a fake.
    private let mirrors: [any FlightMirroring]

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
         speaker: CalloutSpeaking? = nil,
         mirrors: [any FlightMirroring] = [],
         now: @escaping () -> Date = { Date() }) {
        self.settings = settings
        self.locationProvider = locationProvider
        self.timerScheduler = timerScheduler
        self.speaker = speaker
        self.mirrors = mirrors
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
         speaker: CalloutSpeaking? = nil,
         mirrors: [any FlightMirroring] = [],
         now: @escaping () -> Date = { Date() }) {
        self.settings = settings
        self.locationProvider = locationProvider
        self.timerScheduler = timerScheduler
        self.speaker = speaker
        self.mirrors = mirrors
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
    /// and stops GPS monitoring. Safe to call when not started. Mirrors get a final snapshot
    /// marked `isEnded` and then `flightDidEnd()`, so a watch or Live Activity can show the
    /// end state rather than going STALE.
    func stop() {
        guard timerToken != nil else { return }
        timerToken?.cancel()
        timerToken = nil
        locationProvider.updateDelegate = nil
        locationProvider.stopMonitoring()
        speaker?.stop()
        if !mirrors.isEmpty {
            let final = makeSnapshot(isEnded: true)
            for mirror in mirrors {
                mirror.flightDidUpdate(final)
                mirror.flightDidEnd()
            }
        }
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
        let pressed = TimingEngine.floorToSecond(now())
        tot = pressed.addingTimeInterval(_hackTime)
        // Mirrors learn the new ToT now rather than up to a second later on the next tick.
        sendSnapshot()
    }
    
    // MARK: - Location Updates
    func onLocationUpdate() {
        AppLogger.viewModel.debug("Location update received from LocationProvider")
        lastLocationUpdate = now()
        updateInstruments()
    }
    
    // MARK: - Update Pipelines
    /// One 1 Hz tick: the readouts come from `TimingEngine` (FormationFlightCore), which owns
    /// the whole-second policy (B-40), the turn-aware ETE (B-25), required ground speed (B-24,
    /// B-42), the Δ truncation (B-46) and the status mapping. This method only feeds it the
    /// current inputs, applies the stale-fix rule (B-07), publishes the results, and adds the
    /// localized Δ label (B-11).
    private func updateTimings() {
        let wallClock = now()
        self.currentTime = TimingEngine.floorToSecond(wallClock)

        // Stale fix (B-07): once the newest fix is older than the threshold, the speed and
        // course it carried are no longer live. Clearing them here makes ETE, ETA, delta and
        // the status fall through to their "nothing to judge" branches, so the pilot sees
        // placeholders instead of numbers counting down on a frozen speed. Distance and
        // bearing are kept: the last known position is still the best position estimate.
        let isFixStale = TimingEngine.isFixStale(lastFix: lastLocationUpdate, now: wallClock)
        if isFixStale {
            self.currentGroundSpeed = nil
            self.track = nil
            turnDetector.reset()
            turnDirection = nil
        }

        let timing = TimingEngine.compute(timingInput(at: wallClock))
        self.ete = timing.ete
        self.turnDuration = timing.turnDuration
        self.turnInDirection = timing.turnInDirection
        self.turnRemaining = timing.turnRemaining
        self.eta = timing.eta
        self.requiredGroundSpeed = timing.requiredGroundSpeed
            .map { Measurement(value: $0, unit: UnitSpeed.metersPerSecond).converted(to: .knots) }
        self.delta = timing.delta

        // Spell out the sign of the delta (B-11). The tint alone is not a dependable cue in a
        // cockpit, and "+00:00:07" still needs the reader to remember which way the sign runs.
        if let _delta = delta {
            if _delta < 0 {
                // Orbit hint (B-25): while early by at least one full standard-rate orbit
                // (120 s), a complete go-around still fits before the turn-in point.
                let orbits = timing.surplusOrbits
                if orbits > 0 {
                    deltaLabel = String(localized: "EARLY · +\(orbits) ORBIT",
                                        comment: "Flight Δ row: early by at least this many full standard-rate orbits")
                } else {
                    deltaLabel = String(localized: "EARLY", comment: "Flight Δ row: ETA is before ToT")
                }
            } else if _delta > 0 {
                deltaLabel = String(localized: "LATE", comment: "Flight Δ row: ETA is after ToT")
            } else {
                deltaLabel = String(localized: "ON TIME", comment: "Flight Δ row: ETA equals ToT")
            }
        } else {
            deltaLabel = nil
        }

        statusColor = timing.status

        // Mirrors get this tick's inputs before any callout from it, so a watch already shows
        // the state the cue refers to when the haptic plays.
        sendSnapshot(at: wallClock, isFixStale: isFixStale)
        updateCallouts(at: timing.currentTime, isFixStale: isFixStale)
    }

    /// Runs the callout rules for this tick (F-01): shows the banner, speaks it when voice is
    /// on, and clears an expired banner.
    private func updateCallouts(at clock: Date, isFixStale: Bool) {
        if let shownAt = calloutShownAt, clock.timeIntervalSince(shownAt) >= Self.calloutBannerDuration {
            activeCallout = nil
            calloutShownAt = nil
        }
        let input = CalloutEngine.Input(
            now: clock,
            tot: tot,
            delta: delta,
            yellowTolerance: settings.yellowTolerance,
            redTolerance: settings.redTolerance,
            turnDirection: turnDirection,
            turnInDirection: turnInDirection,
            turnRemaining: turnRemaining,
            currentGroundSpeed: currentGroundSpeed,
            requiredGroundSpeed: requiredGroundSpeed,
            isFixStale: isFixStale,
            settings: settings.callouts,
            speedUnit: settings.speedUnit
        )
        guard let callout = calloutEngine.evaluate(input) else { return }
        deliver(callout, at: clock)
    }

    /// The one place a callout leaves the view model (F-01): the banner, the voice and every
    /// mirror (watch haptic, Live Activity) get the same `Callout`, so they never disagree.
    private func deliver(_ callout: Callout, at clock: Date) {
        activeCallout = callout
        calloutShownAt = clock
        if settings.callouts.voiceEnabled {
            speaker?.speak(callout.text)
        }
        for mirror in mirrors {
            mirror.flightDidEmit(callout)
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

        // Orbit direction (B-25): a valid course feeds the detector; the sentinel (< 0) means
        // the receiver has no course, so the detector forgets its history rather than
        // measuring a bogus rate against a stale sample. The rate is measured against the
        // fix's own timestamp (B-44), not the receipt time: Core Location delivers late and in
        // batches, which would otherwise read as a frozen or halved track rate.
        let course = locationProvider.course.converted(to: .degrees).value
        if course >= 0 {
            if let fixTime = locationProvider.lastFixTimestamp {
                turnDirection = turnDetector.record(track: course, at: fixTime)
            }
        } else {
            turnDetector.reset()
            turnDirection = nil
        }

        // Required ground speed is not computed here (B-24): it depends on the time left to
        // ToT, which changes every second, so `updateTimings()` derives it from the cached
        // distance on each tick. This callback only refreshes what the fix itself provides.
    }
    
    // MARK: - Helpers
    /// The current inputs for `TimingEngine`, in its plain units (metres, m/s, true degrees).
    /// Speed and track are already nil when the fix is stale (B-07).
    private func timingInput(at clock: Date) -> TimingEngine.Input {
        TimingEngine.Input(
            now: clock,
            tot: tot,
            distance: distance?.converted(to: .meters).value,
            groundSpeed: currentGroundSpeed?.converted(to: .metersPerSecond).value,
            track: track?.converted(to: .degrees).value,
            bearing: bearing?.converted(to: .degrees).value,
            preferredTurnDirection: turnDirection,
            yellowTolerance: settings.yellowTolerance,
            redTolerance: settings.redTolerance
        )
    }

    // MARK: - Mirrors
    /// The flight as mirror inputs: the same values `timingInput` feeds `TimingEngine`, so a
    /// receiver's `snapshot.timing(at:)` reproduces this screen's readouts.
    private func makeSnapshot(at clock: Date? = nil, isFixStale: Bool? = nil, isEnded: Bool = false) -> FlightSnapshot {
        let clock = clock ?? now()
        let input = timingInput(at: clock)
        return FlightSnapshot(
            sentAt: clock,
            missionName: missionName,
            missionType: missionType,
            tot: tot,
            hackTime: hackTime,
            isHackPending: missionType == .hackTime && tot == nil,
            fixTime: lastLocationUpdate,
            distance: input.distance,
            groundSpeed: input.groundSpeed,
            track: input.track,
            bearing: input.bearing,
            turnDirection: turnDirection,
            isFixStale: isFixStale ?? TimingEngine.isFixStale(lastFix: lastLocationUpdate, now: clock),
            yellowTolerance: settings.yellowTolerance,
            redTolerance: settings.redTolerance,
            speedUnit: settings.speedUnit,
            distanceUnit: settings.distanceUnit,
            isEnded: isEnded
        )
    }

    private func sendSnapshot(at clock: Date? = nil, isFixStale: Bool? = nil) {
        guard !mirrors.isEmpty else { return }
        let snapshot = makeSnapshot(at: clock, isFixStale: isFixStale)
        for mirror in mirrors {
            mirror.flightDidUpdate(snapshot)
        }
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

