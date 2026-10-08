//
//  TurnToTarget.swift
//  Formation Flight
//
//  B-25: the time-to-target model. The pilot orbits away from the target and watches the
//  screen to decide between "turn in now" and "go around again". ETE therefore answers:
//  "if I roll into (or continue) a standard-rate turn toward the target right now and then
//  fly straight, when do I pass overhead?"
//

import Foundation

/// Planar turn-then-straight path from the aircraft to a point target.
///
/// Geometry (local tangent plane, metres, x east / y north, compass angles clockwise from
/// north): the aircraft at the origin is flying along `track`. A standard-rate turn has radius
/// `R = groundSpeed / ω`. The two candidate turn circles sit `R` to the left and right of the
/// aircraft. For each, the aircraft follows the circle until the tangent line through the
/// target leaves it in the direction of travel, then flies that tangent. The time is the arc
/// divided by the turn rate plus the tangent length divided by groundspeed.
///
/// Distances in this app are at most a few tens of nautical miles, for which the planar
/// approximation errs by well under a second.
enum TurnToTarget {
    /// Standard-rate turn, 3° per second (a two-minute turn). Fixed by product decision; the
    /// pilot adjusts speed rather than turn rate to absorb small timing errors.
    static let standardRateDegreesPerSecond: Double = 3.0

    /// Duration of one complete orbit at standard rate: 120 s regardless of speed.
    static var fullOrbitDuration: TimeInterval { 360 / standardRateDegreesPerSecond }

    enum Direction: Equatable, Sendable {
        case left
        case right
    }

    struct Solution: Equatable, Sendable {
        /// Which way the aircraft turns onto the target.
        let direction: Direction
        /// Heading change flown in the turn, degrees in `0..<360`.
        let turnAngleDegrees: Double
        /// Time spent turning, seconds.
        let turnDuration: TimeInterval
        /// Straight-line distance from roll-out to the target, metres.
        let straightDistance: Double
        /// Turn plus straight segment, seconds.
        let totalTime: TimeInterval
        /// `true` when the target lies inside both turn circles and the path degenerates to
        /// distance / speed (the aircraft is effectively on top of the target).
        let isDirectFallback: Bool
    }

    /// Solves the turn-then-straight path.
    ///
    /// - Parameters:
    ///   - distance: Great-circle distance to the target, metres (> 0).
    ///   - bearing: True bearing to the target, degrees.
    ///   - track: True ground track, degrees.
    ///   - groundSpeed: Metres per second (> 0).
    ///   - preferredDirection: The turn already in progress, if any. When set and feasible it
    ///     is used even if the other direction is shorter: mid-orbit a reversal is not flown.
    ///   - turnRate: Degrees per second.
    /// - Returns: `nil` for non-positive or non-finite inputs.
    static func solve(distance: Double,
                      bearing: Double,
                      track: Double,
                      groundSpeed: Double,
                      preferredDirection: Direction? = nil,
                      turnRate: Double = standardRateDegreesPerSecond) -> Solution? {
        guard distance.isFinite, distance > 0,
              groundSpeed.isFinite, groundSpeed > 0,
              bearing.isFinite, track.isFinite,
              turnRate.isFinite, turnRate > 0 else { return nil }

        let omega = turnRate.degreesToRadians          // rad/s
        let radius = groundSpeed / omega                // m
        let trackRad = track.degreesToRadians
        let bearingRad = bearing.degreesToRadians

        // Target in the local frame (x east, y north) from the aircraft at the origin.
        let tx = distance * sin(bearingRad)
        let ty = distance * cos(bearingRad)

        func candidate(_ direction: Direction) -> Solution? {
            // Circle centre: R to the right of the track for a right turn, left otherwise.
            let (cx, cy): (Double, Double)
            switch direction {
            case .right: (cx, cy) = (radius * cos(trackRad), -radius * sin(trackRad))
            case .left:  (cx, cy) = (-radius * cos(trackRad), radius * sin(trackRad))
            }
            let dx = tx - cx, dy = ty - cy
            let d = (dx * dx + dy * dy).squareRoot()
            // Target inside this turn circle: no tangent exists for this direction.
            guard d >= radius * (1 - 1e-9) else { return nil }

            // Math-convention angles (counterclockwise from +x) measured at the circle centre.
            let phi = atan2(dy, dx)
            let gamma = acos(min(1, radius / d))
            let alphaExit: Double
            let alphaStart = atan2(-cy, -cx)   // the aircraft's position on the circle
            var arc: Double
            switch direction {
            case .right:
                alphaExit = phi + gamma
                arc = (alphaStart - alphaExit).truncatingRemainder(dividingBy: 2 * .pi)
            case .left:
                alphaExit = phi - gamma
                arc = (alphaExit - alphaStart).truncatingRemainder(dividingBy: 2 * .pi)
            }
            if arc < 0 { arc += 2 * .pi }
            // Floating-point noise can turn "no turn needed" into "a full circle".
            if arc > 2 * .pi - 1e-6 { arc = 0 }

            let straight = max(0, d * d - radius * radius).squareRoot()
            let turnDuration = arc / omega
            return Solution(direction: direction,
                            turnAngleDegrees: arc.radiansToDegrees,
                            turnDuration: turnDuration,
                            straightDistance: straight,
                            totalTime: turnDuration + straight / groundSpeed,
                            isDirectFallback: false)
        }

        let right = candidate(.right)
        let left = candidate(.left)

        if let preferredDirection {
            switch preferredDirection {
            case .right: if let right { return right }
            case .left: if let left { return left }
            }
        }
        switch (left, right) {
        case let (l?, r?): return l.totalTime <= r.totalTime ? l : r
        case let (l?, nil): return l
        case let (nil, r?): return r
        case (nil, nil):
            // The two circles touch only at the aircraft, so a target cannot lie strictly
            // inside both; this is a numerical safety net for a target at the aircraft's own
            // position. Fall back to the straight-line time so the readout never goes blank.
            return Solution(direction: preferredDirection ?? .right,
                            turnAngleDegrees: 0,
                            turnDuration: 0,
                            straightDistance: distance,
                            totalTime: distance / groundSpeed,
                            isDirectFallback: true)
        }
    }

    /// The groundspeed at which the turn-then-straight path arrives exactly `timeRemaining`
    /// seconds from now. Falls back to the straight-line figure when no speed in the searched
    /// range can make the time; `nil` only for invalid inputs or no time remaining.
    ///
    /// The turn radius grows with speed, so the path length depends on the speed being solved
    /// for. `solve(...).totalTime` is *not* monotonic in speed (B-42): once the radius is large
    /// enough that the near-side turn circle contains the target, that turn becomes infeasible
    /// and the time jumps up to the long way round. A single bisection over the whole range
    /// therefore misses close-in targets. Instead the range is scanned upward from the slowest
    /// speed for the first bracket in which the time crosses `timeRemaining` on one continuous
    /// branch (same turn direction at both ends), and the answer is bisected inside it. The
    /// slowest matching speed is returned: it is the continuation of the turn being flown.
    static func requiredGroundSpeed(distance: Double,
                                    bearing: Double,
                                    track: Double,
                                    timeRemaining: TimeInterval,
                                    preferredDirection: Direction? = nil,
                                    turnRate: Double = standardRateDegreesPerSecond) -> Double? {
        guard timeRemaining.isFinite, timeRemaining > 0, distance.isFinite, distance > 0 else { return nil }
        func solution(at speed: Double) -> Solution? {
            solve(distance: distance, bearing: bearing, track: track, groundSpeed: speed,
                  preferredDirection: preferredDirection, turnRate: turnRate)
        }

        // 0.5 m/s ... 400 m/s (≈ 1 kt ... 780 kt): wide enough for anything that formation-flies.
        let low = 0.5, high = 400.0, step = 2.0
        guard var previous = solution(at: low) else { return nil }
        var previousSpeed = low
        var speed = low
        while speed < high {
            speed = min(speed + step, high)
            guard let current = solution(at: speed) else { return nil }
            defer { previous = current; previousSpeed = speed }
            guard previous.totalTime >= timeRemaining, current.totalTime <= timeRemaining,
                  previous.direction == current.direction else { continue }

            var lo = previousSpeed, hi = speed
            for _ in 0..<60 {
                let mid = (lo + hi) / 2
                guard let t = solution(at: mid)?.totalTime else { return nil }
                if t > timeRemaining { lo = mid } else { hi = mid }
                if hi - lo < 1e-4 { break }
            }
            let result = (lo + hi) / 2
            // A branch switch inside the bracket (it would have to switch and switch back
            // within one step) leaves the bisection on a jump rather than a root; skip it.
            if let t = solution(at: result)?.totalTime, abs(t - timeRemaining) < 0.05 {
                return result
            }
        }
        // No speed in the searched range arrives on time: either faster than anything that
        // flies or slower than 0.5 m/s. Fall back to the straight-line figure so the readout is
        // never blank while time remains; an absurd number reads as "impossible", a blank
        // reads as "unknown".
        return distance / timeRemaining
    }

    /// Number of complete standard-rate orbits that fit before the turn-in point, given how
    /// early the turn-in-now path would arrive. Zero when on time or late.
    static func surplusOrbits(delta: TimeInterval) -> Int {
        guard delta.isFinite, delta < 0 else { return 0 }
        return Int((-delta / fullOrbitDuration).rounded(.down))
    }
}

/// Infers which way the aircraft is turning from successive GPS track samples.
///
/// The rate is the median of the last few per-sample track rates, so GPS course jitter and a
/// single wild sample do not move it. A turn starts once that rate reaches
/// `enterTurnDegreesPerSecond` and ends only when it falls to `exitTurnDegreesPerSecond`
/// (B-43). The gap between the two thresholds stops a rate that jitters around one threshold
/// from toggling the direction, and with it ETE, ETA, Δ and the ORBIT caption, at 1 Hz.
struct TurnDetector: Equatable, Sendable {
    /// Standard rate is 3°/s; straight-flight course jitter is well under 1°/s.
    static let enterTurnDegreesPerSecond: Double = 1.5
    /// Below this, in the direction of the turn, the aircraft has rolled out.
    static let exitTurnDegreesPerSecond: Double = 0.5
    /// Number of recent rates the median is taken over. Five 1 Hz fixes: a roll-out is
    /// recognised about three seconds after the track stops changing.
    static let rateWindow = 5
    /// Samples further apart than this do not describe the same turn.
    static let maxSampleGap: TimeInterval = 10

    private var lastTrack: Double?
    private var lastTime: Date?
    private var recentRates: [Double] = []

    /// The detected turn, or `nil` while flying straight or before two usable samples.
    private(set) var direction: TurnToTarget.Direction?

    init() {}

    /// Records a track sample measured at `time` and returns the current detected direction.
    ///
    /// `time` must be when the fix was measured (its Core Location timestamp), not when it was
    /// delivered (B-44). A sample whose time has not advanced past the previous one (a
    /// duplicate or out-of-order delivery) is ignored rather than treated as a reset.
    @discardableResult
    mutating func record(track: Double, at time: Date) -> TurnToTarget.Direction? {
        guard track.isFinite else { return direction }
        guard let previousTrack = lastTrack, let previousTime = lastTime else {
            lastTrack = track
            lastTime = time
            return direction
        }
        let dt = time.timeIntervalSince(previousTime)
        guard dt > 0 else { return direction }
        lastTrack = track
        lastTime = time
        guard dt <= Self.maxSampleGap else {
            recentRates = []
            direction = nil
            return nil
        }
        // Signed heading change in (-180, 180]: positive is clockwise, a right turn.
        var change = (track - previousTrack).truncatingRemainder(dividingBy: 360)
        if change > 180 { change -= 360 }
        if change <= -180 { change += 360 }
        recentRates.append(change / dt)
        if recentRates.count > Self.rateWindow { recentRates.removeFirst() }

        let rate = Self.median(recentRates)
        // Leave the current turn only once the rate in its direction has decayed.
        switch direction {
        case .right where rate <= Self.exitTurnDegreesPerSecond: direction = nil
        case .left where rate >= -Self.exitTurnDegreesPerSecond: direction = nil
        default: break
        }
        // Enter a turn (or reverse straight into the other one) on a clear rate.
        if direction == nil, abs(rate) >= Self.enterTurnDegreesPerSecond {
            direction = rate > 0 ? .right : .left
        }
        return direction
    }

    /// Forgets all samples (e.g. after a stale-fix blank).
    mutating func reset() {
        lastTrack = nil
        lastTime = nil
        recentRates = []
        direction = nil
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }
}
