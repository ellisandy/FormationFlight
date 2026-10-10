//
//  CalloutEngine.swift
//  FormationFlightCore
//
//  F-01: decides which in-flight callout, if any, to give on each 1 Hz tick.
//

import Foundation

/// Turns the flight screen's derived state into callouts, keeping them sparse.
///
/// Pure value type, fed one `Input` per timer tick, so every rule is unit-testable with an
/// injected clock. Noise rules (product decision: "don't make it too noisy"):
/// - Countdown marks and turn cues are time-critical and are never held back.
/// - Every other callout waits `advisoryGap` after the previous callout of any kind.
/// - Drift is announced only when Δ has sat in a new band for `driftHold`, and at most once
///   per `driftCooldown`. A first reading that is already on time is not announced.
/// - Speed advice is given only while Δ is outside the yellow tolerance, after the gap has
///   persisted for `speedHold`, at most once per `speedInterval`, and not repeated unless the
///   target speed has moved by the threshold or the direction has flipped.
/// - With the countdown on, only the countdown speaks in the last `finalRunWindow` seconds.
///   After ToT, only GPS callouts remain.
/// - Level conditions (drift, speed) that are blocked are not queued: they are re-checked on
///   the next tick, so nothing stale is ever spoken.
public struct CalloutEngine {
    public struct Input: Sendable {
        public var now: Date
        public var tot: Date?
        /// Positive late, negative early (whole seconds), as shown in the Δ row.
        public var delta: TimeInterval?
        public var yellowTolerance: Int
        public var redTolerance: Int
        /// Orbit in progress from the track rate; nil while straight.
        public var turnDirection: TurnToTarget.Direction?
        /// Direction of the modelled turn onto the target.
        public var turnInDirection: TurnToTarget.Direction?
        /// Seconds of turn left before pointing at the target; nil when the geometry is unknown.
        public var turnRemaining: TimeInterval?
        public var currentGroundSpeed: Measurement<UnitSpeed>?
        public var requiredGroundSpeed: Measurement<UnitSpeed>?
        /// The last fix is older than the staleness threshold.
        public var isFixStale: Bool
        public var settings: CalloutSettings
        /// The pilot's display unit, for the target speed in a speed advisory.
        public var speedUnit: SpeedUnit

        public init(now: Date,
                    tot: Date?,
                    delta: TimeInterval?,
                    yellowTolerance: Int,
                    redTolerance: Int,
                    turnDirection: TurnToTarget.Direction?,
                    turnInDirection: TurnToTarget.Direction?,
                    turnRemaining: TimeInterval?,
                    currentGroundSpeed: Measurement<UnitSpeed>?,
                    requiredGroundSpeed: Measurement<UnitSpeed>?,
                    isFixStale: Bool,
                    settings: CalloutSettings,
                    speedUnit: SpeedUnit) {
            self.now = now
            self.tot = tot
            self.delta = delta
            self.yellowTolerance = yellowTolerance
            self.redTolerance = redTolerance
            self.turnDirection = turnDirection
            self.turnInDirection = turnInDirection
            self.turnRemaining = turnRemaining
            self.currentGroundSpeed = currentGroundSpeed
            self.requiredGroundSpeed = requiredGroundSpeed
            self.isFixStale = isFixStale
            self.settings = settings
            self.speedUnit = speedUnit
        }
    }

    // MARK: - Tuning

    /// Seconds before ToT that get a callout. 0 is "Mark".
    public static let countdownMarks = [300, 60, 30, 10, 5, 4, 3, 2, 1, 0]
    public static let advisoryGap: TimeInterval = 5
    public static let driftHold: TimeInterval = 3
    public static let driftCooldown: TimeInterval = 15
    public static let speedHold: TimeInterval = 3
    public static let speedInterval: TimeInterval = 30
    public static let finalRunWindow = 15
    /// A pending turn shorter than this is "already pointed at it": no start-turn cue.
    public static let minimumTurnForCue: TimeInterval = 5
    /// Roll-out cue lead: about 9° of standard-rate turn before pointing at the target.
    public static let rollOutLead: TimeInterval = 3
    /// The roll-out cue arms only once the turn has at least this much left, so it fires once
    /// per approach to the target rather than on every tick near it.
    public static let rollOutArmTurn: TimeInterval = 10

    // MARK: - State

    private var lastRemaining: Int?
    private var lastCalloutAt: Date?

    private enum DriftBand: Equatable {
        case onTime, earlyWarning, earlyBad, lateWarning, lateBad
    }
    private var announcedBand: DriftBand?
    private var candidateBand: DriftBand?
    private var candidateSince: Date?
    private var lastDriftAt: Date?

    private var startTurnArmed = false
    private var rollOutArmed = false

    private var speedGapSince: Date?
    private var lastSpeedAt: Date?
    private var lastSpeedTargetKnots: Double?
    private var lastSpeedIncrease: Bool?

    private var wasStale = false
    private var gpsLostAnnounced = false
    private var pendingGPS: Callout?

    public init() {}

    // MARK: - Evaluation

    /// Updates the trackers with this tick's state and returns the callout to give, if any.
    public mutating func evaluate(_ input: Input) -> Callout? {
        let settings = input.settings
        let now = input.now
        // Whole seconds to ToT, rounded up so "Mark" lands on the first tick at or after ToT.
        let remaining = input.tot.map { Int($0.timeIntervalSince(now).rounded(.up)) }
        defer { lastRemaining = remaining }

        let band = input.delta.map { Self.band(for: $0, yellow: input.yellowTolerance, red: input.redTolerance) }
        updateTrackers(input, band: band)

        let isPastToT = remaining.map { $0 < 0 } ?? false
        let inFinalRun = settings.countdownEnabled && remaining.map { (1...Self.finalRunWindow).contains($0) } == true
        let advisoriesAllowed = !isPastToT && !inFinalRun

        // 1. Countdown. A mark is given only on the tick that crosses it (one second of slack
        //    for a late timer), so editing the ToT never replays marks already passed.
        if settings.countdownEnabled, let remaining, let previous = lastRemaining,
           let mark = Self.countdownMarks.first(where: { previous > $0 && remaining <= $0 && remaining >= $0 - 1 }) {
            return emit(Callout(.countdown(secondsToToT: mark)), at: now)
        }

        // 2. Turn cues.
        if settings.turnInEnabled, advisoriesAllowed, let callout = turnCue(input, band: band) {
            return emit(callout, at: now)
        }

        // Everything below waits for the gap after the previous callout.
        if let lastCalloutAt, now.timeIntervalSince(lastCalloutAt) < Self.advisoryGap { return nil }

        // 3. GPS lost / restored.
        if !settings.speedAndGPSEnabled { pendingGPS = nil }
        if let gps = pendingGPS, !inFinalRun {
            pendingGPS = nil
            gpsLostAnnounced = input.isFixStale
            return emit(gps, at: now)
        }

        // 4. Drift.
        if settings.driftEnabled, advisoriesAllowed, let callout = driftCallout(input, band: band) {
            return emit(callout, at: now)
        }

        // 5. Speed.
        if settings.speedAndGPSEnabled, advisoriesAllowed, let callout = speedCallout(input, band: band) {
            return emit(callout, at: now)
        }
        return nil
    }

    private mutating func emit(_ callout: Callout, at now: Date) -> Callout {
        lastCalloutAt = now
        return callout
    }

    /// Observations that must run every tick, whether or not a callout is given.
    private mutating func updateTrackers(_ input: Input, band: DriftBand?) {
        // GPS edges. A recovery is announced only if the loss was.
        if input.isFixStale != wasStale {
            if input.isFixStale {
                pendingGPS = Callout(.gpsLost)
            } else {
                pendingGPS = gpsLostAnnounced
                    ? Callout(.gpsRestored)
                    : nil
                gpsLostAnnounced = false
            }
            wasStale = input.isFixStale
        }

        // Start-turn cue arms while flying straight, early beyond yellow, with a turn ahead.
        if input.turnDirection != nil || input.delta == nil {
            startTurnArmed = false
        } else if let delta = input.delta, delta < -Double(input.yellowTolerance), hasPendingTurn(input) {
            startTurnArmed = true
        }

        // Roll-out cue arms once an orbit has a good part of a turn still to go.
        if input.turnDirection == nil {
            rollOutArmed = false
        } else if let turn = input.turnRemaining, turn >= Self.rollOutArmTurn {
            rollOutArmed = true
        }

        if band != candidateBand {
            candidateBand = band
            candidateSince = input.now
        }

        if speedGap(input) != nil {
            if speedGapSince == nil { speedGapSince = input.now }
        } else {
            speedGapSince = nil
        }
    }

    // MARK: - Turn cues

    private func hasPendingTurn(_ input: Input) -> Bool {
        input.turnInDirection != nil && (input.turnRemaining ?? 0) >= Self.minimumTurnForCue
    }

    private mutating func turnCue(_ input: Input, band: DriftBand?) -> Callout? {
        guard let delta = input.delta else { return nil }

        // Straight (e.g. a racetrack leg): the turn-in-now path has just come on time.
        if startTurnArmed, input.turnDirection == nil, hasPendingTurn(input),
           delta >= -Double(input.yellowTolerance), let direction = input.turnInDirection {
            startTurnArmed = false
            suppressDriftAnnouncement(band, at: input.now)
            return Callout(.turnIn(direction))
        }

        // Orbiting: about to point at the target with no full orbit to spare.
        if rollOutArmed, input.turnDirection != nil, let turn = input.turnRemaining, turn <= Self.rollOutLead,
           TurnToTarget.surplusOrbits(delta: delta) == 0 {
            rollOutArmed = false
            suppressDriftAnnouncement(band, at: input.now)
            return Callout(.rollOut)
        }
        return nil
    }

    /// A turn cue already tells the pilot where they stand; don't follow it with "On time."
    private mutating func suppressDriftAnnouncement(_ band: DriftBand?, at now: Date) {
        guard let band else { return }
        announcedBand = band
        lastDriftAt = now
    }

    // MARK: - Drift

    private static func band(for delta: TimeInterval, yellow: Int, red: Int) -> DriftBand {
        // Same mapping as the Δ row's status colour.
        let magnitude = abs(delta)
        if magnitude <= Double(yellow) { return .onTime }
        let isBad = magnitude > Double(red)
        if delta < 0 { return isBad ? .earlyBad : .earlyWarning }
        return isBad ? .lateBad : .lateWarning
    }

    private mutating func driftCallout(_ input: Input, band: DriftBand?) -> Callout? {
        guard let band, let delta = input.delta, band != announcedBand,
              let candidateSince, input.now.timeIntervalSince(candidateSince) >= Self.driftHold
        else { return nil }
        if let lastDriftAt, input.now.timeIntervalSince(lastDriftAt) < Self.driftCooldown { return nil }

        let isFirstReading = announcedBand == nil
        announcedBand = band
        if isFirstReading && band == .onTime { return nil }
        lastDriftAt = input.now
        return Callout(Self.driftEvent(delta: delta, isOnTime: band == .onTime))
    }

    /// The drift event for a whole-second Δ: on time inside the yellow tolerance (or at a
    /// zero magnitude), otherwise early or late by `|Δ|`.
    public static func driftEvent(delta: TimeInterval, isOnTime: Bool) -> Callout.Event {
        let seconds = Int(abs(delta))
        let relation: Callout.DriftRelation
        if isOnTime || seconds == 0 {
            relation = .onTime
        } else {
            relation = delta < 0 ? .early : .late
        }
        return .drift(seconds: seconds, relation: relation)
    }

    /// "On time." inside the yellow tolerance, otherwise "Early, 12." / "Late, 1 minute, 5 seconds."
    public static func driftText(delta: TimeInterval, isOnTime: Bool) -> String {
        driftEvent(delta: delta, isOnTime: isOnTime).text
    }

    // MARK: - Speed

    /// Required minus current ground speed in knots when it is at least the threshold.
    private func speedGap(_ input: Input) -> Double? {
        guard let current = input.currentGroundSpeed?.converted(to: .knots).value,
              let required = input.requiredGroundSpeed?.converted(to: .knots).value,
              current.isFinite, required.isFinite else { return nil }
        let gap = required - current
        return abs(gap) >= input.settings.speedThresholdKnots ? gap : nil
    }

    private mutating func speedCallout(_ input: Input, band: DriftBand?) -> Callout? {
        // On time means the current speed is good enough, whatever the model's figure says.
        guard let band, band != .onTime,
              let gap = speedGap(input), let since = speedGapSince,
              input.now.timeIntervalSince(since) >= Self.speedHold,
              let required = input.requiredGroundSpeed
        else { return nil }
        if let lastSpeedAt, input.now.timeIntervalSince(lastSpeedAt) < Self.speedInterval { return nil }

        let requiredKnots = required.converted(to: .knots).value
        let increase = gap > 0
        if let lastTarget = lastSpeedTargetKnots, lastSpeedIncrease == increase,
           abs(requiredKnots - lastTarget) < input.settings.speedThresholdKnots {
            return nil
        }
        lastSpeedAt = input.now
        lastSpeedTargetKnots = requiredKnots
        lastSpeedIncrease = increase

        let value = Int(required.converted(to: input.speedUnit.unitSpeed).value.rounded())
        return Callout(.speed(increase: increase, target: value, unit: input.speedUnit))
    }

    // MARK: - Countdown

    public static func countdownText(_ mark: Int) -> String {
        Callout.Event.countdownText(mark)
    }
}
