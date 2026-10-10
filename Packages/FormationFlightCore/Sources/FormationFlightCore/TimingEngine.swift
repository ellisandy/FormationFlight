//
//  TimingEngine.swift
//  FormationFlightCore
//
//  The flight screen's timing math, extracted from `FlightViewModel.updateTimings()` so the
//  phone, its Live Activity and the watch all derive Time / ETE / ETA / Req GS / Δ / status
//  from the same inputs with the same rules. The watch receives the inputs (`FlightSnapshot`)
//  and runs this on its own clock every second, which is how it "ticks locally".
//

import Foundation

/// How far Δ sits from the ToT relative to the pilot's tolerances.
///
/// Raw values are part of the phone-to-watch payload and must not change.
public enum TimingStatus: String, Codable, Equatable, Sendable, CaseIterable {
    /// |Δ| within the yellow tolerance.
    case good
    /// |Δ| beyond yellow, within red.
    case bad
    /// |Δ| beyond red.
    case reallyBad
    /// No Δ to judge (no fix, no speed, or no ToT).
    case unknown

    /// Maps a delta to a status: `|Δ| <= yellow` good, `<= red` bad, otherwise reallyBad.
    /// With no delta there is nothing to judge, so `.unknown` rather than a stale colour.
    public init(delta: TimeInterval?, yellowTolerance: Int, redTolerance: Int) {
        guard let delta else {
            self = .unknown
            return
        }
        let absDelta = abs(delta)
        if absDelta <= Double(yellowTolerance) {
            self = .good
        } else if absDelta <= Double(redTolerance) {
            self = .bad
        } else {
            self = .reallyBad
        }
    }
}

/// Pure timing computation for one tick.
///
/// Whole-second policy (B-40): Time, ETE and ETA are each shown truncated to the second. If the
/// clock and ETE were kept fractional and truncated independently at display time, the Time and
/// ETE readouts could add up to one second less than the ETA readout. So the engine truncates
/// (never rounds) at the source: the clock is floored to the second, ETE is floored to the
/// second, and ETA is derived from those two floored values. Delta then inherits the same basis.
public enum TimingEngine {
    // MARK: - Staleness (B-07)

    /// A fix older than this is no longer trusted for speed-derived readouts. GPS normally
    /// reports at 1 Hz, so 15 s of silence means the receiver has lost the sky or the app
    /// has stopped receiving updates; showing the last speed as if it were live would let
    /// ETE/ETA keep counting down on a frozen number. Mirrors use the same threshold for a
    /// phone that has stopped sending (`FlightSnapshot.isStale(at:)`).
    public static let staleFixThreshold: TimeInterval = 15

    /// Whether a fix received at `lastFix` is stale at `now`. No fix yet is not stale: there
    /// is nothing to blank, and the readouts already show placeholders.
    public static func isFixStale(lastFix: Date?, now: Date) -> Bool {
        lastFix.map { now.timeIntervalSince($0) > staleFixThreshold } ?? false
    }

    // MARK: - Input / Output

    /// Plain values for one tick. The caller blanks `groundSpeed`, `track` and
    /// `preferredTurnDirection` when the fix is stale (B-07); `distance` and `bearing` are kept
    /// because the last known position is still the best position estimate.
    public struct Input: Equatable, Sendable {
        /// Wall clock, unfloored; the engine floors it (B-40).
        public var now: Date
        public var tot: Date?
        /// Distance to the target, metres.
        public var distance: Double?
        /// Ground speed, metres per second. Nil or non-positive means unknown.
        public var groundSpeed: Double?
        /// True track, degrees. Nil, negative (Core Location's "invalid") or non-finite is unknown.
        public var track: Double?
        /// True bearing to the target, degrees. Same validity rules as `track`.
        public var bearing: Double?
        /// The orbit in progress from the track rate (B-25); the modelled path continues it.
        public var preferredTurnDirection: TurnToTarget.Direction?
        /// Status tolerances, seconds.
        public var yellowTolerance: Int
        public var redTolerance: Int

        public init(now: Date,
                    tot: Date?,
                    distance: Double?,
                    groundSpeed: Double?,
                    track: Double?,
                    bearing: Double?,
                    preferredTurnDirection: TurnToTarget.Direction?,
                    yellowTolerance: Int,
                    redTolerance: Int) {
            self.now = now
            self.tot = tot
            self.distance = distance
            self.groundSpeed = groundSpeed
            self.track = track
            self.bearing = bearing
            self.preferredTurnDirection = preferredTurnDirection
            self.yellowTolerance = yellowTolerance
            self.redTolerance = redTolerance
        }
    }

    public struct Output: Equatable, Sendable {
        /// `now` floored to the whole second (B-40): the Time readout.
        public var currentTime: Date
        /// Whole seconds to the target along the turn-then-straight path (B-25), floored.
        public var ete: TimeInterval?
        /// `currentTime + ete`, so Time + ETE == ETA on screen.
        public var eta: Date?
        /// Seconds from `currentTime` to ToT, negative once past it; nil with no ToT.
        public var timeToToT: TimeInterval?
        /// Ground speed to set after rolling out to arrive at ToT, metres per second (B-24,
        /// B-25, B-42). Nil with no distance, no ToT, ToT passed, or no achievable speed.
        public var requiredGroundSpeed: Double?
        /// ETA minus ToT in whole seconds, truncated toward zero (B-46). Positive is late.
        public var delta: TimeInterval?
        public var status: TimingStatus
        /// Whole seconds of the ETE spent in the roll-in turn, nil under one second or with no
        /// turn modelled. Feeds the ETE row's caption (B-45).
        public var turnDuration: TimeInterval?
        /// Which way the modelled path turns onto the target; nil whenever `turnDuration` is.
        public var turnInDirection: TurnToTarget.Direction?
        /// Unrounded seconds of turn left before pointing at the target; nil when the geometry
        /// is unknown or degenerate. Feeds the turn cues (F-01), which need 0 as a value.
        public var turnRemaining: TimeInterval?
        /// Complete standard-rate orbits that fit while early (B-25); 0 when on time or late.
        public var surplusOrbits: Int

        public init(currentTime: Date,
                    ete: TimeInterval? = nil,
                    eta: Date? = nil,
                    timeToToT: TimeInterval? = nil,
                    requiredGroundSpeed: Double? = nil,
                    delta: TimeInterval? = nil,
                    status: TimingStatus = .unknown,
                    turnDuration: TimeInterval? = nil,
                    turnInDirection: TurnToTarget.Direction? = nil,
                    turnRemaining: TimeInterval? = nil,
                    surplusOrbits: Int = 0) {
            self.currentTime = currentTime
            self.ete = ete
            self.eta = eta
            self.timeToToT = timeToToT
            self.requiredGroundSpeed = requiredGroundSpeed
            self.delta = delta
            self.status = status
            self.turnDuration = turnDuration
            self.turnInDirection = turnInDirection
            self.turnRemaining = turnRemaining
            self.surplusOrbits = surplusOrbits
        }
    }

    // MARK: - Compute

    public static func compute(_ input: Input) -> Output {
        let flooredClock = floorToSecond(input.now)
        var output = Output(currentTime: flooredClock)
        let geometry = turnGeometry(track: input.track, bearing: input.bearing)

        // ETE (B-25): the time to turn onto the target at standard rate, continuing the orbit
        // already in progress, and then fly straight to it. Without a usable track or bearing
        // this degrades to the direct-to figure, distance / speed. Truncated to a whole second
        // so that it matches what durationHMS displays (B-40).
        if let gs = input.groundSpeed, gs > 0, let dist = input.distance {
            let rawETE: Double
            if let geometry,
               let solution = TurnToTarget.solve(distance: dist, bearing: geometry.bearing, track: geometry.track,
                                                 groundSpeed: gs, preferredDirection: input.preferredTurnDirection) {
                rawETE = solution.totalTime
                // Under a second of turn is "already pointed at it": no caption.
                let turnSeconds = solution.turnDuration.rounded(.down)
                output.turnDuration = turnSeconds >= 1 ? turnSeconds : nil
                output.turnInDirection = turnSeconds >= 1 ? solution.direction : nil
                output.turnRemaining = solution.isDirectFallback ? nil : solution.turnDuration
            } else {
                rawETE = dist / gs
            }
            output.ete = rawETE.isFinite ? rawETE.rounded(.down) : nil
        }

        // ETA from the floored clock and the truncated ETE so Time + ETE == ETA on screen.
        if let ete = output.ete {
            output.eta = flooredClock.addingTimeInterval(ete)
        }

        output.timeToToT = input.tot?.timeIntervalSince(flooredClock)

        // Required ground speed (B-24). Distance only changes with a fix, but the time left to
        // ToT shrinks every second, so it is recomputed on every tick. Uses the floored clock
        // so the time remaining is on the same whole-second basis as ToT. Turn-aware (B-25):
        // the speed at which the turn-then-straight path arrives exactly at ToT, so it is the
        // speed to set after rolling out. Direct-to when the geometry is unknown.
        if let dist = input.distance, let tot = input.tot {
            output.requiredGroundSpeed = requiredGroundSpeed(distance: dist, arrivalTime: tot, now: flooredClock,
                                                             geometry: geometry,
                                                             preferredDirection: input.preferredTurnDirection)
        }

        // Delta. Positive means ETA is after ToT (late), negative early. Truncated to the whole
        // seconds the Δ readout shows (B-46): a ToT with a fractional second otherwise put
        // "LATE +00:00:00" on screen for a sub-second miss.
        if let eta = output.eta, let tot = input.tot {
            output.delta = eta.timeIntervalSince(tot).rounded(.towardZero)
        }

        // Orbit hint (B-25): while early by at least one full standard-rate orbit (120 s), a
        // complete go-around still fits before the turn-in point.
        output.surplusOrbits = output.delta.map(TurnToTarget.surplusOrbits(delta:)) ?? 0
        output.status = TimingStatus(delta: output.delta, yellowTolerance: input.yellowTolerance,
                                     redTolerance: input.redTolerance)
        return output
    }

    // MARK: - Helpers

    /// Drops the sub-second part of `date` (B-40 whole-second policy).
    public static func floorToSecond(_ date: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate.rounded(.down))
    }

    /// Track and bearing in true degrees when both are known and valid, for the turn model.
    static func turnGeometry(track: Double?, bearing: Double?) -> (track: Double, bearing: Double)? {
        guard let track, track >= 0, track.isFinite,
              let bearing, bearing >= 0, bearing.isFinite
        else { return nil }
        return (track, bearing)
    }

    static func requiredGroundSpeed(distance meters: Double,
                                    arrivalTime: Date,
                                    now: Date,
                                    geometry: (track: Double, bearing: Double)?,
                                    preferredDirection: TurnToTarget.Direction?) -> Double? {
        let timeRemaining = arrivalTime.timeIntervalSince(now) // seconds
        // Already at/after the arrival time; cannot compute a positive required speed.
        guard timeRemaining > 0 else { return nil }
        let mps: Double
        if let geometry,
           let turnAware = TurnToTarget.requiredGroundSpeed(distance: meters, bearing: geometry.bearing,
                                                            track: geometry.track, timeRemaining: timeRemaining,
                                                            preferredDirection: preferredDirection) {
            mps = turnAware
        } else if geometry != nil {
            // Turn geometry known but no speed in range can make the time.
            return nil
        } else {
            mps = meters / timeRemaining
        }
        guard mps.isFinite && mps > 0 else { return nil }
        return mps
    }
}
