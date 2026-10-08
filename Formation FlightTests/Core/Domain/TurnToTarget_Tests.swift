import Foundation
import Testing
@testable import Formation_Flight

/// B-25: time to target assuming a standard-rate turn onto the target, then straight flight.
@Suite("TurnToTarget")
struct TurnToTargetTests {
    /// 100 m/s at 3°/s gives a turn radius of 100 / (π/60) ≈ 1909.86 m.
    private let speed = 100.0
    private var radius: Double { speed / TurnToTarget.standardRateDegreesPerSecond.degreesToRadians }

    @Test("Aligned with the target: no turn, straight time only")
    func alignedIsDirect() throws {
        let s = try #require(TurnToTarget.solve(distance: 10_000, bearing: 0, track: 0, groundSpeed: speed))
        #expect(abs(s.turnDuration) < 1e-9)
        #expect(abs(s.straightDistance - 10_000) < 1e-6)
        #expect(abs(s.totalTime - 100) < 1e-9)
        #expect(!s.isDirectFallback)
    }

    @Test("Target abeam at exactly two radii: a 180° turn ends on top of it")
    func abeamAtTwoRadiiIsHalfOrbit() throws {
        // Track north, target due east at 2R: the right-hand circle passes through the target.
        let s = try #require(TurnToTarget.solve(distance: 2 * radius, bearing: 90, track: 0, groundSpeed: speed))
        #expect(s.direction == .right)
        #expect(abs(s.turnAngleDegrees - 180) < 1e-6)
        #expect(abs(s.turnDuration - 60) < 1e-6)
        #expect(s.straightDistance < 1e-3)
        #expect(abs(s.totalTime - 60) < 1e-6)
    }

    @Test("Target abeam at four radii: turn then tangent, checked against hand geometry")
    func abeamAtFourRadii() throws {
        // Centre of the right circle is R east of the aircraft; target is 4R east, so the
        // centre-to-target distance is 3R. Tangent length = sqrt(9R² − R²) = R·√8, and the
        // exit angle from the centre is acos(R/3R) off the centre→target line, so the arc is
        // 180° − acos(1/3) = 109.47°.
        let s = try #require(TurnToTarget.solve(distance: 4 * radius, bearing: 90, track: 0, groundSpeed: speed))
        let expectedArc = 180 - acos(1.0 / 3.0).radiansToDegrees
        #expect(s.direction == .right)
        #expect(abs(s.turnAngleDegrees - expectedArc) < 1e-6)
        #expect(abs(s.straightDistance - radius * 8.0.squareRoot()) < 1e-6)
        #expect(abs(s.totalTime - (expectedArc / 3 + radius * 8.0.squareRoot() / speed)) < 1e-6)
    }

    @Test("Mirror-image targets take the same time in opposite directions")
    func leftRightSymmetry() throws {
        let right = try #require(TurnToTarget.solve(distance: 8_000, bearing: 60, track: 0, groundSpeed: speed))
        let left = try #require(TurnToTarget.solve(distance: 8_000, bearing: 300, track: 0, groundSpeed: speed))
        #expect(right.direction == .right)
        #expect(left.direction == .left)
        #expect(abs(right.totalTime - left.totalTime) < 1e-9)
        #expect(abs(right.turnAngleDegrees - left.turnAngleDegrees) < 1e-9)
    }

    @Test("Target directly behind: a 180°-plus turn and a tangent exactly as long as the distance")
    func targetBehind() throws {
        let s = try #require(TurnToTarget.solve(distance: 10_000, bearing: 180, track: 0, groundSpeed: speed))
        // Centre is R abeam, target D behind: centre-to-target is sqrt(R² + D²), so the tangent
        // is sqrt(d² − R²) = D exactly. After 180° the aircraft is heading straight back, 2R
        // abeam the target; the extra arc θ to swing onto the tangent satisfies
        // D·sinθ = R·(1 + cosθ), i.e. θ = 2·atan(R / D) ≈ 21.6°.
        let expectedArc = 180 + 2 * atan(radius / 10_000).radiansToDegrees
        #expect(abs(s.turnAngleDegrees - expectedArc) < 1e-6)
        #expect(abs(s.straightDistance - 10_000) < 1e-6)
        // Both directions are equivalent by symmetry; the solver must pick one deterministically.
        #expect(s.direction == .left)
    }

    @Test("A preferred direction is honoured even when the other turn is shorter")
    func preferredDirectionWins() throws {
        let shortest = try #require(TurnToTarget.solve(distance: 8_000, bearing: 60, track: 0, groundSpeed: speed))
        let continued = try #require(TurnToTarget.solve(distance: 8_000, bearing: 60, track: 0, groundSpeed: speed,
                                                        preferredDirection: .left))
        #expect(shortest.direction == .right)
        #expect(continued.direction == .left)
        #expect(continued.totalTime > shortest.totalTime)
        // Continuing the orbit the long way round costs most of a full circle.
        #expect(continued.turnAngleDegrees > 250)
    }

    @Test("Preferred direction that cannot reach the target falls back to the other side")
    func preferredDirectionInfeasibleFallsBack() throws {
        // Target just inside the right-hand circle: only a left turn can reach it.
        let s = try #require(TurnToTarget.solve(distance: 1.2 * radius, bearing: 90, track: 0, groundSpeed: speed,
                                                preferredDirection: .right))
        #expect(s.direction == .left)
        #expect(!s.isDirectFallback)
    }

    @Test("Target close ahead inside a turn radius is still a straight run")
    func closeAheadIsStraight() throws {
        // The two turn circles touch only at the aircraft, so a target dead ahead is never
        // inside either: the solver yields no turn and a 0.5 s straight run.
        let s = try #require(TurnToTarget.solve(distance: 50, bearing: 0, track: 0, groundSpeed: speed))
        #expect(s.turnDuration < 1e-9)
        #expect(abs(s.totalTime - 0.5) < 1e-9)
        #expect(!s.isDirectFallback)
    }

    @Test("Target abeam inside one circle is reached by turning the other way")
    func abeamInsideOneCircle() throws {
        // 0.5R due east sits inside the right-hand circle; only a left turn reaches it.
        let s = try #require(TurnToTarget.solve(distance: 0.5 * radius, bearing: 90, track: 0, groundSpeed: speed))
        #expect(s.direction == .left)
        #expect(s.turnAngleDegrees > 180)
        #expect(!s.isDirectFallback)
    }

    @Test("Invalid inputs return nil")
    func invalidInputs() {
        #expect(TurnToTarget.solve(distance: 0, bearing: 0, track: 0, groundSpeed: speed) == nil)
        #expect(TurnToTarget.solve(distance: 1_000, bearing: 0, track: 0, groundSpeed: 0) == nil)
        #expect(TurnToTarget.solve(distance: .nan, bearing: 0, track: 0, groundSpeed: speed) == nil)
        #expect(TurnToTarget.solve(distance: 1_000, bearing: .infinity, track: 0, groundSpeed: speed) == nil)
    }

    @Test("Required groundspeed reproduces the time remaining through the same path")
    func requiredGroundSpeedRoundTrip() throws {
        let distance = 12_000.0, bearing = 75.0, track = 0.0, timeRemaining = 150.0
        let v = try #require(TurnToTarget.requiredGroundSpeed(distance: distance, bearing: bearing, track: track,
                                                              timeRemaining: timeRemaining))
        let s = try #require(TurnToTarget.solve(distance: distance, bearing: bearing, track: track, groundSpeed: v))
        #expect(abs(s.totalTime - timeRemaining) < 0.01)
        // Turning costs time, so the required speed is above the direct-to figure.
        #expect(v > distance / timeRemaining)
    }

    @Test("Required groundspeed is direct-to when already aligned")
    func requiredGroundSpeedAligned() throws {
        let v = try #require(TurnToTarget.requiredGroundSpeed(distance: 1_000, bearing: 0, track: 0, timeRemaining: 100))
        #expect(abs(v - 10) < 1e-3)
    }

    @Test("Required groundspeed beyond the search range falls back to direct-to; no time left is nil")
    func requiredGroundSpeedOutOfRange() throws {
        // 100 km in 5 s is far beyond any aircraft; the readout still shows the straight-line
        // figure (20 000 m/s) so the pilot sees "impossible" rather than a blank.
        let v = try #require(TurnToTarget.requiredGroundSpeed(distance: 100_000, bearing: 90, track: 0, timeRemaining: 5))
        #expect(abs(v - 20_000) < 1e-9)
        #expect(TurnToTarget.requiredGroundSpeed(distance: 1_000, bearing: 0, track: 0, timeRemaining: 0) == nil)
        #expect(TurnToTarget.requiredGroundSpeed(distance: 1_000, bearing: 0, track: 0, timeRemaining: -5) == nil)
    }

    /// B-42: close-in targets abeam where the top of the old bisection range put the target
    /// inside the near turn circle, so the solver fell back to direct-to and arrived 13 s late.
    @Test("Required groundspeed for close-in targets abeam lands on time (B-42)",
          arguments: [(distance: 3_704.0, time: 100.0, expected: 42.9),
                      (distance: 5_000.0, time: 90.0, expected: 66.0),
                      (distance: 5_000.0, time: 120.0, expected: 46.8)])
    func requiredGroundSpeedCloseInAbeam(distance: Double, time: Double, expected: Double) throws {
        let v = try #require(TurnToTarget.requiredGroundSpeed(distance: distance, bearing: 90, track: 0, timeRemaining: time))
        let s = try #require(TurnToTarget.solve(distance: distance, bearing: 90, track: 0, groundSpeed: v))
        #expect(abs(s.totalTime - time) < 0.01)
        #expect(abs(v - expected) < 0.1)
    }

    @Test("Required groundspeed round-trips through solve for random geometry (B-42)")
    func requiredGroundSpeedRandomRoundTrip() throws {
        // A fixed-seed generator keeps the cases reproducible.
        var rng = SplitMix64(seed: 42)
        for _ in 0..<500 {
            let distance = Double.random(in: 200...60_000, using: &rng)
            let bearing = Double.random(in: 0..<360, using: &rng)
            let time = Double.random(in: 10...1_800, using: &rng)
            let preferred: TurnToTarget.Direction? = [nil, .left, .right].randomElement(using: &rng)!
            let v = try #require(TurnToTarget.requiredGroundSpeed(distance: distance, bearing: bearing, track: 0,
                                                                  timeRemaining: time, preferredDirection: preferred))
            // The straight-line fallback is only for times no speed in range can make.
            guard v != distance / time else { continue }
            let s = try #require(TurnToTarget.solve(distance: distance, bearing: bearing, track: 0, groundSpeed: v,
                                                    preferredDirection: preferred))
            #expect(abs(s.totalTime - time) < 0.05, "d=\(distance) brg=\(bearing) T=\(time) pref=\(String(describing: preferred))")
        }
    }

    @Test("Surplus orbits count whole two-minute circles of earliness")
    func surplusOrbits() {
        #expect(TurnToTarget.fullOrbitDuration == 120)
        #expect(TurnToTarget.surplusOrbits(delta: 30) == 0)
        #expect(TurnToTarget.surplusOrbits(delta: 0) == 0)
        #expect(TurnToTarget.surplusOrbits(delta: -119) == 0)
        #expect(TurnToTarget.surplusOrbits(delta: -120) == 1)
        #expect(TurnToTarget.surplusOrbits(delta: -250) == 2)
        #expect(TurnToTarget.surplusOrbits(delta: -.infinity) == 0)
    }
}

@Suite("TurnDetector")
struct TurnDetectorTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test("Straight flight with jitter is not a turn")
    func straightFlight() {
        var d = TurnDetector()
        #expect(d.record(track: 90.0, at: t0) == nil)
        #expect(d.record(track: 90.4, at: t0.addingTimeInterval(1)) == nil)
        #expect(d.record(track: 89.7, at: t0.addingTimeInterval(2)) == nil)
    }

    @Test("A standard-rate right turn is detected as right")
    func rightTurn() {
        var d = TurnDetector()
        d.record(track: 10, at: t0)
        d.record(track: 13, at: t0.addingTimeInterval(1))
        #expect(d.record(track: 16, at: t0.addingTimeInterval(2)) == .right)
    }

    @Test("A left turn through north wraps correctly")
    func leftTurnThroughNorth() {
        var d = TurnDetector()
        d.record(track: 4, at: t0)
        d.record(track: 1, at: t0.addingTimeInterval(1))
        #expect(d.record(track: 358, at: t0.addingTimeInterval(2)) == .left)
        #expect(d.record(track: 355, at: t0.addingTimeInterval(3)) == .left)
    }

    @Test("Rolling out of a turn returns to straight after the rate decays")
    func rollOut() {
        var d = TurnDetector()
        d.record(track: 0, at: t0)
        d.record(track: 3, at: t0.addingTimeInterval(1))
        #expect(d.record(track: 6, at: t0.addingTimeInterval(2)) == .right)
        d.record(track: 6, at: t0.addingTimeInterval(3))
        d.record(track: 6, at: t0.addingTimeInterval(4))
        #expect(d.record(track: 6, at: t0.addingTimeInterval(5)) == nil)
    }

    @Test("A long gap between samples resets the detection")
    func gapResets() {
        var d = TurnDetector()
        d.record(track: 0, at: t0)
        d.record(track: 3, at: t0.addingTimeInterval(1))
        #expect(d.record(track: 6, at: t0.addingTimeInterval(2)) == .right)
        #expect(d.record(track: 60, at: t0.addingTimeInterval(30)) == nil)
    }

    @Test("A right turn with ±1.5°/s of per-sample jitter stays right throughout (B-43)")
    func jitteryTurnHolds() {
        var d = TurnDetector()
        var track = 0.0
        d.record(track: track, at: t0)
        let jitter: [Double] = [1.5, -1.5, 1.2, -1.4, 1.5, -1.5, 0.8, -1.5, 1.5, -1.0]
        for (i, j) in jitter.enumerated() {
            track += 3 + j
            let direction = d.record(track: track, at: t0.addingTimeInterval(Double(i + 1)))
            #expect(direction == .right, "sample \(i + 1)")
        }
    }

    @Test("Rate jitter around 1°/s does not toggle the direction (B-43)")
    func noFlapAtOldThreshold() {
        // Straight-ish flight with a rate wandering between 0.7 and 1.3°/s: under the old
        // single 1°/s threshold this toggled every sample.
        var d = TurnDetector()
        var track = 90.0
        d.record(track: track, at: t0)
        var seen: Set<String> = []
        for (i, rate) in [1.3, 0.7, 1.3, 0.7, 1.3, 0.7, 1.3, 0.7].enumerated() {
            track += rate
            seen.insert(String(describing: d.record(track: track, at: t0.addingTimeInterval(Double(i + 1)))))
        }
        #expect(seen == ["nil"])
    }

    @Test("A single wild sample mid-turn does not clear the direction (B-43)")
    func wildSampleIgnored() {
        var d = TurnDetector()
        let tracks: [Double] = [0, 3, 6, 9, 12, 2, 18, 21]   // 12 → 2 is a 10° course spike back
        for (i, track) in tracks.enumerated() {
            let direction = d.record(track: track, at: t0.addingTimeInterval(Double(i)))
            if i >= 1 { #expect(direction == .right, "sample \(i)") }
        }
    }

    @Test("A roll-out returns to straight within about five seconds (B-43)")
    func rollOutWithinFiveSeconds() {
        var d = TurnDetector()
        for i in 0...5 { d.record(track: Double(i) * 3, at: t0.addingTimeInterval(Double(i))) }
        #expect(d.direction == .right)
        var clearedAfter: Int?
        for s in 1...10 where clearedAfter == nil {
            if d.record(track: 15, at: t0.addingTimeInterval(Double(5 + s))) == nil { clearedAfter = s }
        }
        #expect((clearedAfter ?? .max) <= 5)
    }

    @Test("A sample whose timestamp has not advanced is ignored, not a reset (B-44)")
    func duplicateTimestampIgnored() {
        var d = TurnDetector()
        d.record(track: 0, at: t0)
        d.record(track: 3, at: t0.addingTimeInterval(1))
        #expect(d.record(track: 6, at: t0.addingTimeInterval(2)) == .right)
        // The same fix delivered again, then an out-of-order one: both dropped.
        #expect(d.record(track: 6, at: t0.addingTimeInterval(2)) == .right)
        #expect(d.record(track: 1, at: t0.addingTimeInterval(1.5)) == .right)
        #expect(d.record(track: 9, at: t0.addingTimeInterval(3)) == .right)
    }
}

/// Deterministic generator for reproducible randomized tests.
private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
