//
//  CalloutEngine.swift
//  Formation Flight
//
//  F-01: decides which in-flight callout, if any, to give on each 1 Hz tick.
//

import Foundation

/// One banner / spoken callout.
struct Callout: Equatable, Sendable {
    /// Event type, in priority order: when several are due on the same tick the first wins
    /// and the others are re-evaluated on later ticks (or dropped if no longer true).
    enum Kind: Sendable {
        case countdown
        case turnIn
        case gps
        case drift
        case speed
    }

    let kind: Kind
    /// Short radio-style phrase, used for both the banner and speech.
    let text: String
}

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
struct CalloutEngine {
    struct Input {
        var now: Date
        var tot: Date?
        /// Positive late, negative early (whole seconds), as shown in the Δ row.
        var delta: TimeInterval?
        var yellowTolerance: Int
        var redTolerance: Int
        /// Orbit in progress from the track rate; nil while straight.
        var turnDirection: TurnToTarget.Direction?
        /// Direction of the modelled turn onto the target.
        var turnInDirection: TurnToTarget.Direction?
        /// Seconds of turn left before pointing at the target; nil when the geometry is unknown.
        var turnRemaining: TimeInterval?
        var currentGroundSpeed: Measurement<UnitSpeed>?
        var requiredGroundSpeed: Measurement<UnitSpeed>?
        /// The last fix is older than the staleness threshold.
        var isFixStale: Bool
        var settings: CalloutSettings
        var speedUnit: Settings.SpeedUnit
    }

    // MARK: - Tuning

    /// Seconds before ToT that get a callout. 0 is "Mark".
    static let countdownMarks = [300, 60, 30, 10, 5, 4, 3, 2, 1, 0]
    static let advisoryGap: TimeInterval = 5
    static let driftHold: TimeInterval = 3
    static let driftCooldown: TimeInterval = 15
    static let speedHold: TimeInterval = 3
    static let speedInterval: TimeInterval = 30
    static let finalRunWindow = 15
    /// A pending turn shorter than this is "already pointed at it": no start-turn cue.
    static let minimumTurnForCue: TimeInterval = 5
    /// Roll-out cue lead: about 9° of standard-rate turn before pointing at the target.
    static let rollOutLead: TimeInterval = 3
    /// The roll-out cue arms only once the turn has at least this much left, so it fires once
    /// per approach to the target rather than on every tick near it.
    static let rollOutArmTurn: TimeInterval = 10

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

    init() {}

    // MARK: - Evaluation

    /// Updates the trackers with this tick's state and returns the callout to give, if any.
    mutating func evaluate(_ input: Input) -> Callout? {
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
            return emit(Callout(kind: .countdown, text: Self.countdownText(mark)), at: now)
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
                pendingGPS = Callout(kind: .gps, text: String(localized: "GPS lost.", comment: "Callout: the GPS fix has gone stale"))
            } else {
                pendingGPS = gpsLostAnnounced
                    ? Callout(kind: .gps, text: String(localized: "GPS restored.", comment: "Callout: GPS fixes are arriving again"))
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
            switch direction {
            case .left: return Callout(kind: .turnIn, text: String(localized: "Turn left now.", comment: "Callout: start the turn onto the target, to the left"))
            case .right: return Callout(kind: .turnIn, text: String(localized: "Turn right now.", comment: "Callout: start the turn onto the target, to the right"))
            }
        }

        // Orbiting: about to point at the target with no full orbit to spare.
        if rollOutArmed, input.turnDirection != nil, let turn = input.turnRemaining, turn <= Self.rollOutLead,
           TurnToTarget.surplusOrbits(delta: delta) == 0 {
            rollOutArmed = false
            suppressDriftAnnouncement(band, at: input.now)
            return Callout(kind: .turnIn, text: String(localized: "Roll out now.", comment: "Callout: stop turning, now pointed at the target"))
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
        return Callout(kind: .drift, text: Self.driftText(delta: delta, isOnTime: band == .onTime))
    }

    /// "On time." inside the yellow tolerance, otherwise "Early, 12." / "Late, 1 minute, 5 seconds."
    static func driftText(delta: TimeInterval, isOnTime: Bool) -> String {
        let seconds = Int(abs(delta))
        if isOnTime || seconds == 0 {
            return String(localized: "On time.", comment: "Callout: Δ is within the yellow tolerance")
        }
        let amount: String
        if seconds < 60 {
            amount = "\(seconds)"
        } else {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.minute, .second]
            formatter.unitsStyle = .full
            amount = formatter.string(from: TimeInterval(seconds)) ?? "\(seconds)"
        }
        return delta < 0
            ? String(localized: "Early, \(amount).", comment: "Callout: early by this many seconds, or minutes and seconds")
            : String(localized: "Late, \(amount).", comment: "Callout: late by this many seconds, or minutes and seconds")
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

        let unit: UnitSpeed
        switch input.speedUnit {
        case .kts: unit = .knots
        case .mph: unit = .milesPerHour
        case .kph: unit = .kilometersPerHour
        }
        let value = Int(required.converted(to: unit).value.rounded())
        return increase
            ? Callout(kind: .speed, text: String(localized: "Increase, \(value).", comment: "Callout: speed up to this ground speed, in the pilot's unit"))
            : Callout(kind: .speed, text: String(localized: "Reduce, \(value).", comment: "Callout: slow down to this ground speed, in the pilot's unit"))
    }

    // MARK: - Countdown

    static func countdownText(_ mark: Int) -> String {
        switch mark {
        case 300: String(localized: "Five minutes.", comment: "Callout: five minutes to ToT")
        case 60: String(localized: "One minute.", comment: "Callout: one minute to ToT")
        case 30: String(localized: "Thirty seconds.", comment: "Callout: thirty seconds to ToT")
        case 10: String(localized: "Ten.", comment: "Callout: ten seconds to ToT")
        case 0: String(localized: "Mark.", comment: "Callout: now at ToT")
        default: "\(mark)."
        }
    }
}
