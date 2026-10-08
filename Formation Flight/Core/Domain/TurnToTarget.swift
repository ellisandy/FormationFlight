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
    /// seconds from now, or `nil` if no speed in the searched range can.
    ///
    /// The turn radius grows with speed, so the path length depends on the speed being solved
    /// for; this is a bisection on `solve(...).totalTime`, which falls with speed.
    static func requiredGroundSpeed(distance: Double,
                                    bearing: Double,
                                    track: Double,
                                    timeRemaining: TimeInterval,
                                    preferredDirection: Direction? = nil,
                                    turnRate: Double = standardRateDegreesPerSecond) -> Double? {
        guard timeRemaining.isFinite, timeRemaining > 0, distance.isFinite, distance > 0 else { return nil }
        // 0.5 m/s ... 400 m/s (≈ 1 kt ... 780 kt): wide enough for anything that formation-flies.
        var low = 0.5, high = 400.0
        func time(at speed: Double) -> Double? {
            solve(distance: distance, bearing: bearing, track: track, groundSpeed: speed,
                  preferredDirection: preferredDirection, turnRate: turnRate)?.totalTime
        }
        guard let tHigh = time(at: high), let tLow = time(at: low) else { return nil }
        // Outside the searched range the turn model has nothing useful to add: above it the
        // turn radius dwarfs the geometry, below it the answer is "slower than anything that
        // flies". Fall back to the straight-line figure so the readout is never blank while
        // time remains; an absurd number reads as "impossible", a blank reads as "unknown".
        if tHigh > timeRemaining || tLow < timeRemaining { return distance / timeRemaining }
        for _ in 0..<60 {
            let mid = (low + high) / 2
            guard let t = time(at: mid) else { return nil }
            if t > timeRemaining { low = mid } else { high = mid }
            if high - low < 1e-4 { break }
        }
        return (low + high) / 2
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
/// A sustained track rate above `turningThresholdDegreesPerSecond` is a turn; below it the
/// aircraft is treated as flying straight. The rate is smoothed over the last few samples so
/// GPS course jitter does not flip the direction between fixes.
struct TurnDetector: Equatable, Sendable {
    /// Standard rate is 3°/s; straight-flight course jitter is well under 1°/s.
    static let turningThresholdDegreesPerSecond: Double = 1.0
    /// Samples further apart than this do not describe the same turn.
    static let maxSampleGap: TimeInterval = 10

    private var lastTrack: Double?
    private var lastTime: Date?
    private var smoothedRate: Double = 0

    /// The detected turn, or `nil` while flying straight or before two usable samples.
    private(set) var direction: TurnToTarget.Direction?

    init() {}

    /// Records a track sample and returns the current detected direction.
    @discardableResult
    mutating func record(track: Double, at time: Date) -> TurnToTarget.Direction? {
        defer { lastTrack = track; lastTime = time }
        guard track.isFinite, let previousTrack = lastTrack, let previousTime = lastTime else {
            return direction
        }
        let dt = time.timeIntervalSince(previousTime)
        guard dt > 0, dt <= Self.maxSampleGap else {
            smoothedRate = 0
            direction = nil
            return nil
        }
        // Signed heading change in (-180, 180]: positive is clockwise, a right turn.
        var change = (track - previousTrack).truncatingRemainder(dividingBy: 360)
        if change > 180 { change -= 360 }
        if change <= -180 { change += 360 }
        let rate = change / dt
        smoothedRate = smoothedRate == 0 ? rate : 0.5 * smoothedRate + 0.5 * rate

        if abs(smoothedRate) >= Self.turningThresholdDegreesPerSecond {
            direction = smoothedRate > 0 ? .right : .left
        } else {
            direction = nil
        }
        return direction
    }

    /// Forgets all samples (e.g. after a stale-fix blank).
    mutating func reset() {
        lastTrack = nil
        lastTime = nil
        smoothedRate = 0
        direction = nil
    }
}
